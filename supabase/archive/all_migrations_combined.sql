DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;

-- 1. ÛŒÙˆØ²Ø± Ø±ÙˆÙ„Ø² Ú©Û’ Ù„ÛŒÛ’ Ø§Ù†Ù… (Enum) Ù¹Ø§Ø¦Ù¾ Ø¨Ù†Ø§Ù†Ø§
CREATE TYPE user_role AS ENUM ('buyer', 'seller', 'admin');

-- 2. Ù¾Ø±ÙˆÙØ§Ø¦Ù„Ø² Ù¹ÛŒØ¨Ù„ Ø¨Ù†Ø§Ù†Ø§ Ø¬Ùˆ Ø³Ù¾Ø§Ø¨ÛŒØ³ Ú©ÛŒ Ø§Ù¾Ù†ÛŒ Ø§ÛŒØªÚ¾Ù†Ù¹ÛŒÚ©ÛŒØ´Ù† (auth.users) Ø³Û’ Ø¬Ú‘Ø§ ÛÙˆÚ¯Ø§
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  full_name TEXT,
  phone_number TEXT,
  role user_role DEFAULT 'buyer'::user_role NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 3. Ø³ÛŒÙ„Ø±Ø² Ú©Û’ Ø§Ø³Ù¹ÙˆØ±Ø² Ú©ÛŒ Ù…Ø¹Ù„ÙˆÙ…Ø§Øª Ú©Û’ Ù„ÛŒÛ’ Ù¹ÛŒØ¨Ù„
CREATE TABLE public.sellers (
  id UUID REFERENCES public.profiles(id) ON DELETE CASCADE PRIMARY KEY,
  shop_name TEXT NOT NULL,
  shop_logo TEXT,
  is_approved BOOLEAN DEFAULT FALSE NOT NULL,
  commission_rate DECIMAL(5,2) DEFAULT 10.00 NOT NULL, -- Ø³Ù¾Ø± Ø§ÛŒÚˆÙ…Ù† Ú©ÛŒ Ú©Ù…ÛŒØ´Ù† ÙÛŒØµØ¯ (Ù¾ÛÙ„Û’ Ø³Û’ Ø·Û’ Ø´Ø¯Û 10%)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 4. Ø±Ø¦ÛŒÙ„ Ù¹Ø§Ø¦Ù… (Real-time) Ø§ÙˆØ± Ø³ÛŒÚ©ÛŒÙˆØ±Ù¹ÛŒ Ù¾Ø§Ù„ÛŒØ³ÛŒØ² (RLS) Ú©Ùˆ ÙØ¹Ø§Ù„ Ú©Ø±Ù†Ø§
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sellers ENABLE ROW LEVEL SECURITY;

-- 5. Ø¢Ù¹Ùˆ Ù¾Ø±ÙˆÙØ§Ø¦Ù„ Ø¨Ù†Ø§Ù†Û’ Ú©Û’ Ù„ÛŒÛ’ Ø§ÛŒÚ© ÙÙ†Ú©Ø´Ù† Ø¬Ùˆ Ù†Ø¦Û’ Ø³Ø§Ø¦Ù† Ø§Ù¾ ÛÙˆÙ†Û’ ÙˆØ§Ù„Û’ ØµØ§Ø±Ù Ú©Ø§ Ù¾Ø±ÙˆÙØ§Ø¦Ù„ Ø®ÙˆØ¯ Ø¨Ø®ÙˆØ¯ Ø¨Ù†Ø§ Ø¯Û’ Ú¯Ø§
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'full_name', 'Ù†ÛŒØ§ ØµØ§Ø±Ù'),
    COALESCE((new.raw_user_meta_data->>'role')::user_role, 'buyer'::user_role)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Ù¹Ø±Ú¯Ø± Ø³ÛŒÙ¹ Ú©Ø±Ù†Ø§ Ø¬Ùˆ Ø³Ø§Ø¦Ù† Ø§Ù¾ Ù¾Ø± ÙÙ†Ú©Ø´Ù† Ú†Ù„Ø§Ø¦Û’ Ú¯Ø§
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
-- ============================================================================
-- APNA STORE â€” REVISED AUTHORITATIVE DATABASE SCHEMA, ROLES & RLS POLICIES
-- Migration: 20260805000000_authoritative_schema_and_rls.sql
-- Description: Consolidates legacy table definitions, establishes protected
--              user_roles table, SECURITY DEFINER functions with SET search_path = '',
--              private profiles RLS + public view, strict column-level INSERT/UPDATE
--              privileges, admin product review, and explicit grants.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. PREFLIGHT CHECKS & ASSERTIONS
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE 'Executing Preflight Inspection for Migration 20260805000000';
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role'
    ) THEN
        RAISE NOTICE 'Preflight Audit: Legacy profiles.role column detected. Legacy roles require manual admin verification before user_roles migration.';
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 1. EXTENSIONS & ENUMS
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'app_role') THEN
        CREATE TYPE public.app_role AS ENUM ('buyer', 'seller', 'admin', 'super_admin', 'owner');
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 2. PROTECTED ROLE FOUNDATION (user_roles & TRIGGER)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role public.app_role NOT NULL DEFAULT 'buyer'::public.app_role,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    granted_by UUID REFERENCES auth.users(id),
    CONSTRAINT user_roles_user_id_role_key UNIQUE (user_id, role)
);

CREATE INDEX IF NOT EXISTS idx_user_roles_user_id ON public.user_roles(user_id);
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 3. PROFILES TABLE (PRIVATE PERSONAL DATA ONLY)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL DEFAULT '',
    email TEXT NOT NULL DEFAULT '',
    mobile_number TEXT DEFAULT '',
    avatar_url TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS email TEXT NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS mobile_number TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS avatar_url TEXT DEFAULT '';

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Limited Public View for Marketplace Display (Security Invoker, Authenticated Access Only)
CREATE OR REPLACE VIEW public.public_profile_view 
WITH (security_invoker = true) AS
SELECT id, full_name, avatar_url
FROM public.profiles;

-- Server-Controlled New User Trigger: NEVER TRUST raw_user_meta_data FOR ROLES!
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, email)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'full_name', 'New User'),
        COALESCE(new.email, '')
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        email = EXCLUDED.email,
        updated_at = NOW();

    -- Always assign default 'buyer' role. Never trust client signup metadata!
    INSERT INTO public.user_roles (user_id, role)
    VALUES (new.id, 'buyer'::public.app_role)
    ON CONFLICT (user_id, role) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ----------------------------------------------------------------------------
-- 4. CANONICAL TABLES CONSOLIDATION
-- ----------------------------------------------------------------------------

-- A. seller_stores (Single Canonical Table)
CREATE TABLE IF NOT EXISTS public.seller_stores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    shop_name TEXT NOT NULL,
    shop_slug TEXT UNIQUE NOT NULL,
    business_name TEXT DEFAULT '',
    business_address TEXT DEFAULT '',
    city TEXT DEFAULT '',
    country TEXT DEFAULT 'Pakistan',
    category TEXT DEFAULT '',
    shop_description TEXT DEFAULT '',
    shop_logo TEXT DEFAULT '',
    shop_banner TEXT DEFAULT '',
    is_approved BOOLEAN NOT NULL DEFAULT FALSE,
    kyc_status TEXT NOT NULL DEFAULT 'Pending' CHECK (kyc_status IN ('Pending', 'Approved', 'Rejected')),
    commission_rate NUMERIC(5,2) NOT NULL DEFAULT 10.00 CHECK (commission_rate >= 0.00 AND commission_rate <= 100.00),
    balance NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0.00),
    pending_payout NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (pending_payout >= 0.00),
    last_payout NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (last_payout >= 0.00),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.seller_stores ENABLE ROW LEVEL SECURITY;

-- B. seller_kyc_documents (Single Canonical Table)
CREATE TABLE IF NOT EXISTS public.seller_kyc_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_store_id UUID NOT NULL REFERENCES public.seller_stores(id) ON DELETE CASCADE,
    document_type TEXT NOT NULL,
    document_url TEXT NOT NULL,
    cnic_number TEXT DEFAULT '',
    ntn_number TEXT DEFAULT '',
    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected')),
    submitted_by UUID REFERENCES auth.users(id),
    reviewed_by UUID REFERENCES auth.users(id),
    reviewed_at TIMESTAMPTZ,
    rejection_reason TEXT,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.seller_kyc_documents ENABLE ROW LEVEL SECURITY;

-- C. categories (Single Canonical Table)
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    icon TEXT DEFAULT '',
    banner_url TEXT DEFAULT '',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

-- D. products (Single Canonical Table)
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_store_id UUID NOT NULL REFERENCES public.seller_stores(id) ON DELETE CASCADE,
    category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    description TEXT DEFAULT '',
    price NUMERIC(12,2) NOT NULL CHECK (price >= 0.00),
    sale_price NUMERIC(12,2) CHECK (sale_price IS NULL OR sale_price >= 0.00),
    rating NUMERIC(3,2) NOT NULL DEFAULT 5.00 CHECK (rating >= 0.00 AND rating <= 5.00),
    stock_quantity INT NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    image_url TEXT NOT NULL DEFAULT '',
    category TEXT DEFAULT '',
    approval_status TEXT NOT NULL DEFAULT 'Pending' CHECK (approval_status IN ('Pending', 'Approved', 'Rejected')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- E. buyer_orders (Temporary Compatibility Table for Phase 3/4)
CREATE TABLE IF NOT EXISTS public.buyer_orders (
    id TEXT PRIMARY KEY,
    customer_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    customer_name TEXT NOT NULL,
    customer_email TEXT NOT NULL,
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0.00),
    payment_method TEXT NOT NULL,
    items JSONB NOT NULL DEFAULT '[]'::jsonb,
    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.buyer_orders ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 5. INDEXES & CONSTRAINTS
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_seller_stores_owner_id ON public.seller_stores(owner_id);
CREATE INDEX IF NOT EXISTS idx_seller_stores_slug ON public.seller_stores(shop_slug);
CREATE INDEX IF NOT EXISTS idx_seller_stores_is_approved ON public.seller_stores(is_approved);
CREATE INDEX IF NOT EXISTS idx_kyc_seller_store_id ON public.seller_kyc_documents(seller_store_id);
CREATE INDEX IF NOT EXISTS idx_categories_slug ON public.categories(slug);
CREATE INDEX IF NOT EXISTS idx_categories_is_active ON public.categories(is_active);
CREATE INDEX IF NOT EXISTS idx_products_seller_store_id ON public.products(seller_store_id);
CREATE INDEX IF NOT EXISTS idx_products_category_id ON public.products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_approval_active ON public.products(approval_status, is_active);
CREATE INDEX IF NOT EXISTS idx_buyer_orders_customer_user_id ON public.buyer_orders(customer_user_id);
CREATE INDEX IF NOT EXISTS idx_buyer_orders_customer_email ON public.buyer_orders(customer_email);
CREATE INDEX IF NOT EXISTS idx_buyer_orders_status ON public.buyer_orders(status);

-- ----------------------------------------------------------------------------
-- 6. SECURITY DEFINER HELPER & ADMINISTRATIVE FUNCTIONS (SET search_path = '')
-- ----------------------------------------------------------------------------

-- Helper: Get user role from protected user_roles
CREATE OR REPLACE FUNCTION public.get_current_user_role()
RETURNS public.app_role AS $$
DECLARE
    u_role public.app_role;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN 'buyer'::public.app_role;
    END IF;

    SELECT role INTO u_role
    FROM public.user_roles
    WHERE user_id = auth.uid()
    ORDER BY granted_at DESC
    LIMIT 1;

    RETURN COALESCE(u_role, 'buyer'::public.app_role);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

-- Helper: Check if caller has role
CREATE OR REPLACE FUNCTION public.has_role(required_role public.app_role)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = auth.uid()
          AND role = required_role
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

-- Helper: Check if caller is admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = auth.uid()
          AND role IN ('admin'::public.app_role, 'super_admin'::public.app_role, 'owner'::public.app_role)
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

-- Helper: Check store ownership
CREATE OR REPLACE FUNCTION public.owns_seller_store(target_store_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1 FROM public.seller_stores
        WHERE id = target_store_id
          AND owner_id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

-- Admin Function: Assign Role
CREATE OR REPLACE FUNCTION public.assign_user_role(target_user_id UUID, new_role public.app_role)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL OR NOT public.is_admin() THEN
        RAISE EXCEPTION 'Access denied: Administrator privileges required.';
    END IF;

    INSERT INTO public.user_roles (user_id, role, granted_by)
    VALUES (target_user_id, new_role, auth.uid())
    ON CONFLICT (user_id, role) DO UPDATE SET granted_at = NOW(), granted_by = auth.uid();

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Admin Function: Review Seller Store
CREATE OR REPLACE FUNCTION public.admin_review_seller_store(
    target_store_id UUID,
    approve BOOLEAN,
    new_commission NUMERIC(5,2) DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL OR NOT public.is_admin() THEN
        RAISE EXCEPTION 'Access denied: Administrator privileges required.';
    END IF;

    UPDATE public.seller_stores
    SET is_approved = approve,
        commission_rate = COALESCE(new_commission, commission_rate),
        updated_at = NOW()
    WHERE id = target_store_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Admin Function: Review KYC Document
CREATE OR REPLACE FUNCTION public.admin_review_kyc_document(
    target_kyc_id UUID,
    new_status TEXT,
    reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL OR NOT public.is_admin() THEN
        RAISE EXCEPTION 'Access denied: Administrator privileges required.';
    END IF;

    IF new_status NOT IN ('Approved', 'Rejected', 'Pending') THEN
        RAISE EXCEPTION 'Invalid KYC status value.';
    END IF;

    UPDATE public.seller_kyc_documents
    SET status = new_status,
        reviewed_by = auth.uid(),
        reviewed_at = NOW(),
        rejection_reason = reason,
        updated_at = NOW()
    WHERE id = target_kyc_id;

    IF new_status = 'Approved' THEN
        UPDATE public.seller_stores
        SET kyc_status = 'Approved', updated_at = NOW()
        WHERE id = (SELECT seller_store_id FROM public.seller_kyc_documents WHERE id = target_kyc_id);
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Admin Function: Review Product Approval
CREATE OR REPLACE FUNCTION public.admin_review_product(
    target_product_id UUID,
    approve BOOLEAN
)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL OR NOT public.is_admin() THEN
        RAISE EXCEPTION 'Access denied: Administrator privileges required.';
    END IF;

    -- Prevent seller self-approval even if seller has an admin role
    IF EXISTS (
        SELECT 1 FROM public.products p
        JOIN public.seller_stores s ON s.id = p.seller_store_id
        WHERE p.id = target_product_id AND s.owner_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Access denied: Sellers cannot approve their own products.';
    END IF;

    UPDATE public.products
    SET approval_status = CASE WHEN approve THEN 'Approved' ELSE 'Rejected' END,
        updated_at = NOW()
    WHERE id = target_product_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Revoke execution from PUBLIC & anon
REVOKE EXECUTE ON FUNCTION public.assign_user_role(UUID, public.app_role) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_review_seller_store(UUID, BOOLEAN, NUMERIC) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_review_kyc_document(UUID, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_review_product(UUID, BOOLEAN) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.assign_user_role(UUID, public.app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_seller_store(UUID, BOOLEAN, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_kyc_document(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_product(UUID, BOOLEAN) TO authenticated;

-- ----------------------------------------------------------------------------
-- 7. COLUMN-LEVEL PRIVILEGE PROTECTION (GRANT / REVOKE)
-- ----------------------------------------------------------------------------

-- A. user_roles: No client INSERT/UPDATE/DELETE privileges
REVOKE ALL ON public.user_roles FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.user_roles TO authenticated;

-- B. seller_stores: Protect approval, financial, & ownership columns during INSERT and UPDATE
REVOKE ALL ON public.seller_stores FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.seller_stores TO anon, authenticated;
GRANT INSERT (owner_id, shop_name, shop_slug, business_name, business_address, city, country, category, shop_description, shop_logo, shop_banner) ON public.seller_stores TO authenticated;
GRANT UPDATE (shop_name, shop_slug, business_name, business_address, city, country, category, shop_description, shop_logo, shop_banner, updated_at) ON public.seller_stores TO authenticated;

-- C. seller_kyc_documents: Protect status & review columns during INSERT and UPDATE
REVOKE ALL ON public.seller_kyc_documents FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.seller_kyc_documents TO authenticated;
GRANT INSERT (seller_store_id, document_type, document_url, cnic_number, ntn_number, submitted_by) ON public.seller_kyc_documents TO authenticated;

-- D. products: Protect approval_status during INSERT and UPDATE
REVOKE ALL ON public.products FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.products TO anon, authenticated;
GRANT INSERT (seller_store_id, category_id, name, description, price, sale_price, stock_quantity, image_url, category, is_active) ON public.products TO authenticated;
GRANT UPDATE (name, description, price, sale_price, stock_quantity, image_url, category, is_active, updated_at) ON public.products TO authenticated;

-- E. buyer_orders: Direct client INSERT and UPDATE are revoked until Phase 8 Atomic Checkout
REVOKE ALL ON public.buyer_orders FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.buyer_orders TO authenticated;

-- ----------------------------------------------------------------------------
-- 8. EXPLICIT ROW LEVEL SECURITY (RLS) POLICIES
-- ----------------------------------------------------------------------------

-- A. user_roles
CREATE POLICY "Users and admins can view relevant user roles" ON public.user_roles
    FOR SELECT USING (public.is_admin() OR user_id = auth.uid());

-- B. profiles (PRIVATE)
CREATE POLICY "Users can view own full profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id OR public.is_admin());

CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own personal profile" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- C. seller_stores
CREATE POLICY "Public view approved stores; Owner/Admin view all" ON public.seller_stores
    FOR SELECT USING (is_approved = TRUE OR auth.uid() = owner_id OR public.is_admin());

CREATE POLICY "Authenticated users insert own store" ON public.seller_stores
    FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Store owners update safe business details" ON public.seller_stores
    FOR UPDATE USING (auth.uid() = owner_id OR public.is_admin());

-- D. seller_kyc_documents
CREATE POLICY "Sellers view own KYC" ON public.seller_kyc_documents
    FOR SELECT USING (
        public.owns_seller_store(seller_store_id) OR public.is_admin()
    );

CREATE POLICY "Sellers submit KYC for own store" ON public.seller_kyc_documents
    FOR INSERT WITH CHECK (
        public.owns_seller_store(seller_store_id)
    );

-- E. categories
CREATE POLICY "Public view active categories" ON public.categories
    FOR SELECT USING (is_active = TRUE OR public.is_admin());

CREATE POLICY "Admins manage categories" ON public.categories
    FOR ALL USING (public.is_admin());

-- F. products
CREATE POLICY "Public view approved active products; Owner/Admin view all" ON public.products
    FOR SELECT USING (
        (approval_status = 'Approved' AND is_active = TRUE)
        OR public.owns_seller_store(seller_store_id)
        OR public.is_admin()
    );

CREATE POLICY "Approved sellers insert products for own store" ON public.products
    FOR INSERT WITH CHECK (
        public.owns_seller_store(seller_store_id)
    );

CREATE POLICY "Sellers update safe product details" ON public.products
    FOR UPDATE USING (
        public.owns_seller_store(seller_store_id) OR public.is_admin()
    );

-- G. buyer_orders
CREATE POLICY "Buyers view own orders; Admins view all" ON public.buyer_orders
    FOR SELECT USING (
        customer_user_id = auth.uid()
        OR customer_email = (SELECT email FROM public.profiles WHERE id = auth.uid())
        OR public.is_admin()
    );

-- ----------------------------------------------------------------------------
-- 9. POST-MIGRATION VERIFICATION QUERIES
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE 'Migration 20260805000000 completed successfully.';
END $$;
-- ============================================================================
-- APNA STORE â€” PHASE 6: GRANULAR RBAC, SERVER-SIDE SECURITY & IMMUTABLE AUDIT LOGS
-- Migration: 20260806000000_phase_6_rbac_admin_audit.sql
-- Description: Establishes role_permissions table, immutable audit_logs table,
--              internal audit logging helper, granular has_permission() check,
--              and retrofitted/hardened SECURITY DEFINER RPC functions.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. ADD NEW PROTECTED SECURITY COLUMNS TO seller_stores
-- ----------------------------------------------------------------------------
ALTER TABLE public.seller_stores
    ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS payout_locked BOOLEAN NOT NULL DEFAULT FALSE;

-- Revoke direct UPDATE on newly added protected fields from authenticated/anon clients
REVOKE ALL ON public.seller_stores FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.seller_stores TO anon, authenticated;
GRANT INSERT (owner_id, shop_name, shop_slug, business_name, business_address, city, country, category, shop_description, shop_logo, shop_banner) ON public.seller_stores TO authenticated;
GRANT UPDATE (shop_name, shop_slug, business_name, business_address, city, country, category, shop_description, shop_logo, shop_banner, updated_at) ON public.seller_stores TO authenticated;

-- ----------------------------------------------------------------------------
-- 2. PROTECTED GRANULAR ROLE PERMISSIONS TABLE (role_permissions)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role public.app_role NOT NULL,
    module TEXT NOT NULL,
    action TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT role_permissions_role_module_action_key UNIQUE (role, module, action)
);

ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.role_permissions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.role_permissions TO authenticated;

DROP POLICY IF EXISTS "Authenticated users view role permissions" ON public.role_permissions;
CREATE POLICY "Authenticated users view role permissions" ON public.role_permissions
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Seed Canonical Role Permissions Matrix
INSERT INTO public.role_permissions (role, module, action) VALUES
    ('owner'::public.app_role, '*', '*'),
    ('super_admin'::public.app_role, '*', '*'),
    ('admin'::public.app_role, 'sellers', 'view'),
    ('admin'::public.app_role, 'sellers', 'approve'),
    ('admin'::public.app_role, 'sellers', 'suspend'),
    ('admin'::public.app_role, 'kyc', 'view'),
    ('admin'::public.app_role, 'kyc', 'verify'),
    ('admin'::public.app_role, 'products', 'view'),
    ('admin'::public.app_role, 'products', 'approve'),
    ('admin'::public.app_role, 'finance', 'view'),
    ('admin'::public.app_role, 'finance', 'adjust'),
    ('admin'::public.app_role, 'commission', 'view'),
    ('admin'::public.app_role, 'commission', 'edit'),
    ('admin'::public.app_role, 'payouts', 'view'),
    ('admin'::public.app_role, 'payouts', 'hold'),
    ('admin'::public.app_role, 'roles', 'assign'),
    ('seller'::public.app_role, 'store', 'manage'),
    ('seller'::public.app_role, 'products', 'create'),
    ('seller'::public.app_role, 'kyc', 'submit'),
    ('buyer'::public.app_role, 'orders', 'create'),
    ('buyer'::public.app_role, 'products', 'view')
ON CONFLICT (role, module, action) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. IMMUTABLE AUDIT LOGS TABLE & TRIGGER (audit_logs)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_user_id UUID REFERENCES auth.users(id),
    actor_role public.app_role NOT NULL,
    action TEXT NOT NULL,
    target_type TEXT NOT NULL,
    target_id TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    correlation_id UUID DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.audit_logs FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.audit_logs TO authenticated;

DROP POLICY IF EXISTS "Admins can view audit logs" ON public.audit_logs;
CREATE POLICY "Admins can view audit logs" ON public.audit_logs
    FOR SELECT USING (public.is_admin());

-- Immutable Trigger: Block ANY direct UPDATE or DELETE on audit_logs
CREATE OR REPLACE FUNCTION public.prevent_audit_log_tampering()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Audit log records are immutable and cannot be modified or deleted.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

DROP TRIGGER IF EXISTS trg_prevent_audit_log_tampering ON public.audit_logs;
CREATE TRIGGER trg_prevent_audit_log_tampering
    BEFORE UPDATE OR DELETE ON public.audit_logs
    FOR EACH ROW EXECUTE PROCEDURE public.prevent_audit_log_tampering();

-- Internal Audit Logging Helper (Revoked from PUBLIC/client execution; only RPCs can invoke)
CREATE OR REPLACE FUNCTION public.internal_record_audit_log(
    p_target_type TEXT,
    p_target_id TEXT,
    p_action TEXT,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
DECLARE
    v_actor UUID;
    v_role public.app_role;
    v_id UUID;
BEGIN
    v_actor := auth.uid();
    IF v_actor IS NULL THEN
        RAISE EXCEPTION 'Authentication required for audit logging.';
    END IF;

    v_role := public.get_current_user_role();

    INSERT INTO public.audit_logs (
        actor_user_id,
        actor_role,
        action,
        target_type,
        target_id,
        metadata,
        correlation_id,
        created_at
    ) VALUES (
        v_actor,
        v_role,
        p_action,
        p_target_type,
        p_target_id,
        p_metadata,
        gen_random_uuid(),
        NOW()
    ) RETURNING id INTO v_id;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

REVOKE EXECUTE ON FUNCTION public.internal_record_audit_log(TEXT, TEXT, TEXT, JSONB) FROM PUBLIC, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 4. GRANULAR PERMISSION CHECKING FUNCTION (has_permission)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.has_permission(required_module TEXT, required_action TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_role public.app_role;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;

    v_role := public.get_current_user_role();

    -- Owner and Super Admin have full unrestricted privileges
    IF v_role IN ('owner'::public.app_role, 'super_admin'::public.app_role) THEN
        RETURN TRUE;
    END IF;

    -- Evaluate explicit permission mapping in role_permissions table
    RETURN EXISTS (
        SELECT 1 FROM public.role_permissions
        WHERE role = v_role
          AND (module = '*' OR module = required_module)
          AND (action = '*' OR action = required_action)
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

-- ----------------------------------------------------------------------------
-- 5. HARDENED & RETROFITTED PRIVILEGED RPC FUNCTIONS WITH AUDIT LOGGING
-- ----------------------------------------------------------------------------

-- A. assign_user_role
CREATE OR REPLACE FUNCTION public.assign_user_role(target_user_id UUID, new_role public.app_role)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT public.has_permission('roles', 'assign') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for role assignment.';
    END IF;

    INSERT INTO public.user_roles (user_id, role, granted_by)
    VALUES (target_user_id, new_role, auth.uid())
    ON CONFLICT (user_id, role) DO UPDATE SET granted_at = NOW(), granted_by = auth.uid();

    PERFORM public.internal_record_audit_log(
        'user_roles',
        target_user_id::text,
        'ASSIGN_USER_ROLE',
        jsonb_build_object('assigned_role', new_role::text)
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- B. admin_review_seller_store
CREATE OR REPLACE FUNCTION public.admin_review_seller_store(
    target_store_id UUID,
    approve BOOLEAN,
    new_commission NUMERIC(5,2) DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT public.has_permission('sellers', 'approve') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for seller store review.';
    END IF;

    UPDATE public.seller_stores
    SET is_approved = approve,
        commission_rate = COALESCE(new_commission, commission_rate),
        updated_at = NOW()
    WHERE id = target_store_id;

    PERFORM public.internal_record_audit_log(
        'seller_stores',
        target_store_id::text,
        'REVIEW_SELLER_STORE',
        jsonb_build_object('is_approved', approve, 'commission_rate', new_commission)
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- C. admin_review_kyc_document
CREATE OR REPLACE FUNCTION public.admin_review_kyc_document(
    target_kyc_id UUID,
    new_status TEXT,
    reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT public.has_permission('kyc', 'verify') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for KYC document review.';
    END IF;

    IF new_status NOT IN ('Approved', 'Rejected', 'Pending') THEN
        RAISE EXCEPTION 'Invalid KYC status value.';
    END IF;

    UPDATE public.seller_kyc_documents
    SET status = new_status,
        reviewed_by = auth.uid(),
        reviewed_at = NOW(),
        rejection_reason = reason,
        updated_at = NOW()
    WHERE id = target_kyc_id;

    IF new_status = 'Approved' THEN
        UPDATE public.seller_stores
        SET kyc_status = 'Approved', updated_at = NOW()
        WHERE id = (SELECT seller_store_id FROM public.seller_kyc_documents WHERE id = target_kyc_id);
    END IF;

    PERFORM public.internal_record_audit_log(
        'seller_kyc_documents',
        target_kyc_id::text,
        'REVIEW_KYC_DOCUMENT',
        jsonb_build_object('kyc_status', new_status, 'rejection_reason', reason)
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- D. admin_review_product
CREATE OR REPLACE FUNCTION public.admin_review_product(
    target_product_id UUID,
    approve BOOLEAN
)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT public.has_permission('products', 'approve') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for product approval.';
    END IF;

    -- Strict Self-Approval Protection: Sellers cannot approve their own products even if they possess an admin role
    IF EXISTS (
        SELECT 1 FROM public.products p
        JOIN public.seller_stores s ON s.id = p.seller_store_id
        WHERE p.id = target_product_id AND s.owner_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Access denied: Sellers cannot approve their own products.';
    END IF;

    UPDATE public.products
    SET approval_status = CASE WHEN approve THEN 'Approved' ELSE 'Rejected' END,
        updated_at = NOW()
    WHERE id = target_product_id;

    PERFORM public.internal_record_audit_log(
        'products',
        target_product_id::text,
        'REVIEW_PRODUCT',
        jsonb_build_object('approval_status', CASE WHEN approve THEN 'Approved' ELSE 'Rejected' END)
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- E. admin_adjust_seller_wallet (NEW FINANCIAL RPC)
CREATE OR REPLACE FUNCTION public.admin_adjust_seller_wallet(
    target_store_id UUID,
    amount_delta NUMERIC(12,2),
    reason TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_old_bal NUMERIC(12,2);
    v_new_bal NUMERIC(12,2);
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT public.has_permission('finance', 'adjust') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for wallet adjustment.';
    END IF;

    SELECT balance INTO v_old_bal FROM public.seller_stores WHERE id = target_store_id;
    IF v_old_bal IS NULL THEN
        RAISE EXCEPTION 'Target store not found.';
    END IF;

    v_new_bal := v_old_bal + amount_delta;
    IF v_new_bal < 0.00 THEN
        RAISE EXCEPTION 'Invalid transaction: Resulting balance cannot be negative.';
    END IF;

    UPDATE public.seller_stores
    SET balance = v_new_bal, updated_at = NOW()
    WHERE id = target_store_id;

    PERFORM public.internal_record_audit_log(
        'seller_stores',
        target_store_id::text,
        'ADJUST_SELLER_WALLET',
        jsonb_build_object('amount_delta', amount_delta, 'old_balance', v_old_bal, 'new_balance', v_new_bal, 'reason', reason)
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- F. admin_toggle_seller_suspension (NEW GOVERNANCE RPC)
CREATE OR REPLACE FUNCTION public.admin_toggle_seller_suspension(
    target_store_id UUID,
    suspend BOOLEAN,
    reason TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT public.has_permission('sellers', 'suspend') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for seller suspension.';
    END IF;

    UPDATE public.seller_stores
    SET is_suspended = suspend, updated_at = NOW()
    WHERE id = target_store_id;

    PERFORM public.internal_record_audit_log(
        'seller_stores',
        target_store_id::text,
        'TOGGLE_SELLER_SUSPENSION',
        jsonb_build_object('is_suspended', suspend, 'reason', reason)
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- G. admin_toggle_payout_lock (NEW FINANCIAL GOVERNANCE RPC)
CREATE OR REPLACE FUNCTION public.admin_toggle_payout_lock(
    target_store_id UUID,
    lock_state BOOLEAN,
    reason TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT public.has_permission('payouts', 'hold') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for payout lock management.';
    END IF;

    UPDATE public.seller_stores
    SET payout_locked = lock_state, updated_at = NOW()
    WHERE id = target_store_id;

    PERFORM public.internal_record_audit_log(
        'seller_stores',
        target_store_id::text,
        'TOGGLE_PAYOUT_LOCK',
        jsonb_build_object('payout_locked', lock_state, 'reason', reason)
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- H. assign_role_permission (OWNER / SUPER ADMIN PERMISSION MANAGEMENT RPC)
CREATE OR REPLACE FUNCTION public.assign_role_permission(
    target_role public.app_role,
    target_module TEXT,
    target_action TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    -- Only Owner and Super Admin can manage role_permissions mapping
    IF public.get_current_user_role() NOT IN ('owner'::public.app_role, 'super_admin'::public.app_role) THEN
        RAISE EXCEPTION 'Access denied: Owner or Super Admin privileges required for permission management.';
    END IF;

    INSERT INTO public.role_permissions (role, module, action)
    VALUES (target_role, target_module, target_action)
    ON CONFLICT (role, module, action) DO NOTHING;

    PERFORM public.internal_record_audit_log(
        'role_permissions',
        target_role::text,
        'ASSIGN_ROLE_PERMISSION',
        jsonb_build_object('module', target_module, 'action', target_action)
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Revoke execution of privileged RPCs from PUBLIC/anon
REVOKE EXECUTE ON FUNCTION public.assign_user_role(UUID, public.app_role) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_review_seller_store(UUID, BOOLEAN, NUMERIC) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_review_kyc_document(UUID, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_review_product(UUID, BOOLEAN) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_adjust_seller_wallet(UUID, NUMERIC, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_toggle_seller_suspension(UUID, BOOLEAN, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_toggle_payout_lock(UUID, BOOLEAN, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.assign_role_permission(public.app_role, TEXT, TEXT) FROM PUBLIC, anon;

-- Grant execution of privileged RPCs to authenticated role (internal permissions checked inside functions)
GRANT EXECUTE ON FUNCTION public.assign_user_role(UUID, public.app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_seller_store(UUID, BOOLEAN, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_kyc_document(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_product(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_adjust_seller_wallet(UUID, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_toggle_seller_suspension(UUID, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_toggle_payout_lock(UUID, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_role_permission(public.app_role, TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 6. MIGRATION COMPLETION NOTICE
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE 'Migration 20260806000000 (Phase 6 RBAC, Server Security & Immutable Audit Logs) completed successfully.';
END $$;
-- ============================================================================
-- MIGRATION: 20260807000000_phase_7_storage_and_kyc_security.sql
-- PURPOSE: Supabase Storage Security, Private KYC Bucket, Signed URLs, and Complete Seller Lifecycle
-- ============================================================================

-- 1. Ensure Storage Buckets Exist & Configured Correctly
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
    ('kyc-documents', 'kyc-documents', FALSE, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
    ('seller-store-media', 'seller-store-media', TRUE, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET 
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2. Consolidate All Phase 7 Storage Path & Governance Columns into Single Canonical public.seller_kyc_documents & seller_stores
ALTER TABLE public.seller_kyc_documents
    ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS cnic_number TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS cnic_front_path TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS cnic_back_path TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS selfie_path TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS resubmission_instructions TEXT DEFAULT '';

ALTER TABLE public.seller_stores
    ADD COLUMN IF NOT EXISTS cnic_front_path TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS cnic_back_path TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS selfie_path TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS shop_logo_path TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS shop_banner_path TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS rejection_reason TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS resubmission_instructions TEXT DEFAULT '';

-- 3. Safely Extend seller_stores.kyc_status CHECK Constraint to Include 'ResubmissionRequired'
ALTER TABLE public.seller_stores
    DROP CONSTRAINT IF EXISTS seller_stores_kyc_status_check;

ALTER TABLE public.seller_stores
    ADD CONSTRAINT seller_stores_kyc_status_check 
    CHECK (kyc_status IN ('Pending', 'Approved', 'Rejected', 'ResubmissionRequired'));

-- ----------------------------------------------------------------------------
-- RLS POLICIES FOR PRIVATE 'kyc-documents' BUCKET
-- ----------------------------------------------------------------------------

-- A. Public / Anonymous Read Denied
DROP POLICY IF EXISTS "Public read on kyc-documents denied" ON storage.objects;
CREATE POLICY "Public read on kyc-documents denied"
    ON storage.objects FOR SELECT
    TO anon
    USING (FALSE);

-- B. Authenticated Owner or Admin with 'kyc:view' Can Read KYC Objects
DROP POLICY IF EXISTS "Owner or KYC Admin can view KYC storage objects" ON storage.objects;
CREATE POLICY "Owner or KYC Admin can view KYC storage objects"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'kyc-documents'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR public.has_permission('kyc', 'view')
        )
    );

-- C. Authenticated Seller Can Insert into Own Folder in 'kyc-documents'
DROP POLICY IF EXISTS "Sellers can upload own KYC documents" ON storage.objects;
CREATE POLICY "Sellers can upload own KYC documents"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'kyc-documents'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- D. Owner or Admin Can Delete KYC Objects
DROP POLICY IF EXISTS "Owner or Admin can delete KYC documents" ON storage.objects;
CREATE POLICY "Owner or Admin can delete KYC documents"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'kyc-documents'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR public.has_permission('kyc', 'verify')
        )
    );

-- ----------------------------------------------------------------------------
-- RLS POLICIES FOR PUBLIC 'seller-store-media' BUCKET
-- ----------------------------------------------------------------------------

-- A. Anyone (Public & Anon) Can View Seller Store Logos & Banners
DROP POLICY IF EXISTS "Public can view seller store media" ON storage.objects;
CREATE POLICY "Public can view seller store media"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'seller-store-media');

-- B. Authenticated Seller Can Upload Store Media to Own Folder
DROP POLICY IF EXISTS "Sellers can upload own store media" ON storage.objects;
CREATE POLICY "Sellers can upload own store media"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'seller-store-media'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- C. Authenticated Seller Can Update Own Store Media
DROP POLICY IF EXISTS "Sellers can update own store media" ON storage.objects;
CREATE POLICY "Sellers can update own store media"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'seller-store-media'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- ----------------------------------------------------------------------------
-- 4. HARDENED SECURITY DEFINER RPC: VERIFY & AUTHORIZE KYC ACCESS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.authorize_kyc_document_access(p_owner_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Owner can access own document
    IF auth.uid() = p_owner_id THEN
        RETURN TRUE;
    END IF;

    -- Admin with 'kyc:view' permission can access
    RETURN public.has_permission('kyc', 'view');
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.authorize_kyc_document_access(UUID) TO authenticated;

-- ----------------------------------------------------------------------------
-- 5. HARDENED & RETROFITTED SELLER APPLICATION REVIEW RPC
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_review_seller_application(
    p_store_id UUID,
    p_decision TEXT,
    p_reason TEXT DEFAULT '',
    p_resubmission_instructions TEXT DEFAULT ''
)
RETURNS BOOLEAN AS $$
DECLARE
    v_owner_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT public.has_permission('sellers', 'approve') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for seller store review.';
    END IF;

    SELECT owner_id INTO v_owner_id
    FROM public.seller_stores
    WHERE id = p_store_id;

    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'Seller store not found.';
    END IF;

    -- Self-review check: Seller cannot review own application
    IF v_owner_id = auth.uid() THEN
        RAISE EXCEPTION 'Self-review of seller application is forbidden.';
    END IF;

    IF p_decision NOT IN ('Approved', 'Rejected', 'ResubmissionRequired') THEN
        RAISE EXCEPTION 'Invalid review decision. Must be Approved, Rejected, or ResubmissionRequired.';
    END IF;

    -- Non-empty reason validation for Rejection or Resubmission
    IF p_decision IN ('Rejected', 'ResubmissionRequired') AND trim(COALESCE(p_reason, '')) = '' THEN
        RAISE EXCEPTION 'Rejection or resubmission request requires a non-empty reason.';
    END IF;

    IF p_decision = 'Approved' THEN
        UPDATE public.seller_stores
        SET is_approved = TRUE,
            kyc_status = 'Approved',
            is_verified = TRUE,
            rejection_reason = '',
            resubmission_instructions = '',
            updated_at = NOW()
        WHERE id = p_store_id;

        -- Provision trusted seller role upon approval
        INSERT INTO public.user_roles (user_id, role, granted_by)
        VALUES (v_owner_id, 'seller'::public.app_role, auth.uid())
        ON CONFLICT (user_id, role) DO UPDATE SET granted_at = NOW(), granted_by = auth.uid();

    ELSIF p_decision = 'Rejected' THEN
        UPDATE public.seller_stores
        SET is_approved = FALSE,
            kyc_status = 'Rejected',
            is_verified = FALSE,
            rejection_reason = trim(p_reason),
            resubmission_instructions = '',
            updated_at = NOW()
        WHERE id = p_store_id;

    ELSIF p_decision = 'ResubmissionRequired' THEN
        UPDATE public.seller_stores
        SET is_approved = FALSE,
            kyc_status = 'ResubmissionRequired',
            is_verified = FALSE,
            rejection_reason = trim(p_reason),
            resubmission_instructions = COALESCE(NULLIF(trim(p_resubmission_instructions), ''), trim(p_reason)),
            updated_at = NOW()
        WHERE id = p_store_id;
    END IF;

    -- Write immutable audit log entry
    PERFORM public.internal_record_audit_log(
        'seller_stores',
        p_store_id::text,
        'REVIEW_SELLER_APPLICATION',
        jsonb_build_object(
            'decision', p_decision,
            'reason', p_reason,
            'instructions', p_resubmission_instructions,
            'seller_owner_id', v_owner_id
        )
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.admin_review_seller_application(UUID, TEXT, TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 6. SELLER KYC RESUBMISSION RPC
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.seller_submit_kyc_resubmission(
    p_store_id UUID,
    p_cnic_front_path TEXT,
    p_cnic_back_path TEXT,
    p_selfie_path TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_owner_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    SELECT owner_id INTO v_owner_id
    FROM public.seller_stores
    WHERE id = p_store_id;

    IF v_owner_id IS NULL THEN
        RAISE EXCEPTION 'Seller store not found.';
    END IF;

    IF v_owner_id <> auth.uid() THEN
        RAISE EXCEPTION 'Access denied: Cannot resubmit KYC for another seller.';
    END IF;

    UPDATE public.seller_stores
    SET cnic_front_path = p_cnic_front_path,
        cnic_back_path = p_cnic_back_path,
        selfie_path = p_selfie_path,
        kyc_status = 'Pending',
        is_approved = FALSE,
        rejection_reason = '',
        resubmission_instructions = '',
        updated_at = NOW()
    WHERE id = p_store_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.seller_submit_kyc_resubmission(UUID, TEXT, TEXT, TEXT) TO authenticated;
-- ============================================================================
-- MIGRATION: 20260808000000_phase_8_catalog_and_inventory.sql
-- PURPOSE: Marketplace Catalog, Products, Moderation Lifecycle, Variants/SKUs & Inventory Security
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. NORMALIZE PRODUCT APPROVAL STATUS & CONSTRAINTS
-- ----------------------------------------------------------------------------

-- Migration: Update legacy 'Pending' values to 'PendingReview'
UPDATE public.products
SET approval_status = 'PendingReview'
WHERE approval_status = 'Pending';

ALTER TABLE public.products
    DROP CONSTRAINT IF EXISTS products_approval_status_check;

ALTER TABLE public.products
    ADD CONSTRAINT products_approval_status_check 
    CHECK (approval_status IN ('Draft', 'PendingReview', 'Approved', 'Rejected', 'Archived'));

ALTER TABLE public.products
    ALTER COLUMN approval_status SET DEFAULT 'PendingReview';

-- Enforce valid sale_price rule (sale_price <= price)
ALTER TABLE public.products
    DROP CONSTRAINT IF EXISTS products_sale_price_check;

ALTER TABLE public.products
    ADD CONSTRAINT products_sale_price_check 
    CHECK (sale_price IS NULL OR (sale_price >= 0.00 AND sale_price <= price));

-- ----------------------------------------------------------------------------
-- 2. HELPER FUNCTION: STORE OPERATIONAL STATUS VALIDATION
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_approved_active_seller_store(p_store_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.seller_stores
        WHERE id = p_store_id
          AND is_approved = TRUE
          AND is_suspended = FALSE
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.is_approved_active_seller_store(UUID) TO authenticated, anon;

-- ----------------------------------------------------------------------------
-- 3. CANONICAL PRODUCT VARIANTS TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.product_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    seller_store_id UUID NOT NULL REFERENCES public.seller_stores(id) ON DELETE CASCADE,
    sku TEXT NOT NULL,
    variant_name TEXT NOT NULL,
    attributes JSONB NOT NULL DEFAULT '{}'::jsonb,
    price_override NUMERIC(12,2) CHECK (price_override IS NULL OR price_override >= 0.00),
    stock_quantity INT NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT product_variants_store_sku_key UNIQUE (seller_store_id, sku)
);

ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_product_variants_product_id ON public.product_variants(product_id);
CREATE INDEX IF NOT EXISTS idx_product_variants_store_id ON public.product_variants(seller_store_id);

-- ----------------------------------------------------------------------------
-- 4. PRODUCT IMAGES STORAGE BUCKET & RLS POLICIES
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('product-images', 'product-images', TRUE, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET 
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Public view product images" ON storage.objects;
CREATE POLICY "Public view product images" ON storage.objects
    FOR SELECT USING (bucket_id = 'product-images');

DROP POLICY IF EXISTS "Sellers upload product images to own folder" ON storage.objects;
CREATE POLICY "Sellers upload product images to own folder" ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'product-images'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Sellers update product images in own folder" ON storage.objects;
CREATE POLICY "Sellers update product images in own folder" ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id = 'product-images'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Sellers delete product images in own folder" ON storage.objects;
CREATE POLICY "Sellers delete product images in own folder" ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'product-images'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- ----------------------------------------------------------------------------
-- 5. BLOCK DIRECT CLIENT STOCK MANIPULATION & GRANT SAFE COLUMN PRIVILEGES
-- ----------------------------------------------------------------------------
GRANT SELECT ON public.categories TO PUBLIC, anon, authenticated;
GRANT INSERT (name, slug, icon, banner_url, display_order) ON public.categories TO authenticated;
GRANT UPDATE (name, slug, icon, banner_url, is_active, display_order) ON public.categories TO authenticated;

REVOKE UPDATE (stock_quantity) ON public.products FROM PUBLIC, anon, authenticated;
REVOKE UPDATE (stock_quantity) ON public.product_variants FROM PUBLIC, anon, authenticated;

-- Grant safe column updates for sellers
GRANT UPDATE (name, description, price, sale_price, category_id, image_url, category, is_active) ON public.products TO authenticated;
GRANT UPDATE (variant_name, attributes, price_override, is_active) ON public.product_variants TO authenticated;

GRANT SELECT ON public.product_variants TO PUBLIC, anon, authenticated;
GRANT INSERT (product_id, seller_store_id, sku, variant_name, attributes, price_override) ON public.product_variants TO authenticated;

-- ----------------------------------------------------------------------------
-- 6. RLS POLICIES FOR PRODUCTS & VARIANTS
-- ----------------------------------------------------------------------------

-- A. Buyer / Public SELECT Policy on Products
DROP POLICY IF EXISTS "Public view approved active products; Owner/Admin view all" ON public.products;
DROP POLICY IF EXISTS "Public view approved active products from active stores" ON public.products;
CREATE POLICY "Public view approved active products from active stores" ON public.products
    FOR SELECT USING (
        (
            approval_status = 'Approved'
            AND is_active = TRUE
            AND public.is_approved_active_seller_store(seller_store_id)
        )
        OR public.owns_seller_store(seller_store_id)
        OR public.is_admin()
    );

-- B. Seller INSERT Policy on Products (Must own store AND store must be approved & non-suspended)
DROP POLICY IF EXISTS "Approved sellers insert products for own store" ON public.products;
DROP POLICY IF EXISTS "Approved active sellers insert products for own store" ON public.products;
CREATE POLICY "Approved active sellers insert products for own store" ON public.products
    FOR INSERT TO authenticated
    WITH CHECK (
        public.owns_seller_store(seller_store_id)
        AND public.is_approved_active_seller_store(seller_store_id)
    );

-- C. Seller UPDATE Policy on Products
DROP POLICY IF EXISTS "Sellers update safe product details" ON public.products;
DROP POLICY IF EXISTS "Approved active sellers update own products" ON public.products;
CREATE POLICY "Approved active sellers update own products" ON public.products
    FOR UPDATE TO authenticated
    USING (
        (
            public.owns_seller_store(seller_store_id)
            AND public.is_approved_active_seller_store(seller_store_id)
        )
        OR public.is_admin()
    );

-- D. RLS Policies on Product Variants
DROP POLICY IF EXISTS "Public view active product variants" ON public.product_variants;
CREATE POLICY "Public view active product variants" ON public.product_variants
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.products p
            WHERE p.id = product_id
              AND p.approval_status = 'Approved'
              AND p.is_active = TRUE
              AND public.is_approved_active_seller_store(p.seller_store_id)
        )
        OR public.owns_seller_store(seller_store_id)
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "Sellers insert variants for own products" ON public.product_variants;
CREATE POLICY "Sellers insert variants for own products" ON public.product_variants
    FOR INSERT TO authenticated
    WITH CHECK (
        public.owns_seller_store(seller_store_id)
        AND public.is_approved_active_seller_store(seller_store_id)
        AND EXISTS (
            SELECT 1 FROM public.products p
            WHERE p.id = product_id AND p.seller_store_id = seller_store_id
        )
    );

DROP POLICY IF EXISTS "Sellers update variants for own products" ON public.product_variants;
CREATE POLICY "Sellers update variants for own products" ON public.product_variants
    FOR UPDATE TO authenticated
    USING (
        (
            public.owns_seller_store(seller_store_id)
            AND public.is_approved_active_seller_store(seller_store_id)
        )
        OR public.is_admin()
    );

-- ----------------------------------------------------------------------------
-- 7. CONTROLLED INVENTORY MANAGEMENT RPCs
-- ----------------------------------------------------------------------------

-- A. Seller Update Product Stock
CREATE OR REPLACE FUNCTION public.seller_update_product_stock(
    p_product_id UUID,
    p_new_stock INT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_store_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    SELECT seller_store_id INTO v_store_id
    FROM public.products
    WHERE id = p_product_id;

    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'Product not found.';
    END IF;

    IF NOT public.owns_seller_store(v_store_id) THEN
        RAISE EXCEPTION 'Access denied: Cannot manage inventory for another seller store.';
    END IF;

    IF NOT public.is_approved_active_seller_store(v_store_id) THEN
        RAISE EXCEPTION 'Access denied: Store is not approved or is suspended.';
    END IF;

    IF p_new_stock < 0 THEN
        RAISE EXCEPTION 'Stock quantity cannot be negative.';
    END IF;

    UPDATE public.products
    SET stock_quantity = p_new_stock,
        updated_at = NOW()
    WHERE id = p_product_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.seller_update_product_stock(UUID, INT) TO authenticated;

-- B. Seller Update Variant Stock
CREATE OR REPLACE FUNCTION public.seller_update_variant_stock(
    p_variant_id UUID,
    p_new_stock INT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_store_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    SELECT seller_store_id INTO v_store_id
    FROM public.product_variants
    WHERE id = p_variant_id;

    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'Product variant not found.';
    END IF;

    IF NOT public.owns_seller_store(v_store_id) THEN
        RAISE EXCEPTION 'Access denied: Cannot manage inventory for another seller store.';
    END IF;

    IF NOT public.is_approved_active_seller_store(v_store_id) THEN
        RAISE EXCEPTION 'Access denied: Store is not approved or is suspended.';
    END IF;

    IF p_new_stock < 0 THEN
        RAISE EXCEPTION 'Stock quantity cannot be negative.';
    END IF;

    UPDATE public.product_variants
    SET stock_quantity = p_new_stock,
        updated_at = NOW()
    WHERE id = p_variant_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.seller_update_variant_stock(UUID, INT) TO authenticated;

-- C. Internal Atomic Stock Decrement (Trusted Foundation for Phase 9 Checkout)
CREATE OR REPLACE FUNCTION public.internal_decrement_product_stock(
    p_product_id UUID,
    p_quantity INT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_rows_affected INT;
BEGIN
    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Decrement quantity must be greater than zero.';
    END IF;

    -- Atomic conditional update in single SQL statement
    UPDATE public.products
    SET stock_quantity = stock_quantity - p_quantity,
        updated_at = NOW()
    WHERE id = p_product_id
      AND stock_quantity >= p_quantity;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    IF v_rows_affected = 0 THEN
        RAISE EXCEPTION 'Insufficient stock quantity or product not found.';
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Strictly revoke execution from client roles (Phase 9 trusted execution only)
REVOKE EXECUTE ON FUNCTION public.internal_decrement_product_stock(UUID, INT) FROM PUBLIC, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 8. HARDENED ADMIN PRODUCT MODERATION RPC
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.admin_review_product(UUID, BOOLEAN);

CREATE OR REPLACE FUNCTION public.admin_review_product(
    target_product_id UUID,
    approve BOOLEAN,
    reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_store_id UUID;
    v_new_status TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT public.has_permission('products', 'approve') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for product moderation.';
    END IF;

    SELECT seller_store_id INTO v_store_id
    FROM public.products
    WHERE id = target_product_id;

    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'Target product not found.';
    END IF;

    -- Self-approval check: Seller cannot approve own product
    IF public.owns_seller_store(v_store_id) THEN
        RAISE EXCEPTION 'Sellers cannot approve their own products.';
    END IF;

    IF approve THEN
        v_new_status := 'Approved';
    ELSE
        v_new_status := 'Rejected';
        IF trim(COALESCE(reason, '')) = '' THEN
            RAISE EXCEPTION 'Product rejection requires a non-empty reason.';
        END IF;
    END IF;

    UPDATE public.products
    SET approval_status = v_new_status,
        updated_at = NOW()
    WHERE id = target_product_id;

    PERFORM public.internal_record_audit_log(
        'products',
        target_product_id::text,
        'REVIEW_PRODUCT',
        jsonb_build_object('approval_status', v_new_status, 'rejection_reason', reason, 'seller_store_id', v_store_id)
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.admin_review_product(UUID, BOOLEAN, TEXT) TO authenticated;
-- ============================================================================
-- MIGRATION: 20260809000000_phase_9_cart_checkout_atomic_orders.sql
-- PURPOSE: Cart, Atomic Checkout & Server-Authoritative Idempotent Order Creation
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. ENHANCE BUYER_ORDERS SCHEMA WITH CANONICAL COLUMNS, FINGERPRINT & IDEMPOTENCY
-- ----------------------------------------------------------------------------

-- Collision-free Sequence for Order Numbers
CREATE SEQUENCE IF NOT EXISTS public.order_number_seq START WITH 100000 INCREMENT BY 1;

-- Add order_number, request_fingerprint, idempotency_key, and financial columns
ALTER TABLE public.buyer_orders
    ADD COLUMN IF NOT EXISTS order_number TEXT UNIQUE,
    ADD COLUMN IF NOT EXISTS idempotency_key TEXT,
    ADD COLUMN IF NOT EXISTS request_fingerprint TEXT,
    ADD COLUMN IF NOT EXISTS subtotal NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (subtotal >= 0.00),
    ADD COLUMN IF NOT EXISTS shipping_fee NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (shipping_fee >= 0.00),
    ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (discount_amount >= 0.00),
    ADD COLUMN IF NOT EXISTS grand_total NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (grand_total >= 0.00),
    ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'Pending' CHECK (payment_status IN ('Pending', 'Paid', 'Failed')),
    ADD COLUMN IF NOT EXISTS shipping_address JSONB NOT NULL DEFAULT '{}'::jsonb;

-- Idempotency constraint per authenticated buyer
ALTER TABLE public.buyer_orders
    DROP CONSTRAINT IF EXISTS buyer_orders_user_idempotency_key;

ALTER TABLE public.buyer_orders
    ADD CONSTRAINT buyer_orders_user_idempotency_key UNIQUE (customer_user_id, idempotency_key);

CREATE INDEX IF NOT EXISTS idx_buyer_orders_order_number ON public.buyer_orders(order_number);
CREATE INDEX IF NOT EXISTS idx_buyer_orders_idempotency ON public.buyer_orders(customer_user_id, idempotency_key);

-- ----------------------------------------------------------------------------
-- 2. CANONICAL ORDER ITEMS TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id TEXT NOT NULL REFERENCES public.buyer_orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id),
    variant_id UUID REFERENCES public.product_variants(id),
    seller_store_id UUID NOT NULL REFERENCES public.seller_stores(id),
    product_name TEXT NOT NULL,
    sku TEXT NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0.00),
    sale_price NUMERIC(12,2) CHECK (sale_price IS NULL OR sale_price >= 0.00),
    quantity INT NOT NULL CHECK (quantity > 0),
    total_price NUMERIC(12,2) NOT NULL CHECK (total_price >= 0.00),
    commission_rate NUMERIC(5,2) NOT NULL DEFAULT 10.00 CHECK (commission_rate >= 0.00),
    commission_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (commission_amount >= 0.00),
    seller_payable NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (seller_payable >= 0.00),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_seller_store ON public.order_items(seller_store_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product ON public.order_items(product_id);

-- ----------------------------------------------------------------------------
-- 3. CANONICAL ORDER STATUS HISTORY TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.order_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id TEXT NOT NULL REFERENCES public.buyer_orders(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled')),
    notes TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.order_status_history ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_order_status_history_order ON public.order_status_history(order_id);

-- ----------------------------------------------------------------------------
-- 4. BLOCK DIRECT CLIENT MUTATIONS ON ORDER TABLES
-- ----------------------------------------------------------------------------
REVOKE ALL ON public.buyer_orders FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.order_items FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.order_status_history FROM PUBLIC, anon, authenticated;

-- Grant safe SELECT privileges for clients
GRANT SELECT ON public.buyer_orders TO authenticated;
GRANT SELECT ON public.order_items TO authenticated;
GRANT SELECT ON public.order_status_history TO authenticated;

-- ----------------------------------------------------------------------------
-- 5. HELPER FUNCTION & RLS POLICIES FOR ORDER TABLES (RECURSION-SAFE & SELLER-SAFE)
-- ----------------------------------------------------------------------------

-- Helper: Check if seller owns any line item in target order (SECURITY DEFINER to avoid RLS recursion)
CREATE OR REPLACE FUNCTION public.seller_owns_order_item(p_order_id TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1 FROM public.order_items oi
        JOIN public.seller_stores ss ON ss.id = oi.seller_store_id
        WHERE oi.order_id = p_order_id
          AND ss.owner_id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.seller_owns_order_item(TEXT) TO authenticated;

-- A. buyer_orders RLS Policies (Strict Buyer & Admin isolation; Seller reads via get_seller_orders RPC)
DROP POLICY IF EXISTS "Buyers view own orders; Admins view all" ON public.buyer_orders;
DROP POLICY IF EXISTS "Buyers view own orders; Sellers view store orders; Admins view all" ON public.buyer_orders;
CREATE POLICY "Buyers view own orders; Sellers view store orders; Admins view all" ON public.buyer_orders
    FOR SELECT USING (
        customer_user_id = auth.uid()
        OR public.is_admin()
        OR public.seller_owns_order_item(id)
    );

-- B. order_items RLS Policies (Seller sees ONLY own store items; Buyer sees own order items)
DROP POLICY IF EXISTS "Buyers view own order items; Sellers view store items; Admins view all" ON public.order_items;
CREATE POLICY "Buyers view own order items; Sellers view store items; Admins view all" ON public.order_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.buyer_orders bo
            WHERE bo.id = public.order_items.order_id
              AND bo.customer_user_id = auth.uid()
        )
        OR public.owns_seller_store(seller_store_id)
        OR public.is_admin()
    );

-- C. order_status_history RLS Policies
DROP POLICY IF EXISTS "Buyers view own status history; Admins view all" ON public.order_status_history;
CREATE POLICY "Buyers view own status history; Admins view all" ON public.order_status_history
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.buyer_orders bo
            WHERE bo.id = public.order_status_history.order_id
              AND bo.customer_user_id = auth.uid()
        )
        OR public.seller_owns_order_item(order_id)
        OR public.is_admin()
    );

-- D. Seller-Safe Order RPC (Isolates Seller to own store items/payable without exposing cross-seller grand totals)
CREATE OR REPLACE FUNCTION public.get_seller_orders()
RETURNS TABLE (
    order_id TEXT,
    order_number TEXT,
    order_date TIMESTAMPTZ,
    order_status TEXT,
    customer_name TEXT,
    store_subtotal NUMERIC(12,2),
    store_payable NUMERIC(12,2),
    items JSONB
) AS $$
DECLARE
    v_seller_id UUID;
BEGIN
    v_seller_id := auth.uid();
    IF v_seller_id IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT 
        bo.id AS order_id,
        bo.order_number,
        bo.created_at AS order_date,
        bo.status AS order_status,
        bo.customer_name,
        SUM(oi.total_price)::NUMERIC(12,2) AS store_subtotal,
        SUM(oi.seller_payable)::NUMERIC(12,2) AS store_payable,
        jsonb_agg(
            jsonb_build_object(
                'item_id', oi.id,
                'product_id', oi.product_id,
                'product_name', oi.product_name,
                'sku', oi.sku,
                'unit_price', oi.unit_price,
                'quantity', oi.quantity,
                'total_price', oi.total_price,
                'commission_amount', oi.commission_amount,
                'seller_payable', oi.seller_payable
            )
        ) AS items
    FROM public.order_items oi
    JOIN public.buyer_orders bo ON bo.id = oi.order_id
    JOIN public.seller_stores ss ON ss.id = oi.seller_store_id
    WHERE ss.owner_id = v_seller_id
    GROUP BY bo.id, bo.order_number, bo.created_at, bo.status, bo.customer_name;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.get_seller_orders() TO authenticated;

-- ----------------------------------------------------------------------------
-- 6. ATOMIC CHECKOUT & ORDER CREATION RPC (WITH RACE-CONDITION SAFETY)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_atomic_order(
    p_idempotency_key TEXT,
    p_items JSONB,
    p_shipping_address JSONB,
    p_payment_method TEXT DEFAULT 'COD'
)
RETURNS JSONB AS $$
DECLARE
    v_buyer_id UUID;
    v_buyer_name TEXT;
    v_buyer_email TEXT;
    v_order_id TEXT;
    v_order_number TEXT;
    v_fingerprint TEXT;
    v_existing_order_id TEXT;
    v_existing_fingerprint TEXT;
    v_item JSONB;
    v_product_id UUID;
    v_variant_id UUID;
    v_requested_qty INT;
    v_aggregated_items JSONB := '[]'::jsonb;
    
    -- Fetched Database Details
    v_store_id UUID;
    v_product_name TEXT;
    v_product_sku TEXT;
    v_unit_price NUMERIC(12,2);
    v_sale_price NUMERIC(12,2);
    v_effective_price NUMERIC(12,2);
    v_item_total NUMERIC(12,2);
    v_commission_rate NUMERIC(5,2) := 10.00;
    v_commission_amount NUMERIC(12,2);
    v_seller_payable NUMERIC(12,2);

    -- Running Order Totals
    v_calculated_subtotal NUMERIC(12,2) := 0.00;
    v_calculated_shipping NUMERIC(12,2) := 0.00;
    v_calculated_discount NUMERIC(12,2) := 0.00;
    v_calculated_grand_total NUMERIC(12,2) := 0.00;
    v_rows_affected INT;
    v_result JSONB;
BEGIN
    -- Step 1: Authentication Check
    v_buyer_id := auth.uid();
    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    -- Validate Idempotency Key
    IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
        RAISE EXCEPTION 'Idempotency key is required for checkout.';
    END IF;

    -- Step 2: Input Array Validation & Duplicate Line Aggregation
    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Cart items array cannot be empty.';
    END IF;

    -- Aggregate item quantities by product_id + variant_id (sorted for canonical fingerprinting)
    SELECT jsonb_agg(
        jsonb_build_object(
            'product_id', product_id,
            'variant_id', variant_id,
            'quantity', total_qty
        )
    ) INTO v_aggregated_items
    FROM (
        SELECT 
            (elem->>'product_id')::UUID AS product_id,
            NULLIF(elem->>'variant_id', '')::UUID AS variant_id,
            SUM((elem->>'quantity')::INT) AS total_qty
        FROM jsonb_array_elements(p_items) AS elem
        GROUP BY 1, 2
        ORDER BY 1, 2
    ) sub;

    -- Step 3: Server-Side Payment Method Gate (COD only for Phase 9; digital methods arrive in Phase 10)
    IF p_payment_method <> 'COD' THEN
        RAISE EXCEPTION 'Payment method % is not currently available.', p_payment_method;
    END IF;

    -- Step 4: Compute Canonical Request Fingerprint
    v_fingerprint := md5(v_aggregated_items::text || '|' || COALESCE(p_shipping_address::text, '{}') || '|' || p_payment_method);

    -- Step 5: Idempotency & Conflict Check
    SELECT id, request_fingerprint INTO v_existing_order_id, v_existing_fingerprint
    FROM public.buyer_orders
    WHERE customer_user_id = v_buyer_id
      AND idempotency_key = p_idempotency_key;

    IF v_existing_order_id IS NOT NULL THEN
        IF v_existing_fingerprint IS NOT NULL AND v_existing_fingerprint <> v_fingerprint THEN
            RAISE EXCEPTION 'Idempotency conflict: Key % was already used with a different request payload.', p_idempotency_key;
        END IF;

        SELECT jsonb_build_object(
            'success', TRUE,
            'idempotent_reused', TRUE,
            'order_id', bo.id,
            'order_number', bo.order_number,
            'grand_total', bo.grand_total,
            'status', bo.status
        ) INTO v_result
        FROM public.buyer_orders bo
        WHERE bo.id = v_existing_order_id;

        RETURN v_result;
    END IF;

    -- Step 6: Fetch Buyer Profile Details
    SELECT COALESCE(full_name, 'Valued Buyer'), COALESCE(email, 'buyer@example.com')
    INTO v_buyer_name, v_buyer_email
    FROM public.profiles
    WHERE id = v_buyer_id;

    IF v_buyer_name IS NULL THEN
        v_buyer_name := 'Valued Buyer';
        v_buyer_email := 'buyer@example.com';
    END IF;

    -- Generate Primary Identifiers (Sequence-backed collision-safe order_number)
    v_order_id := gen_random_uuid()::text;
    v_order_number := 'ORD-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || LPAD(nextval('public.order_number_seq')::TEXT, 6, '0');

    -- Insert Parent Order Container with Race-Condition Safety (Catches concurrent unique_violation)
    BEGIN
        INSERT INTO public.buyer_orders (
            id, order_number, idempotency_key, request_fingerprint, customer_user_id, customer_name, customer_email,
            amount, subtotal, shipping_fee, discount_amount, grand_total, payment_method, payment_status,
            shipping_address, status
        ) VALUES (
            v_order_id, v_order_number, p_idempotency_key, v_fingerprint, v_buyer_id, v_buyer_name, v_buyer_email,
            0.00, 0.00, 0.00, 0.00, 0.00, p_payment_method, 'Pending',
            p_shipping_address, 'Pending'
        );
    EXCEPTION WHEN unique_violation THEN
        -- Concurrent insert race on (customer_user_id, idempotency_key) detected cleanly
        SELECT id, request_fingerprint INTO v_existing_order_id, v_existing_fingerprint
        FROM public.buyer_orders
        WHERE customer_user_id = v_buyer_id
          AND idempotency_key = p_idempotency_key;

        IF v_existing_order_id IS NOT NULL THEN
            IF v_existing_fingerprint IS NOT NULL AND v_existing_fingerprint <> v_fingerprint THEN
                RAISE EXCEPTION 'Idempotency conflict: Key % was already used with a different request payload.', p_idempotency_key;
            END IF;

            SELECT jsonb_build_object(
                'success', TRUE,
                'idempotent_reused', TRUE,
                'order_id', bo.id,
                'order_number', bo.order_number,
                'grand_total', bo.grand_total,
                'status', bo.status
            ) INTO v_result
            FROM public.buyer_orders bo
            WHERE bo.id = v_existing_order_id;

            RETURN v_result;
        END IF;
    END;

    -- Step 7: Loop & Validate Items, Perform Atomic Stock Mutation & Calculate Totals
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_aggregated_items)
    LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_variant_id := NULLIF(v_item->>'variant_id', '')::UUID;
        v_requested_qty := (v_item->>'quantity')::INT;

        IF v_requested_qty <= 0 THEN
            RAISE EXCEPTION 'Item quantity must be greater than zero.';
        END IF;

        -- Load & Operational Status Verification on Parent Product & Store (derive store commission_rate)
        SELECT p.seller_store_id, p.name, 'PRD-' || SUBSTRING(p.id::text FROM 1 FOR 8), p.price, p.sale_price,
               COALESCE(ss.commission_rate, 10.00)
        INTO v_store_id, v_product_name, v_product_sku, v_unit_price, v_sale_price, v_commission_rate
        FROM public.products p
        JOIN public.seller_stores ss ON ss.id = p.seller_store_id
        WHERE p.id = v_product_id
          AND p.approval_status = 'Approved'
          AND p.is_active = TRUE
          AND ss.is_approved = TRUE
          AND ss.is_suspended = FALSE;

        IF v_store_id IS NULL THEN
            RAISE EXCEPTION 'Product % is unavailable or belongs to an unapproved/suspended store.', v_product_id;
        END IF;

        -- Handle Variant Selection & Price Override if applicable
        IF v_variant_id IS NOT NULL THEN
            SELECT pv.sku, COALESCE(pv.price_override, v_sale_price, v_unit_price)
            INTO v_product_sku, v_effective_price
            FROM public.product_variants pv
            WHERE pv.id = v_variant_id
              AND pv.product_id = v_product_id
              AND pv.seller_store_id = v_store_id
              AND pv.is_active = TRUE;

            IF v_effective_price IS NULL THEN
                RAISE EXCEPTION 'Invalid or inactive variant % for product %.', v_variant_id, v_product_id;
            END IF;

            -- Atomic Stock Deduction on Variant
            UPDATE public.product_variants
            SET stock_quantity = stock_quantity - v_requested_qty,
                updated_at = NOW()
            WHERE id = v_variant_id
              AND stock_quantity >= v_requested_qty;

            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
            IF v_rows_affected = 0 THEN
                RAISE EXCEPTION 'Insufficient stock for product variant: %', v_product_name;
            END IF;
        ELSE
            -- Base Product Pricing
            v_effective_price := COALESCE(v_sale_price, v_unit_price);

            -- Atomic Stock Deduction on Product
            UPDATE public.products
            SET stock_quantity = stock_quantity - v_requested_qty,
                updated_at = NOW()
            WHERE id = v_product_id
              AND stock_quantity >= v_requested_qty;

            GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
            IF v_rows_affected = 0 THEN
                RAISE EXCEPTION 'Insufficient stock for product: %', v_product_name;
            END IF;
        END IF;

        -- Financial Calculations per Item
        v_item_total := ROUND(v_effective_price * v_requested_qty, 2);
        v_commission_amount := ROUND(v_item_total * (v_commission_rate / 100.00), 2);
        v_seller_payable := v_item_total - v_commission_amount;
        v_calculated_subtotal := v_calculated_subtotal + v_item_total;

        -- Insert Immutable Order Item Snapshot
        INSERT INTO public.order_items (
            order_id, product_id, variant_id, seller_store_id, product_name, sku,
            unit_price, sale_price, quantity, total_price, commission_rate,
            commission_amount, seller_payable
        ) VALUES (
            v_order_id, v_product_id, v_variant_id, v_store_id, v_product_name, v_product_sku,
            v_unit_price, v_sale_price, v_requested_qty, v_item_total, v_commission_rate,
            v_commission_amount, v_seller_payable
        );
    END LOOP;

    -- Standard Shipping Fee Calculation
    v_calculated_shipping := 150.00;
    v_calculated_grand_total := v_calculated_subtotal + v_calculated_shipping - v_calculated_discount;

    -- Update Parent Order with Authoritative Server Totals
    UPDATE public.buyer_orders
    SET subtotal = v_calculated_subtotal,
        shipping_fee = v_calculated_shipping,
        discount_amount = v_calculated_discount,
        grand_total = v_calculated_grand_total,
        amount = v_calculated_grand_total,
        updated_at = NOW()
    WHERE id = v_order_id;

    -- Initial Order Status History Record
    INSERT INTO public.order_status_history (
        order_id, status, notes, created_by
    ) VALUES (
        v_order_id, 'Pending', 'Order created successfully via ' || p_payment_method, v_buyer_id
    );

    -- Build Final Response
    SELECT jsonb_build_object(
        'success', TRUE,
        'idempotent_reused', FALSE,
        'order_id', v_order_id,
        'order_number', v_order_number,
        'subtotal', v_calculated_subtotal,
        'shipping_fee', v_calculated_shipping,
        'discount_amount', v_calculated_discount,
        'grand_total', v_calculated_grand_total,
        'status', 'Pending'
    ) INTO v_result;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.create_atomic_order(TEXT, JSONB, JSONB, TEXT) TO authenticated;
-- ============================================================================
-- MIGRATION: 20260810000000_phase_10_financial_ledger_payouts_refunds.sql
-- PURPOSE: Server-Authoritative Financial Ledger, COD Lifecycle, Wallet, Payouts & Refunds
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SEED PHASE 10 FINANCIAL PERMISSIONS IN RBAC
-- ----------------------------------------------------------------------------
INSERT INTO public.role_permissions (role, module, action) VALUES
    ('admin'::public.app_role, 'payouts', 'approve'),
    ('admin'::public.app_role, 'payouts', 'process'),
    ('admin'::public.app_role, 'refunds', 'process')
ON CONFLICT (role, module, action) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. CANONICAL PAYMENTS TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id TEXT NOT NULL REFERENCES public.buyer_orders(id) ON DELETE CASCADE,
    customer_user_id UUID NOT NULL REFERENCES auth.users(id),
    payment_method TEXT NOT NULL DEFAULT 'COD' CHECK (payment_method IN ('COD', 'JazzCash', 'EasyPaisa', 'Card')),
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0.00),
    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Collected', 'Settled', 'Cancelled', 'Failed')),
    idempotency_key TEXT UNIQUE NOT NULL,
    collected_at TIMESTAMPTZ,
    settled_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_payments_order_id ON public.payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_customer ON public.payments(customer_user_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON public.payments(status);

-- ----------------------------------------------------------------------------
-- 3. CANONICAL WALLET ACCOUNTS & APPEND-ONLY WALLET TRANSACTIONS LEDGER
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.wallet_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_store_id UUID UNIQUE NOT NULL REFERENCES public.seller_stores(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL REFERENCES auth.users(id),
    currency TEXT NOT NULL DEFAULT 'PKR',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.wallet_accounts ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_account_id UUID NOT NULL REFERENCES public.wallet_accounts(id) ON DELETE CASCADE,
    seller_store_id UUID NOT NULL REFERENCES public.seller_stores(id),
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('CREDIT', 'DEBIT', 'HOLD', 'RELEASE', 'ADJUSTMENT')),
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0.00),
    source_type TEXT NOT NULL CHECK (source_type IN ('ORDER_SETTLEMENT', 'PAYOUT_RESERVATION', 'PAYOUT_DISBURSEMENT', 'PAYOUT_REJECTION_RELEASE', 'REFUND_REVERSAL', 'ADMIN_ADJUSTMENT')),
    source_id TEXT NOT NULL,
    idempotency_key TEXT UNIQUE NOT NULL,
    description TEXT NOT NULL,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_wallet_txns_account ON public.wallet_transactions(wallet_account_id);
CREATE INDEX IF NOT EXISTS idx_wallet_txns_store ON public.wallet_transactions(seller_store_id);
CREATE INDEX IF NOT EXISTS idx_wallet_txns_type ON public.wallet_transactions(transaction_type);

-- Append-Only Trigger on wallet_transactions
CREATE OR REPLACE FUNCTION public.prevent_wallet_transaction_tamper()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Wallet ledger entries are append-only and immutable.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

DROP TRIGGER IF EXISTS trg_prevent_wallet_transaction_tamper ON public.wallet_transactions;
CREATE TRIGGER trg_prevent_wallet_transaction_tamper
BEFORE UPDATE OR DELETE ON public.wallet_transactions
FOR EACH ROW EXECUTE FUNCTION public.prevent_wallet_transaction_tamper();

-- ----------------------------------------------------------------------------
-- 4. CANONICAL PAYOUT REQUESTS TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payout_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_store_id UUID NOT NULL REFERENCES public.seller_stores(id),
    requested_by UUID NOT NULL REFERENCES auth.users(id),
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0.00),
    status TEXT NOT NULL DEFAULT 'Requested' CHECK (status IN ('Requested', 'Approved', 'Processing', 'Paid', 'Rejected', 'Failed')),
    idempotency_key TEXT UNIQUE NOT NULL,
    bank_name TEXT,
    iban TEXT,
    admin_notes TEXT,
    processed_by UUID REFERENCES auth.users(id),
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.payout_requests ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_payout_requests_store ON public.payout_requests(seller_store_id);
CREATE INDEX IF NOT EXISTS idx_payout_requests_status ON public.payout_requests(status);

-- ----------------------------------------------------------------------------
-- 5. CANONICAL REFUNDS TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id TEXT NOT NULL REFERENCES public.buyer_orders(id),
    order_item_id UUID REFERENCES public.order_items(id),
    seller_store_id UUID NOT NULL REFERENCES public.seller_stores(id),
    customer_user_id UUID NOT NULL REFERENCES auth.users(id),
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0.00),
    commission_reversed NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (commission_reversed >= 0.00),
    seller_payable_reversed NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (seller_payable_reversed >= 0.00),
    status TEXT NOT NULL DEFAULT 'Completed' CHECK (status IN ('Pending', 'Completed', 'Failed')),
    reason TEXT NOT NULL,
    idempotency_key TEXT UNIQUE NOT NULL,
    processed_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_refunds_order ON public.refunds(order_id);
CREATE INDEX IF NOT EXISTS idx_refunds_seller ON public.refunds(seller_store_id);

-- ----------------------------------------------------------------------------
-- 6. DIRECT CLIENT REVOKES ON FINANCIAL TABLES
-- ----------------------------------------------------------------------------
REVOKE ALL ON public.payments FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.wallet_accounts FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.wallet_transactions FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.payout_requests FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.refunds FROM PUBLIC, anon, authenticated;

-- Grant safe SELECT privileges for authenticated users
GRANT SELECT ON public.payments TO authenticated;
GRANT SELECT ON public.wallet_accounts TO authenticated;
GRANT SELECT ON public.wallet_transactions TO authenticated;
GRANT SELECT ON public.payout_requests TO authenticated;
GRANT SELECT ON public.refunds TO authenticated;

-- ----------------------------------------------------------------------------
-- 7. RLS POLICIES FOR FINANCIAL TABLES
-- ----------------------------------------------------------------------------

-- A. payments RLS Policies
DROP POLICY IF EXISTS "Buyers view own payments; Sellers view store payments; Admins view all" ON public.payments;
CREATE POLICY "Buyers view own payments; Sellers view store payments; Admins view all" ON public.payments
    FOR SELECT USING (
        customer_user_id = auth.uid()
        OR public.has_permission('finance', 'view')
        OR EXISTS (
            SELECT 1 FROM public.order_items oi
            JOIN public.seller_stores ss ON ss.id = oi.seller_store_id
            WHERE oi.order_id = public.payments.order_id
              AND ss.owner_id = auth.uid()
        )
    );

-- B. wallet_accounts RLS Policies
DROP POLICY IF EXISTS "Sellers view own wallet account; Admins view all" ON public.wallet_accounts;
CREATE POLICY "Sellers view own wallet account; Admins view all" ON public.wallet_accounts
    FOR SELECT USING (
        owner_id = auth.uid()
        OR public.has_permission('finance', 'view')
    );

-- C. wallet_transactions RLS Policies
DROP POLICY IF EXISTS "Sellers view own wallet transactions; Admins view all" ON public.wallet_transactions;
CREATE POLICY "Sellers view own wallet transactions; Admins view all" ON public.wallet_transactions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.seller_stores ss
            WHERE ss.id = public.wallet_transactions.seller_store_id
              AND ss.owner_id = auth.uid()
        )
        OR public.has_permission('finance', 'view')
    );

-- D. payout_requests RLS Policies
DROP POLICY IF EXISTS "Sellers view own payout requests; Admins view all" ON public.payout_requests;
CREATE POLICY "Sellers view own payout requests; Admins view all" ON public.payout_requests
    FOR SELECT USING (
        requested_by = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.seller_stores ss
            WHERE ss.id = public.payout_requests.seller_store_id
              AND ss.owner_id = auth.uid()
        )
        OR public.has_permission('payouts', 'view')
        OR public.has_permission('finance', 'view')
    );

-- E. refunds RLS Policies
DROP POLICY IF EXISTS "Buyers view own refunds; Sellers view store refunds; Admins view all" ON public.refunds;
CREATE POLICY "Buyers view own refunds; Sellers view store refunds; Admins view all" ON public.refunds
    FOR SELECT USING (
        customer_user_id = auth.uid()
        OR public.has_permission('refunds', 'view')
        OR public.has_permission('finance', 'view')
        OR EXISTS (
            SELECT 1 FROM public.seller_stores ss
            WHERE ss.id = public.refunds.seller_store_id
              AND ss.owner_id = auth.uid()
        )
    );

-- ----------------------------------------------------------------------------
-- 8. HELPER FUNCTION: GET SELLER WALLET SUMMARY (DERIVED LEDGER BALANCE)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_seller_wallet_summary(p_seller_store_id UUID DEFAULT NULL)
RETURNS TABLE (
    seller_store_id UUID,
    available_balance NUMERIC(12,2),
    pending_balance NUMERIC(12,2),
    held_balance NUMERIC(12,2),
    paid_out_total NUMERIC(12,2)
) AS $$
DECLARE
    v_target_store_id UUID;
    v_available NUMERIC(12,2) := 0.00;
    v_pending NUMERIC(12,2) := 0.00;
    v_held NUMERIC(12,2) := 0.00;
    v_paid_out NUMERIC(12,2) := 0.00;
BEGIN
    IF p_seller_store_id IS NOT NULL THEN
        -- Admin permission or store owner check
        IF NOT (public.has_permission('finance', 'view') OR public.has_permission('payouts', 'view')) THEN
            SELECT id INTO v_target_store_id FROM public.seller_stores WHERE id = p_seller_store_id AND owner_id = auth.uid();
            IF v_target_store_id IS NULL THEN
                RAISE EXCEPTION 'Access denied: You do not own store %.', p_seller_store_id;
            END IF;
        ELSE
            v_target_store_id := p_seller_store_id;
        END IF;
    ELSE
        SELECT id INTO v_target_store_id FROM public.seller_stores WHERE owner_id = auth.uid();
        IF v_target_store_id IS NULL THEN
            RETURN;
        END IF;
    END IF;

    -- Calculate Available Balance from Append-Only Ledger: (CREDIT + ADJUSTMENT) - (DEBIT + HOLD)
    SELECT COALESCE(SUM(
        CASE 
            WHEN wt.transaction_type IN ('CREDIT', 'RELEASE') THEN wt.amount
            WHEN wt.transaction_type IN ('DEBIT', 'HOLD') THEN -wt.amount
            WHEN wt.transaction_type = 'ADJUSTMENT' THEN wt.amount
            ELSE 0.00
        END
    ), 0.00) INTO v_available
    FROM public.wallet_transactions wt
    WHERE wt.seller_store_id = v_target_store_id;

    -- Calculate Held Balance (Active PAYOUT_RESERVATION holds)
    SELECT COALESCE(SUM(wt.amount), 0.00) INTO v_held
    FROM public.wallet_transactions wt
    WHERE wt.seller_store_id = v_target_store_id
      AND wt.transaction_type = 'HOLD';

    -- Calculate Paid Out Total (Disbursed payouts)
    SELECT COALESCE(SUM(pr.amount), 0.00) INTO v_paid_out
    FROM public.payout_requests pr
    WHERE pr.seller_store_id = v_target_store_id
      AND pr.status = 'Paid';

    -- Calculate Pending Unsettled Balance (Approved orders waiting for COD settlement)
    SELECT COALESCE(SUM(oi.seller_payable), 0.00) INTO v_pending
    FROM public.order_items oi
    JOIN public.buyer_orders bo ON bo.id = oi.order_id
    LEFT JOIN public.payments pm ON pm.order_id = bo.id
    WHERE oi.seller_store_id = v_target_store_id
      AND bo.status <> 'Cancelled'
      AND (pm.status IS NULL OR pm.status IN ('Pending', 'Collected'));

    RETURN QUERY SELECT v_target_store_id, v_available, v_pending, v_held, v_paid_out;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.get_seller_wallet_summary(UUID) TO authenticated;

-- ----------------------------------------------------------------------------
-- 9. SERVER-AUTHORITATIVE RPC: COD PAYMENT COLLECTION & SETTLEMENT
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_process_cod_settlement(
    p_order_id TEXT,
    p_action TEXT DEFAULT 'Settle'
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID;
    v_order_status TEXT;
    v_order_customer_id UUID;
    v_grand_total NUMERIC(12,2);
    v_payment_id UUID;
    v_payment_status TEXT;
    v_item RECORD;
    v_wallet_account_id UUID;
    v_idempotency_key TEXT;
    v_result JSONB;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL OR NOT (public.is_admin() OR public.has_permission('finance', 'adjust')) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for payment settlement.';
    END IF;

    -- Lock Order Row
    SELECT status, customer_user_id, grand_total INTO v_order_status, v_order_customer_id, v_grand_total
    FROM public.buyer_orders
    WHERE id = p_order_id FOR UPDATE;

    IF v_order_status IS NULL THEN
        RAISE EXCEPTION 'Order % does not exist.', p_order_id;
    END IF;

    IF v_order_status <> 'Delivered' THEN
        RAISE EXCEPTION 'Cannot settle COD order %: Order must be in Delivered status (Current: %).', p_order_id, v_order_status;
    END IF;

    -- Ensure Payment Entry Exists (Upsert Canonical Payment Row)
    v_idempotency_key := 'PAY-COD-' || p_order_id;

    INSERT INTO public.payments (
        order_id, customer_user_id, payment_method, amount, status, idempotency_key, created_at
    ) VALUES (
        p_order_id, v_order_customer_id, 'COD', v_grand_total, 'Pending', v_idempotency_key, NOW()
    ) ON CONFLICT (idempotency_key) DO UPDATE SET updated_at = NOW()
    RETURNING id, status INTO v_payment_id, v_payment_status;

    IF p_action = 'Collect' THEN
        UPDATE public.payments
        SET status = 'Collected', collected_at = NOW(), updated_at = NOW()
        WHERE id = v_payment_id;

        UPDATE public.buyer_orders
        SET payment_status = 'Paid', updated_at = NOW()
        WHERE id = p_order_id;

        v_result := jsonb_build_object('success', TRUE, 'status', 'Collected', 'order_id', p_order_id);
        RETURN v_result;

    ELSIF p_action = 'Settle' THEN
        -- Check if already settled
        IF v_payment_status = 'Settled' THEN
            SELECT jsonb_build_object('success', TRUE, 'status', 'Settled', 'already_settled', TRUE, 'order_id', p_order_id) INTO v_result;
            RETURN v_result;
        END IF;

        -- Update Payment & Order Payment Status (Logistics status is NOT fabricated by financial RPC)
        UPDATE public.payments
        SET status = 'Settled', collected_at = COALESCE(collected_at, NOW()), settled_at = NOW(), updated_at = NOW()
        WHERE id = v_payment_id;

        UPDATE public.buyer_orders
        SET payment_status = 'Paid', updated_at = NOW()
        WHERE id = p_order_id;

        -- Multi-Seller Wallet Credit: Loop through each order_item and credit respective seller store
        FOR v_item IN SELECT oi.id, oi.seller_store_id, oi.seller_payable, oi.product_name, ss.owner_id
                      FROM public.order_items oi
                      JOIN public.seller_stores ss ON ss.id = oi.seller_store_id
                      WHERE oi.order_id = p_order_id
        LOOP
            -- Ensure Wallet Account exists for Seller Store
            INSERT INTO public.wallet_accounts (seller_store_id, owner_id)
            VALUES (v_item.seller_store_id, v_item.owner_id)
            ON CONFLICT (seller_store_id) DO NOTHING;

            SELECT id INTO v_wallet_account_id FROM public.wallet_accounts WHERE seller_store_id = v_item.seller_store_id;

            -- Create Append-Only Wallet Transaction (Idempotent per item settlement)
            INSERT INTO public.wallet_transactions (
                wallet_account_id, seller_store_id, transaction_type, amount,
                source_type, source_id, idempotency_key, description, created_by
            ) VALUES (
                v_wallet_account_id, v_item.seller_store_id, 'CREDIT', v_item.seller_payable,
                'ORDER_SETTLEMENT', v_item.id::text, 'WLT-SETTLE-' || p_order_id || '-' || v_item.id::text,
                'COD Order Settlement for ' || v_item.product_name, v_admin_id
            ) ON CONFLICT (idempotency_key) DO NOTHING;

            -- Update Cached Projection on seller_stores for reporting compatibility
            UPDATE public.seller_stores
            SET pending_payout = (SELECT available_balance FROM public.get_seller_wallet_summary(v_item.seller_store_id)),
                updated_at = NOW()
            WHERE id = v_item.seller_store_id;
        END LOOP;

        -- Create Audit Log Entry
        INSERT INTO public.audit_logs (actor_user_id, actor_role, action, target_type, target_id, metadata)
        VALUES (v_admin_id, 'super_admin'::public.app_role, 'COD_ORDER_SETTLED', 'ORDER', p_order_id, jsonb_build_object('order_id', p_order_id, 'amount', v_grand_total));

        v_result := jsonb_build_object('success', TRUE, 'status', 'Settled', 'already_settled', FALSE, 'order_id', p_order_id);
        RETURN v_result;

    ELSE
        RAISE EXCEPTION 'Invalid settlement action: %', p_action;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.admin_process_cod_settlement(TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 10. SERVER-AUTHORITATIVE RPC: SELLER PAYOUT REQUEST (ATOMIC WITH ROW LOCKING)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.seller_request_payout(
    p_amount NUMERIC(12,2),
    p_idempotency_key TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_seller_id UUID;
    v_store_id UUID;
    v_payout_locked BOOLEAN;
    v_wallet_account_id UUID;
    v_available_balance NUMERIC(12,2);
    v_payout_id UUID;
    v_result JSONB;
BEGIN
    v_seller_id := auth.uid();
    IF v_seller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF p_amount IS NULL OR p_amount <= 0.00 THEN
        RAISE EXCEPTION 'Payout amount must be greater than zero.';
    END IF;

    IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
        RAISE EXCEPTION 'Idempotency key is required for payout request.';
    END IF;

    -- Row Lock Seller Store for Concurrency Protection (Prevents parallel overdraw)
    SELECT id, payout_locked INTO v_store_id, v_payout_locked
    FROM public.seller_stores
    WHERE owner_id = v_seller_id FOR UPDATE;

    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'Seller store not found for authenticated user.';
    END IF;

    IF v_payout_locked IS TRUE THEN
        RAISE EXCEPTION 'Payouts are currently locked for your seller account.';
    END IF;

    -- Ensure Wallet Account exists
    INSERT INTO public.wallet_accounts (seller_store_id, owner_id)
    VALUES (v_store_id, v_seller_id)
    ON CONFLICT (seller_store_id) DO NOTHING;

    SELECT id INTO v_wallet_account_id FROM public.wallet_accounts WHERE seller_store_id = v_store_id;

    -- Derive Available Balance from Ledger
    SELECT available_balance INTO v_available_balance
    FROM public.get_seller_wallet_summary(v_store_id);

    IF p_amount > v_available_balance THEN
        RAISE EXCEPTION 'Insufficient available balance. Requested: %, Available: %', p_amount, v_available_balance;
    END IF;

    -- Create Payout Request Row
    INSERT INTO public.payout_requests (
        seller_store_id, requested_by, amount, status, idempotency_key, bank_name, iban
    ) VALUES (
        v_store_id, v_seller_id, p_amount, 'Requested', p_idempotency_key, 'Meezan Bank Ltd', 'PK36 MEZN 0001 0203 0405 0607'
    ) RETURNING id INTO v_payout_id;

    -- Create HOLD Transaction Entry in Wallet Ledger
    INSERT INTO public.wallet_transactions (
        wallet_account_id, seller_store_id, transaction_type, amount,
        source_type, source_id, idempotency_key, description, created_by
    ) VALUES (
        v_wallet_account_id, v_store_id, 'HOLD', p_amount,
        'PAYOUT_RESERVATION', v_payout_id::text, 'WLT-HOLD-' || v_payout_id::text,
        'Payout Reservation Hold for request ' || v_payout_id::text, v_seller_id
    );

    -- Update Cached Projection
    UPDATE public.seller_stores
    SET pending_payout = (SELECT available_balance FROM public.get_seller_wallet_summary(v_store_id)),
        updated_at = NOW()
    WHERE id = v_store_id;

    v_result := jsonb_build_object(
        'success', TRUE,
        'payout_id', v_payout_id,
        'amount', p_amount,
        'status', 'Requested'
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.seller_request_payout(NUMERIC(12,2), TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 11. SERVER-AUTHORITATIVE RPC: ADMIN PAYOUT PROCESSING & DISBURSEMENT
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_process_payout(
    p_payout_id UUID,
    p_action TEXT,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID;
    v_store_id UUID;
    v_requested_by UUID;
    v_amount NUMERIC(12,2);
    v_current_status TEXT;
    v_wallet_account_id UUID;
    v_result JSONB;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL OR NOT (public.is_admin() OR public.has_permission('payouts', 'hold') OR public.has_permission('payouts', 'approve')) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for payout processing.';
    END IF;

    -- Lock Payout Request Row
    SELECT seller_store_id, requested_by, amount, status INTO v_store_id, v_requested_by, v_amount, v_current_status
    FROM public.payout_requests
    WHERE id = p_payout_id FOR UPDATE;

    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'Payout request % not found.', p_payout_id;
    END IF;

    -- Prevent self-approval if admin is also store owner
    IF v_requested_by = v_admin_id THEN
        RAISE EXCEPTION 'Access denied: Admin cannot approve or process own payout request.';
    END IF;

    SELECT id INTO v_wallet_account_id FROM public.wallet_accounts WHERE seller_store_id = v_store_id;

    IF p_action = 'Approve' THEN
        IF v_current_status <> 'Requested' THEN
            RAISE EXCEPTION 'Cannot approve payout in status %.', v_current_status;
        END IF;

        UPDATE public.payout_requests
        SET status = 'Approved', admin_notes = p_notes, processed_by = v_admin_id, updated_at = NOW()
        WHERE id = p_payout_id;

        INSERT INTO public.audit_logs (actor_user_id, actor_role, action, target_type, target_id, metadata)
        VALUES (v_admin_id, 'super_admin'::public.app_role, 'APPROVE_PAYOUT', 'PAYOUT', p_payout_id::text, jsonb_build_object('amount', v_amount));

        v_result := jsonb_build_object('success', TRUE, 'status', 'Approved', 'payout_id', p_payout_id);
        RETURN v_result;

    ELSIF p_action IN ('Process', 'Pay') THEN
        IF v_current_status IN ('Paid', 'Failed') THEN
            SELECT jsonb_build_object('success', TRUE, 'status', v_current_status, 'already_processed', TRUE, 'payout_id', p_payout_id) INTO v_result;
            RETURN v_result;
        END IF;

        -- Release HOLD and Insert DEBIT Transaction (Idempotent execution)
        INSERT INTO public.wallet_transactions (
            wallet_account_id, seller_store_id, transaction_type, amount,
            source_type, source_id, idempotency_key, description, created_by
        ) VALUES (
            v_wallet_account_id, v_store_id, 'RELEASE', v_amount,
            'PAYOUT_DISBURSEMENT', p_payout_id::text, 'WLT-REL-' || p_payout_id::text,
            'Release Hold for Payout Disbursement ' || p_payout_id::text, v_admin_id
        ) ON CONFLICT (idempotency_key) DO NOTHING;

        INSERT INTO public.wallet_transactions (
            wallet_account_id, seller_store_id, transaction_type, amount,
            source_type, source_id, idempotency_key, description, created_by
        ) VALUES (
            v_wallet_account_id, v_store_id, 'DEBIT', v_amount,
            'PAYOUT_DISBURSEMENT', p_payout_id::text, 'WLT-DEB-' || p_payout_id::text,
            'Manual Bank Payout Disbursement for Request ' || p_payout_id::text, v_admin_id
        ) ON CONFLICT (idempotency_key) DO NOTHING;

        UPDATE public.payout_requests
        SET status = 'Paid', admin_notes = p_notes, processed_by = v_admin_id, processed_at = NOW(), updated_at = NOW()
        WHERE id = p_payout_id;

        UPDATE public.seller_stores
        SET last_payout = v_amount,
            pending_payout = GREATEST((SELECT available_balance FROM public.get_seller_wallet_summary(v_store_id)), 0.00),
            updated_at = NOW()
        WHERE id = v_store_id;

        INSERT INTO public.audit_logs (actor_user_id, actor_role, action, target_type, target_id, metadata)
        VALUES (v_admin_id, 'super_admin'::public.app_role, 'PAYOUT_DISBURSED', 'PAYOUT', p_payout_id::text, jsonb_build_object('amount', v_amount));

        v_result := jsonb_build_object('success', TRUE, 'status', 'Paid', 'already_processed', FALSE, 'payout_id', p_payout_id);
        RETURN v_result;

    ELSIF p_action = 'Reject' THEN
        IF v_current_status = 'Paid' THEN
            RAISE EXCEPTION 'Cannot reject an already paid payout.';
        END IF;

        -- Release HOLD Entry back to Seller Available Balance
        INSERT INTO public.wallet_transactions (
            wallet_account_id, seller_store_id, transaction_type, amount,
            source_type, source_id, idempotency_key, description, created_by
        ) VALUES (
            v_wallet_account_id, v_store_id, 'RELEASE', v_amount,
            'PAYOUT_REJECTION_RELEASE', p_payout_id::text, 'WLT-REJ-REL-' || p_payout_id::text,
            'Release Hold for Rejected Payout ' || p_payout_id::text, v_admin_id
        ) ON CONFLICT (idempotency_key) DO NOTHING;

        UPDATE public.payout_requests
        SET status = 'Rejected', admin_notes = p_notes, processed_by = v_admin_id, processed_at = NOW(), updated_at = NOW()
        WHERE id = p_payout_id;

        UPDATE public.seller_stores
        SET pending_payout = GREATEST((SELECT available_balance FROM public.get_seller_wallet_summary(v_store_id)), 0.00),
            updated_at = NOW()
        WHERE id = v_store_id;

        INSERT INTO public.audit_logs (actor_user_id, actor_role, action, target_type, target_id, metadata)
        VALUES (v_admin_id, 'super_admin'::public.app_role, 'PAYOUT_REJECTED', 'PAYOUT', p_payout_id::text, jsonb_build_object('amount', v_amount, 'reason', p_notes));

        v_result := jsonb_build_object('success', TRUE, 'status', 'Rejected', 'payout_id', p_payout_id);
        RETURN v_result;
    ELSE
        RAISE EXCEPTION 'Invalid payout action: %', p_action;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.admin_process_payout(UUID, TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 12. SERVER-AUTHORITATIVE RPC: ADMIN REFUND & FINANCIAL REVERSAL
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_process_refund(
    p_order_id TEXT,
    p_order_item_id UUID,
    p_amount NUMERIC(12,2),
    p_reason TEXT,
    p_idempotency_key TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID;
    v_customer_user_id UUID;
    v_seller_store_id UUID;
    v_item_total NUMERIC(12,2);
    v_item_commission_rate NUMERIC(5,2);
    v_existing_refunded NUMERIC(12,2) := 0.00;
    v_comm_reversed NUMERIC(12,2);
    v_seller_payable_reversed NUMERIC(12,2);
    v_wallet_account_id UUID;
    v_refund_id UUID;
    v_existing_refund_id UUID;
    v_existing_order_id TEXT;
    v_existing_item_id UUID;
    v_existing_amount NUMERIC(12,2);
    v_existing_status TEXT;
    v_result JSONB;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL OR NOT (public.is_admin() OR public.has_permission('refunds', 'process') OR public.has_permission('finance', 'adjust')) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for refund processing.';
    END IF;

    IF p_amount IS NULL OR p_amount <= 0.00 THEN
        RAISE EXCEPTION 'Refund amount must be greater than zero.';
    END IF;

    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'Refund reason is required.';
    END IF;

    IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
        RAISE EXCEPTION 'Idempotency key is required for refund.';
    END IF;

    -- Durable Idempotency Check
    SELECT id, order_id, order_item_id, amount, status INTO v_existing_refund_id, v_existing_order_id, v_existing_item_id, v_existing_amount, v_existing_status
    FROM public.refunds
    WHERE idempotency_key = p_idempotency_key;

    IF v_existing_refund_id IS NOT NULL THEN
        IF v_existing_order_id <> p_order_id OR v_existing_item_id <> p_order_item_id OR v_existing_amount <> p_amount THEN
            RAISE EXCEPTION 'Idempotency conflict: Existing refund % has different request parameters.', p_idempotency_key;
        END IF;

        v_result := jsonb_build_object(
            'success', TRUE,
            'already_processed', TRUE,
            'refund_id', v_existing_refund_id,
            'amount', v_existing_amount,
            'status', v_existing_status
        );
        RETURN v_result;
    END IF;

    -- Fetch Order & Item Financial Details
    SELECT bo.customer_user_id, oi.seller_store_id, oi.total_price, oi.commission_rate
    INTO v_customer_user_id, v_seller_store_id, v_item_total, v_item_commission_rate
    FROM public.order_items oi
    JOIN public.buyer_orders bo ON bo.id = oi.order_id
    WHERE oi.id = p_order_item_id
      AND oi.order_id = p_order_id;

    IF v_seller_store_id IS NULL THEN
        RAISE EXCEPTION 'Target order line item % not found for order %.', p_order_item_id, p_order_id;
    END IF;

    -- Cumulative Refund Check on Item
    SELECT COALESCE(SUM(amount), 0.00) INTO v_existing_refunded
    FROM public.refunds
    WHERE order_item_id = p_order_item_id
      AND status = 'Completed';

    IF (v_existing_refunded + p_amount) > v_item_total THEN
        RAISE EXCEPTION 'Refund amount exceeds eligible paid item amount. Eligible: %, Requested: %', (v_item_total - v_existing_refunded), p_amount;
    END IF;

    -- Proportional Commission & Seller Payable Reversal Calculation
    v_comm_reversed := ROUND(p_amount * (v_item_commission_rate / 100.00), 2);
    v_seller_payable_reversed := p_amount - v_comm_reversed;

    -- Insert Refund Record (Idempotent)
    INSERT INTO public.refunds (
        order_id, order_item_id, seller_store_id, customer_user_id, amount,
        commission_reversed, seller_payable_reversed, status, reason, idempotency_key, processed_by
    ) VALUES (
        p_order_id, p_order_item_id, v_seller_store_id, v_customer_user_id, p_amount,
        v_comm_reversed, v_seller_payable_reversed, 'Completed', p_reason, p_idempotency_key, v_admin_id
    ) RETURNING id INTO v_refund_id;

    -- Insert Seller Wallet Reversal Debit Entry
    SELECT id INTO v_wallet_account_id FROM public.wallet_accounts WHERE seller_store_id = v_seller_store_id;

    IF v_wallet_account_id IS NOT NULL THEN
        INSERT INTO public.wallet_transactions (
            wallet_account_id, seller_store_id, transaction_type, amount,
            source_type, source_id, idempotency_key, description, created_by
        ) VALUES (
            v_wallet_account_id, v_seller_store_id, 'DEBIT', v_seller_payable_reversed,
            'REFUND_REVERSAL', v_refund_id::text, 'WLT-REF-' || v_refund_id::text,
            'Refund Reversal for Order ' || p_order_id || ' (' || p_reason || ')', v_admin_id
        ) ON CONFLICT (idempotency_key) DO NOTHING;

        UPDATE public.seller_stores
        SET pending_payout = GREATEST((SELECT available_balance FROM public.get_seller_wallet_summary(v_seller_store_id)), 0.00),
            updated_at = NOW()
        WHERE id = v_seller_store_id;
    END IF;

    -- Audit Log
    INSERT INTO public.audit_logs (actor_user_id, actor_role, action, target_type, target_id, metadata)
    VALUES (v_admin_id, 'super_admin'::public.app_role, 'PROCESS_REFUND', 'ORDER', p_order_id, jsonb_build_object(
        'refund_id', v_refund_id, 'amount', p_amount, 'seller_payable_reversed', v_seller_payable_reversed, 'reason', p_reason
    ));

    v_result := jsonb_build_object(
        'success', TRUE,
        'already_processed', FALSE,
        'refund_id', v_refund_id,
        'amount', p_amount,
        'seller_payable_reversed', v_seller_payable_reversed,
        'status', 'Completed'
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.admin_process_refund(TEXT, UUID, NUMERIC(12,2), TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 13. HARDENED RPC: ADMIN WALLET ADJUSTMENT (APPEND-ONLY LEDGER AUTHORITATIVE)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.admin_adjust_seller_wallet(UUID, NUMERIC, TEXT);

CREATE OR REPLACE FUNCTION public.admin_adjust_seller_wallet(
    p_store_id UUID,
    p_amount NUMERIC(12,2),
    p_reason TEXT,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_admin_id UUID;
    v_store_owner_id UUID;
    v_wallet_account_id UUID;
    v_effective_idempotency_key TEXT;
    v_txn_type TEXT;
    v_abs_amount NUMERIC(12,2);
    v_new_available NUMERIC(12,2);
    v_result JSONB;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL OR NOT (public.is_admin() OR public.has_permission('finance', 'adjust')) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for wallet adjustment.';
    END IF;

    IF p_amount IS NULL OR p_amount = 0.00 THEN
        RAISE EXCEPTION 'Adjustment amount cannot be zero or null.';
    END IF;

    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'Adjustment reason is required for financial audit.';
    END IF;

    SELECT owner_id INTO v_store_owner_id FROM public.seller_stores WHERE id = p_store_id;
    IF v_store_owner_id IS NULL THEN
        RAISE EXCEPTION 'Seller store % does not exist.', p_store_id;
    END IF;

    -- Ensure Wallet Account exists
    INSERT INTO public.wallet_accounts (seller_store_id, owner_id)
    VALUES (p_store_id, v_store_owner_id)
    ON CONFLICT (seller_store_id) DO NOTHING;

    SELECT id INTO v_wallet_account_id FROM public.wallet_accounts WHERE seller_store_id = p_store_id;

    v_effective_idempotency_key := COALESCE(p_idempotency_key, 'WLT-ADJ-' || gen_random_uuid()::text);
    v_abs_amount := ABS(p_amount);
    v_txn_type := 'ADJUSTMENT';

    -- Insert Append-Only Ledger Entry
    INSERT INTO public.wallet_transactions (
        wallet_account_id, seller_store_id, transaction_type, amount,
        source_type, source_id, idempotency_key, description, created_by
    ) VALUES (
        v_wallet_account_id, p_store_id, v_txn_type, p_amount,
        'ADMIN_ADJUSTMENT', v_admin_id::text, v_effective_idempotency_key,
        'Admin Wallet Adjustment: ' || p_reason, v_admin_id
    ) ON CONFLICT (idempotency_key) DO NOTHING;

    -- Re-derive Available Balance
    SELECT available_balance INTO v_new_available
    FROM public.get_seller_wallet_summary(p_store_id);

    UPDATE public.seller_stores
    SET pending_payout = GREATEST(v_new_available, 0.00), updated_at = NOW()
    WHERE id = p_store_id;

    -- Audit Log
    INSERT INTO public.audit_logs (actor_user_id, actor_role, action, target_type, target_id, metadata)
    VALUES (v_admin_id, 'super_admin'::public.app_role, 'ADJUST_SELLER_WALLET', 'SELLER_STORE', p_store_id::text, jsonb_build_object(
        'amount', p_amount, 'new_balance', v_new_available, 'reason', p_reason
    ));

    v_result := jsonb_build_object(
        'success', TRUE,
        'store_id', p_store_id,
        'amount_adjusted', p_amount,
        'new_available_balance', v_new_available
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.admin_adjust_seller_wallet(UUID, NUMERIC(12,2), TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 14. FINANCIAL RECONCILIATION REPORTING RPC
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reconcile_financial_ledger()
RETURNS TABLE (
    check_name TEXT,
    discrepancy_count INT,
    status TEXT,
    details JSONB
) AS $$
BEGIN
    IF NOT (public.is_admin() OR public.has_permission('finance', 'view')) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for ledger reconciliation.';
    END IF;

    -- Check 1: Order Grand Total vs Payment Amount Mismatch
    RETURN QUERY
    SELECT 
        'Order Grand Total vs Payment Amount'::TEXT,
        COUNT(*)::INT,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'DISCREPANCY_DETECTED' END,
        jsonb_agg(jsonb_build_object('order_id', bo.id, 'order_total', bo.grand_total, 'payment_amount', pm.amount))
    FROM public.buyer_orders bo
    JOIN public.payments pm ON pm.order_id = bo.id
    WHERE bo.grand_total <> pm.amount;

    -- Check 2: Unsettled Seller Payable vs Wallet Credits Mismatch
    RETURN QUERY
    SELECT 
        'Settled Orders vs Wallet Credits Mismatch'::TEXT,
        COUNT(*)::INT,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'DISCREPANCY_DETECTED' END,
        jsonb_agg(jsonb_build_object('order_id', bo.id, 'payment_status', pm.status))
    FROM public.buyer_orders bo
    JOIN public.payments pm ON pm.order_id = bo.id
    WHERE pm.status = 'Settled'
      AND NOT EXISTS (
          SELECT 1 FROM public.wallet_transactions wt
          WHERE wt.source_type = 'ORDER_SETTLEMENT'
            AND wt.source_id IN (SELECT oi.id::text FROM public.order_items oi WHERE oi.order_id = bo.id)
      );

    -- Check 3: Overdrawn Payout Requests vs Available Balance
    RETURN QUERY
    SELECT 
        'Overdrawn Payout Requests vs Available Balance'::TEXT,
        COUNT(*)::INT,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'DISCREPANCY_DETECTED' END,
        jsonb_agg(jsonb_build_object('payout_id', pr.id, 'requested_amount', pr.amount))
    FROM public.payout_requests pr
    JOIN public.seller_stores ss ON ss.id = pr.seller_store_id
    WHERE pr.status = 'Requested'
      AND pr.amount > (SELECT available_balance FROM public.get_seller_wallet_summary(pr.seller_store_id));

    -- Check 4: Cached pending_payout Projection Mismatch vs Derived Available Balance
    RETURN QUERY
    SELECT 
        'Seller Stores Pending Payout Projection Mismatch'::TEXT,
        COUNT(*)::INT,
        CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'DISCREPANCY_DETECTED' END,
        jsonb_agg(jsonb_build_object('seller_store_id', ss.id, 'cached_pending_payout', ss.pending_payout, 'derived_available_balance', summary.available_balance))
    FROM public.seller_stores ss
    CROSS JOIN LATERAL public.get_seller_wallet_summary(ss.id) summary
    WHERE ss.pending_payout <> GREATEST(summary.available_balance, 0.00);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.reconcile_financial_ledger() TO authenticated;
-- ============================================================================
-- APNA STORE â€” PHASE 11: ORDERS, RETURNS, REVIEWS, CHAT, NOTIFICATIONS & TRACKING
-- Migration: 20260811000000_phase_11_orders_returns_reviews_chat_notifications.sql
-- Purpose: Canonical Multi-Seller Fulfillments, Returns, Reviews, Persisted Chat,
--          Server-Created Notifications & Manual Courier Tracking Events
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SEED PHASE 11 RBAC PERMISSIONS
-- ----------------------------------------------------------------------------
INSERT INTO public.role_permissions (role, module, action) VALUES
    ('admin'::public.app_role, 'orders', 'manage'),
    ('admin'::public.app_role, 'returns', 'review'),
    ('admin'::public.app_role, 'reviews', 'moderate'),
    ('admin'::public.app_role, 'chat', 'monitor')
ON CONFLICT (role, module, action) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. EXTEND order_status_history WITH seller_store_id & TRANSITION DETAILS
-- ----------------------------------------------------------------------------
ALTER TABLE public.order_status_history
    ADD COLUMN IF NOT EXISTS seller_store_id UUID REFERENCES public.seller_stores(id),
    ADD COLUMN IF NOT EXISTS old_status TEXT,
    ADD COLUMN IF NOT EXISTS actor_user_id UUID REFERENCES auth.users(id),
    ADD COLUMN IF NOT EXISTS actor_role TEXT;

-- ----------------------------------------------------------------------------
-- 3. CANONICAL store_fulfillments TABLE (MULTI-SELLER FULFILLMENT AUTHORITY)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.store_fulfillments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id TEXT NOT NULL REFERENCES public.buyer_orders(id) ON DELETE CASCADE,
    seller_store_id UUID NOT NULL REFERENCES public.seller_stores(id),
    fulfillment_status TEXT NOT NULL DEFAULT 'Pending' CHECK (fulfillment_status IN ('Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled')),
    courier_name TEXT,
    tracking_number TEXT,
    shipped_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT store_fulfillments_order_store_key UNIQUE (order_id, seller_store_id)
);

ALTER TABLE public.store_fulfillments ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_store_fulfillments_order ON public.store_fulfillments(order_id);
CREATE INDEX IF NOT EXISTS idx_store_fulfillments_store ON public.store_fulfillments(seller_store_id);

REVOKE ALL ON public.store_fulfillments FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.store_fulfillments TO authenticated;

-- RLS: Buyer views fulfillments for own orders; Seller views own store fulfillments; Admin with orders:manage views all
CREATE POLICY "Fulfillment visibility policy" ON public.store_fulfillments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.buyer_orders bo
            WHERE bo.id = public.store_fulfillments.order_id
              AND bo.customer_user_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM public.seller_stores ss
            WHERE ss.id = public.store_fulfillments.seller_store_id
              AND ss.owner_id = auth.uid()
        )
        OR public.has_permission('orders', 'manage')
    );

-- Trigger: Automatically seed store_fulfillments on order_items insert
CREATE OR REPLACE FUNCTION public.trg_auto_create_store_fulfillments()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.store_fulfillments (order_id, seller_store_id, fulfillment_status)
    VALUES (NEW.order_id, NEW.seller_store_id, 'Pending')
    ON CONFLICT (order_id, seller_store_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

DROP TRIGGER IF EXISTS trg_auto_create_store_fulfillments ON public.order_items;
CREATE TRIGGER trg_auto_create_store_fulfillments
    AFTER INSERT ON public.order_items
    FOR EACH ROW EXECUTE FUNCTION public.trg_auto_create_store_fulfillments();

-- ----------------------------------------------------------------------------
-- 4. CANONICAL order_tracking_events TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.order_tracking_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id TEXT NOT NULL REFERENCES public.buyer_orders(id) ON DELETE CASCADE,
    seller_store_id UUID REFERENCES public.seller_stores(id),
    event_type TEXT NOT NULL,
    description TEXT NOT NULL,
    location TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.order_tracking_events ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_tracking_events_order ON public.order_tracking_events(order_id);

REVOKE ALL ON public.order_tracking_events FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.order_tracking_events TO authenticated;

CREATE POLICY "Tracking visibility policy" ON public.order_tracking_events
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.buyer_orders bo
            WHERE bo.id = public.order_tracking_events.order_id
              AND bo.customer_user_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM public.seller_stores ss
            WHERE ss.id = public.order_tracking_events.seller_store_id
              AND ss.owner_id = auth.uid()
        )
        OR public.has_permission('orders', 'manage')
    );

-- ----------------------------------------------------------------------------
-- 5. CANONICAL return_requests TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.return_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id TEXT NOT NULL REFERENCES public.buyer_orders(id),
    order_item_id UUID NOT NULL REFERENCES public.order_items(id),
    seller_store_id UUID NOT NULL REFERENCES public.seller_stores(id),
    customer_user_id UUID NOT NULL REFERENCES auth.users(id),
    quantity INT NOT NULL CHECK (quantity > 0),
    reason TEXT NOT NULL CHECK (length(trim(reason)) > 0),
    description TEXT,
    evidence_paths TEXT[] DEFAULT '{}'::TEXT[],
    status TEXT NOT NULL DEFAULT 'Requested' CHECK (status IN ('Requested', 'Approved', 'Rejected', 'Completed')),
    admin_notes TEXT,
    processed_by UUID REFERENCES auth.users(id),
    refund_id UUID REFERENCES public.refunds(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.return_requests ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_return_requests_order ON public.return_requests(order_id);
CREATE INDEX IF NOT EXISTS idx_return_requests_seller ON public.return_requests(seller_store_id);
CREATE INDEX IF NOT EXISTS idx_return_requests_customer ON public.return_requests(customer_user_id);

REVOKE ALL ON public.return_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.return_requests TO anon, authenticated;

CREATE POLICY "Return requests select policy" ON public.return_requests
    FOR SELECT USING (
        customer_user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.seller_stores ss
            WHERE ss.id = public.return_requests.seller_store_id
              AND ss.owner_id = auth.uid()
        )
        OR public.has_permission('returns', 'review')
        OR public.has_permission('finance', 'view')
    );

-- ----------------------------------------------------------------------------
-- 6. CANONICAL product_reviews TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.product_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    order_item_id UUID UNIQUE NOT NULL REFERENCES public.order_items(id),
    buyer_user_id UUID NOT NULL REFERENCES auth.users(id),
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT NOT NULL CHECK (length(trim(comment)) > 0 AND length(comment) <= 1000),
    is_verified_purchase BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.product_reviews ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_product_reviews_product ON public.product_reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_product_reviews_buyer ON public.product_reviews(buyer_user_id);

REVOKE ALL ON public.product_reviews FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.product_reviews TO anon, authenticated;

CREATE POLICY "Public read reviews" ON public.product_reviews
    FOR SELECT USING (TRUE);

-- ----------------------------------------------------------------------------
-- 7. CANONICAL chat_rooms AND chat_messages TABLES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chat_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_user_id UUID NOT NULL REFERENCES auth.users(id),
    seller_store_id UUID NOT NULL REFERENCES public.seller_stores(id),
    product_id UUID REFERENCES public.products(id),
    order_id TEXT REFERENCES public.buyer_orders(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chat_rooms_buyer_seller_product_key UNIQUE (buyer_user_id, seller_store_id, product_id)
);

ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_chat_rooms_buyer ON public.chat_rooms(buyer_user_id);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_seller ON public.chat_rooms(seller_store_id);

REVOKE ALL ON public.chat_rooms FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.chat_rooms TO authenticated;

CREATE POLICY "Chat room participant select" ON public.chat_rooms
    FOR SELECT USING (
        buyer_user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.seller_stores ss
            WHERE ss.id = public.chat_rooms.seller_store_id
              AND ss.owner_id = auth.uid()
        )
        OR public.has_permission('chat', 'monitor')
    );

CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id),
    message_text TEXT NOT NULL CHECK (length(trim(message_text)) > 0 AND length(message_text) <= 2000),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_chat_messages_room ON public.chat_messages(room_id);

REVOKE ALL ON public.chat_messages FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.chat_messages TO authenticated;

CREATE POLICY "Chat message participant select" ON public.chat_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.chat_rooms cr
            WHERE cr.id = public.chat_messages.room_id
              AND (
                  cr.buyer_user_id = auth.uid()
                  OR EXISTS (
                      SELECT 1 FROM public.seller_stores ss
                      WHERE ss.id = cr.seller_store_id AND ss.owner_id = auth.uid()
                  )
                  OR public.has_permission('chat', 'monitor')
              )
        )
    );

-- ----------------------------------------------------------------------------
-- 8. CANONICAL notifications TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    entity_type TEXT,
    entity_id TEXT,
    event_key TEXT UNIQUE,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON public.notifications(user_id, is_read);

REVOKE ALL ON public.notifications FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.notifications TO authenticated;

CREATE POLICY "User views own notifications" ON public.notifications
    FOR SELECT USING (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 9. PRIVATE STORAGE BUCKET FOR RETURN EVIDENCE
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'return-evidence',
    'return-evidence',
    FALSE,
    10485760, -- 10MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
) ON CONFLICT (id) DO UPDATE SET
    public = FALSE,
    file_size_limit = 10485760;

DROP POLICY IF EXISTS "Return evidence upload policy" ON storage.objects;
CREATE POLICY "Return evidence upload policy" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'return-evidence'
        AND auth.role() = 'authenticated'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Return evidence select policy" ON storage.objects;
CREATE POLICY "Return evidence select policy" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'return-evidence'
        AND auth.role() = 'authenticated'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR public.has_permission('returns', 'review')
            OR public.has_permission('finance', 'view')
            OR EXISTS (
                SELECT 1 FROM public.return_requests rr
                JOIN public.seller_stores ss ON ss.id = rr.seller_store_id
                WHERE ss.owner_id = auth.uid()
                  AND name = ANY(rr.evidence_paths)
            )
        )
    );

-- ----------------------------------------------------------------------------
-- 10. SERVER-AUTHORITATIVE RPC: INTERNAL NOTIFICATION HELPER
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.internal_create_notification(
    p_user_id UUID,
    p_type TEXT,
    p_title TEXT,
    p_body TEXT,
    p_entity_type TEXT DEFAULT NULL,
    p_entity_id TEXT DEFAULT NULL,
    p_event_key TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO public.notifications (
        user_id, type, title, body, entity_type, entity_id, event_key
    ) VALUES (
        p_user_id, p_type, p_title, p_body, p_entity_type, p_entity_id, p_event_key
    ) ON CONFLICT (event_key) DO NOTHING
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

REVOKE EXECUTE ON FUNCTION public.internal_create_notification FROM PUBLIC, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 11. SERVER-AUTHORITATIVE RPC: MARK NOTIFICATION AS READ
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    UPDATE public.notifications
    SET is_read = TRUE, read_at = NOW()
    WHERE id = p_notification_id
      AND user_id = v_user_id;

    RETURN jsonb_build_object('success', TRUE, 'notification_id', p_notification_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.mark_notification_read(UUID) TO authenticated;

-- ----------------------------------------------------------------------------
-- 12. SERVER-AUTHORITATIVE RPC: SELLER UPDATE STORE FULFILLMENT STATUS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.seller_update_fulfillment_status(
    p_order_id TEXT,
    p_new_status TEXT,
    p_seller_store_id UUID DEFAULT NULL,
    p_courier_name TEXT DEFAULT NULL,
    p_tracking_number TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_seller_user_id UUID;
    v_store_id UUID;
    v_old_status TEXT;
    v_order_customer_id UUID;
    v_shipped_count INT;
    v_delivered_count INT;
    v_total_fulfillments INT;
    v_derived_parent_status TEXT;
    v_result JSONB;
BEGIN
    v_seller_user_id := auth.uid();
    IF v_seller_user_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF p_new_status NOT IN ('Processing', 'Shipped', 'Delivered') THEN
        RAISE EXCEPTION 'Invalid fulfillment target status: %', p_new_status;
    END IF;

    IF p_seller_store_id IS NOT NULL THEN
        IF NOT (
            EXISTS (SELECT 1 FROM public.seller_stores WHERE id = p_seller_store_id AND owner_id = v_seller_user_id)
            OR public.has_permission('orders', 'manage')
        ) THEN
            RAISE EXCEPTION 'Access denied: You do not own store %.', p_seller_store_id;
        END IF;
        v_store_id := p_seller_store_id;
    ELSE
        SELECT ss.id INTO v_store_id
        FROM public.seller_stores ss
        WHERE ss.owner_id = v_seller_user_id;
    END IF;

    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'Seller store not found for authenticated user.';
    END IF;

    -- Lock & Fetch Store Fulfillment Row
    SELECT fulfillment_status INTO v_old_status
    FROM public.store_fulfillments
    WHERE order_id = p_order_id
      AND seller_store_id = v_store_id
    FOR UPDATE;

    IF v_old_status IS NULL THEN
        RAISE EXCEPTION 'Fulfillment record not found for order % and store %.', p_order_id, v_store_id;
    END IF;

    IF v_old_status = 'Cancelled' THEN
        RAISE EXCEPTION 'Cannot update status of cancelled store fulfillment.';
    END IF;

    -- Strict Transition Logic
    IF p_new_status = 'Processing' AND v_old_status <> 'Pending' THEN
        RAISE EXCEPTION 'Invalid transition: Store fulfillment can only move to Processing from Pending (Current: %).', v_old_status;
    ELSIF p_new_status = 'Shipped' AND v_old_status NOT IN ('Pending', 'Processing') THEN
        RAISE EXCEPTION 'Invalid transition: Store fulfillment can only move to Shipped from Pending or Processing (Current: %).', v_old_status;
    ELSIF p_new_status = 'Delivered' THEN
        -- Delivery confirmation requires Shipped status or Admin permission
        IF v_old_status <> 'Shipped' AND NOT public.has_permission('orders', 'manage') THEN
            RAISE EXCEPTION 'Invalid transition: Store fulfillment can only move to Delivered from Shipped status (Current: %).', v_old_status;
        END IF;
    END IF;

    -- Update Store Fulfillment Record
    UPDATE public.store_fulfillments
    SET fulfillment_status = p_new_status,
        courier_name = COALESCE(p_courier_name, courier_name),
        tracking_number = COALESCE(p_tracking_number, tracking_number),
        shipped_at = CASE WHEN p_new_status = 'Shipped' THEN COALESCE(shipped_at, NOW()) ELSE shipped_at END,
        delivered_at = CASE WHEN p_new_status = 'Delivered' THEN COALESCE(delivered_at, NOW()) ELSE delivered_at END,
        notes = COALESCE(p_notes, notes),
        updated_at = NOW()
    WHERE order_id = p_order_id
      AND seller_store_id = v_store_id;

    -- Fetch Customer User ID for Order
    SELECT customer_user_id INTO v_order_customer_id
    FROM public.buyer_orders
    WHERE id = p_order_id;

    -- Record Immutable Order Status History
    INSERT INTO public.order_status_history (
        order_id, seller_store_id, status, old_status, notes, created_by, actor_user_id, actor_role
    ) VALUES (
        p_order_id, v_store_id, p_new_status, v_old_status, p_notes, v_seller_user_id, v_seller_user_id, public.get_current_user_role()
    );

    -- Record Tracking Event
    INSERT INTO public.order_tracking_events (
        order_id, seller_store_id, event_type, description, location
    ) VALUES (
        p_order_id, v_store_id, p_new_status,
        'Store Fulfillment ' || p_new_status || COALESCE(' via ' || p_courier_name || ' (Tracking #: ' || p_tracking_number || ')', ''),
        'Seller Warehouse'
    );

    -- Derive Parent buyer_orders.status Dynamically across all Store Fulfillments
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE fulfillment_status = 'Delivered'),
        COUNT(*) FILTER (WHERE fulfillment_status = 'Shipped')
    INTO v_total_fulfillments, v_delivered_count, v_shipped_count
    FROM public.store_fulfillments
    WHERE order_id = p_order_id
      AND fulfillment_status <> 'Cancelled';

    IF v_total_fulfillments > 0 AND v_delivered_count = v_total_fulfillments THEN
        v_derived_parent_status := 'Delivered';
    ELSIF v_shipped_count > 0 THEN
        v_derived_parent_status := 'Shipped';
    ELSE
        v_derived_parent_status := 'Processing';
    END IF;

    UPDATE public.buyer_orders
    SET status = v_derived_parent_status, updated_at = NOW()
    WHERE id = p_order_id;

    -- Send Server Notification to Buyer
    PERFORM public.internal_create_notification(
        v_order_customer_id,
        'ORDER_STATUS_UPDATE',
        'Order Update: ' || p_new_status,
        'Your items for order ' || p_order_id || ' are now ' || p_new_status || '.',
        'ORDER',
        p_order_id,
        'NOTIF-ORD-' || p_order_id || '-' || v_store_id::text || '-' || p_new_status
    );

    v_result := jsonb_build_object(
        'success', TRUE,
        'order_id', p_order_id,
        'store_id', v_store_id,
        'store_fulfillment_status', p_new_status,
        'parent_order_status', v_derived_parent_status
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.seller_update_fulfillment_status(TEXT, TEXT, UUID, TEXT, TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 13. SERVER-AUTHORITATIVE RPC: ORDER CANCELLATION (IDEMPOTENT & STOCK RESTORATIVE)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cancel_order(
    p_order_id TEXT,
    p_seller_store_id UUID DEFAULT NULL,
    p_reason TEXT DEFAULT 'Cancelled by user'
)
RETURNS JSONB AS $$
DECLARE
    v_actor_id UUID;
    v_actor_role public.app_role;
    v_customer_user_id UUID;
    v_order_status TEXT;
    v_payment_status TEXT;
    v_item RECORD;
    v_ful RECORD;
    v_canceled_any BOOLEAN := FALSE;
    v_result JSONB;
BEGIN
    v_actor_id := auth.uid();
    IF v_actor_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    v_actor_role := public.get_current_user_role();

    SELECT customer_user_id, status, payment_status
    INTO v_customer_user_id, v_order_status, v_payment_status
    FROM public.buyer_orders
    WHERE id = p_order_id FOR UPDATE;

    IF v_order_status IS NULL THEN
        RAISE EXCEPTION 'Order % does not exist.', p_order_id;
    END IF;

    IF v_order_status = 'Cancelled' THEN
        RETURN jsonb_build_object('success', TRUE, 'already_cancelled', TRUE, 'order_id', p_order_id);
    END IF;

    -- Buyer Cancellation Rules: Can cancel whole order only if pre-fulfillment (Pending / Processing)
    IF v_actor_role = 'buyer' THEN
        IF v_customer_user_id <> v_actor_id THEN
            RAISE EXCEPTION 'Access denied: You do not own order %.', p_order_id;
        END IF;

        IF v_order_status IN ('Shipped', 'Delivered') THEN
            RAISE EXCEPTION 'Cannot cancel order %: Order is already %.', p_order_id, v_order_status;
        END IF;
    END IF;

    -- Seller Cancellation Rules: Can cancel only own store fulfillment
    IF v_actor_role = 'seller' AND p_seller_store_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM public.seller_stores WHERE id = p_seller_store_id AND owner_id = v_actor_id) THEN
            RAISE EXCEPTION 'Access denied: You do not own store %.', p_seller_store_id;
        END IF;
    END IF;

    -- Cancel Store Fulfillments and Restore Stock for Affected Items
    FOR v_ful IN SELECT id, seller_store_id, fulfillment_status FROM public.store_fulfillments
                 WHERE order_id = p_order_id
                   AND (p_seller_store_id IS NULL OR seller_store_id = p_seller_store_id)
                   AND fulfillment_status <> 'Cancelled'
    LOOP
        IF v_ful.fulfillment_status IN ('Shipped', 'Delivered') AND v_actor_role <> 'super_admin' THEN
            RAISE EXCEPTION 'Cannot cancel store fulfillment %: Already %.', v_ful.id, v_ful.fulfillment_status;
        END IF;

        UPDATE public.store_fulfillments
        SET fulfillment_status = 'Cancelled', updated_at = NOW()
        WHERE id = v_ful.id;

        -- Restore Inventory for Order Items belonging to canceled store fulfillment
        FOR v_item IN SELECT oi.product_id, oi.variant_id, oi.quantity
                      FROM public.order_items oi
                      WHERE oi.order_id = p_order_id
                        AND oi.seller_store_id = v_ful.seller_store_id
        LOOP
            IF v_item.variant_id IS NOT NULL THEN
                UPDATE public.product_variants
                SET stock_quantity = stock_quantity + v_item.quantity, updated_at = NOW()
                WHERE id = v_item.variant_id;
            ELSE
                UPDATE public.products
                SET stock_quantity = stock_quantity + v_item.quantity, updated_at = NOW()
                WHERE id = v_item.product_id;
            END IF;
        END LOOP;

        v_canceled_any := TRUE;
    END LOOP;

    -- If all active fulfillments are now cancelled, mark parent order Cancelled and update payment
    IF NOT EXISTS (SELECT 1 FROM public.store_fulfillments WHERE order_id = p_order_id AND fulfillment_status <> 'Cancelled') THEN
        UPDATE public.buyer_orders
        SET status = 'Cancelled', updated_at = NOW()
        WHERE id = p_order_id;

        UPDATE public.payments
        SET status = 'Cancelled', updated_at = NOW()
        WHERE order_id = p_order_id AND status = 'Pending';
    END IF;

    -- Record Status History
    INSERT INTO public.order_status_history (
        order_id, seller_store_id, status, old_status, notes, created_by, actor_user_id, actor_role
    ) VALUES (
        p_order_id, p_seller_store_id, 'Cancelled', v_order_status, p_reason, v_actor_id, v_actor_id, v_actor_role
    );

    -- Notify Customer
    PERFORM public.internal_create_notification(
        v_customer_user_id,
        'ORDER_CANCELLED',
        'Order Cancelled',
        'Order ' || p_order_id || ' has been cancelled (' || p_reason || ').',
        'ORDER',
        p_order_id,
        'NOTIF-CANCEL-' || p_order_id || '-' || COALESCE(p_seller_store_id::text, 'ALL')
    );

    v_result := jsonb_build_object('success', TRUE, 'already_cancelled', FALSE, 'order_id', p_order_id);
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.cancel_order(TEXT, UUID, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 14. SERVER-AUTHORITATIVE RPC: SUBMIT RETURN REQUEST
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_return_request(
    p_order_id TEXT,
    p_order_item_id UUID,
    p_quantity INT,
    p_reason TEXT,
    p_description TEXT DEFAULT NULL,
    p_evidence_paths TEXT[] DEFAULT '{}'::TEXT[]
)
RETURNS JSONB AS $$
DECLARE
    v_buyer_user_id UUID;
    v_customer_user_id UUID;
    v_order_status TEXT;
    v_seller_store_id UUID;
    v_purchased_qty INT;
    v_already_returned_qty INT := 0;
    v_return_id UUID;
    v_result JSONB;
BEGIN
    v_buyer_user_id := auth.uid();
    IF v_buyer_user_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Return quantity must be greater than zero.';
    END IF;

    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'Return reason is required.';
    END IF;

    -- Fetch Order & Line Item Details
    SELECT bo.customer_user_id, bo.status, oi.seller_store_id, oi.quantity
    INTO v_customer_user_id, v_order_status, v_seller_store_id, v_purchased_qty
    FROM public.order_items oi
    JOIN public.buyer_orders bo ON bo.id = oi.order_id
    WHERE oi.id = p_order_item_id
      AND oi.order_id = p_order_id;

    IF v_seller_store_id IS NULL THEN
        RAISE EXCEPTION 'Target order line item % not found for order %.', p_order_item_id, p_order_id;
    END IF;

    IF v_customer_user_id <> v_buyer_user_id THEN
        RAISE EXCEPTION 'Access denied: You do not own order %.', p_order_id;
    END IF;

    IF v_order_status <> 'Delivered' THEN
        RAISE EXCEPTION 'Return requests can only be submitted for Delivered orders (Current status: %).', v_order_status;
    END IF;

    -- Cumulative Return Quantity Accounting
    SELECT COALESCE(SUM(quantity), 0) INTO v_already_returned_qty
    FROM public.return_requests
    WHERE order_item_id = p_order_item_id
      AND status IN ('Requested', 'Approved', 'Completed');

    IF (v_already_returned_qty + p_quantity) > v_purchased_qty THEN
        RAISE EXCEPTION 'Return quantity exceeds eligible purchased quantity. Eligible: %, Requested: %', (v_purchased_qty - v_already_returned_qty), p_quantity;
    END IF;

    -- Insert Return Request Row
    INSERT INTO public.return_requests (
        order_id, order_item_id, seller_store_id, customer_user_id, quantity, reason, description, evidence_paths, status
    ) VALUES (
        p_order_id, p_order_item_id, v_seller_store_id, v_buyer_user_id, p_quantity, p_reason, p_description, p_evidence_paths, 'Requested'
    ) RETURNING id INTO v_return_id;

    -- Notify Seller Store Owner
    PERFORM public.internal_create_notification(
        (SELECT owner_id FROM public.seller_stores WHERE id = v_seller_store_id),
        'RETURN_REQUESTED',
        'New Return Request',
        'A return request for item in order ' || p_order_id || ' has been submitted.',
        'RETURN',
        v_return_id::text,
        'NOTIF-RET-' || v_return_id::text
    );

    v_result := jsonb_build_object(
        'success', TRUE,
        'return_id', v_return_id,
        'order_id', p_order_id,
        'status', 'Requested'
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.submit_return_request(TEXT, UUID, INT, TEXT, TEXT, TEXT[]) TO authenticated;

-- ----------------------------------------------------------------------------
-- 15. SERVER-AUTHORITATIVE RPC: REVIEW RETURN REQUEST & PHASE 10 REFUND INTEGRATION
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.review_return_request(
    p_return_id UUID,
    p_decision TEXT, -- 'Approved' or 'Rejected'
    p_admin_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_reviewer_id UUID;
    v_return RECORD;
    v_refund_amount NUMERIC(12,2);
    v_idempotency_key TEXT;
    v_refund_res JSONB;
    v_refund_id UUID;
    v_result JSONB;
BEGIN
    v_reviewer_id := auth.uid();
    IF v_reviewer_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF p_decision NOT IN ('Approved', 'Rejected') THEN
        RAISE EXCEPTION 'Invalid return review decision: %', p_decision;
    END IF;

    -- Lock & Fetch Return Request Row
    SELECT id, order_id, order_item_id, seller_store_id, customer_user_id, quantity, status
    INTO v_return
    FROM public.return_requests
    WHERE id = p_return_id FOR UPDATE;

    IF v_return.id IS NULL THEN
        RAISE EXCEPTION 'Return request % not found.', p_return_id;
    END IF;

    -- Authorization: Seller store owner or Admin with returns:review permission
    IF NOT (
        EXISTS (SELECT 1 FROM public.seller_stores WHERE id = v_return.seller_store_id AND owner_id = v_reviewer_id)
        OR public.has_permission('returns', 'review')
    ) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to review return request.';
    END IF;

    IF v_return.status <> 'Requested' THEN
        RAISE EXCEPTION 'Return request % is already in % status.', p_return_id, v_return.status;
    END IF;

    IF p_decision = 'Rejected' THEN
        UPDATE public.return_requests
        SET status = 'Rejected', admin_notes = p_admin_notes, processed_by = v_reviewer_id, updated_at = NOW()
        WHERE id = p_return_id;

        PERFORM public.internal_create_notification(
            v_return.customer_user_id,
            'RETURN_REJECTED',
            'Return Request Rejected',
            'Your return request for order ' || v_return.order_id || ' was rejected.',
            'RETURN',
            p_return_id::text,
            'NOTIF-RET-DEC-' || p_return_id::text || '-REJ'
        );

        v_result := jsonb_build_object('success', TRUE, 'status', 'Rejected', 'return_id', p_return_id);
        RETURN v_result;

    ELSIF p_decision = 'Approved' THEN
        -- Calculate Refund Amount based on Line Item Unit Price * Returned Quantity
        SELECT (unit_price * v_return.quantity) INTO v_refund_amount
        FROM public.order_items
        WHERE id = v_return.order_item_id;

        v_idempotency_key := 'REF-RET-' || p_return_id::text;

        -- Invoke Phase 10 Authoritative Refund Function
        v_refund_res := public.admin_process_refund(
            v_return.order_id,
            v_return.order_item_id,
            v_refund_amount,
            'Approved Return Request ' || p_return_id::text,
            v_idempotency_key
        );

        v_refund_id := (v_refund_res->>'refund_id')::uuid;

        UPDATE public.return_requests
        SET status = 'Completed', refund_id = v_refund_id, admin_notes = p_admin_notes, processed_by = v_reviewer_id, updated_at = NOW()
        WHERE id = p_return_id;

        PERFORM public.internal_create_notification(
            v_return.customer_user_id,
            'RETURN_APPROVED',
            'Return Request Approved',
            'Your return request for order ' || v_return.order_id || ' was approved and refund processed.',
            'RETURN',
            p_return_id::text,
            'NOTIF-RET-DEC-' || p_return_id::text || '-APP'
        );

        v_result := jsonb_build_object(
            'success', TRUE,
            'status', 'Completed',
            'return_id', p_return_id,
            'refund_id', v_refund_id,
            'refund_amount', v_refund_amount
        );

        RETURN v_result;
    END IF;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.review_return_request(UUID, TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 16. SERVER-AUTHORITATIVE RPC: SUBMIT PRODUCT REVIEW
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_product_review(
    p_product_id UUID,
    p_order_item_id UUID,
    p_rating INT,
    p_comment TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_buyer_id UUID;
    v_customer_user_id UUID;
    v_order_status TEXT;
    v_item_product_id UUID;
    v_review_id UUID;
    v_result JSONB;
BEGIN
    v_buyer_id := auth.uid();
    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'Rating must be an integer between 1 and 5.';
    END IF;

    IF p_comment IS NULL OR trim(p_comment) = '' THEN
        RAISE EXCEPTION 'Review comment cannot be empty.';
    END IF;

    -- Verify Line Item & Order Ownership
    SELECT bo.customer_user_id, bo.status, oi.product_id
    INTO v_customer_user_id, v_order_status, v_item_product_id
    FROM public.order_items oi
    JOIN public.buyer_orders bo ON bo.id = oi.order_id
    WHERE oi.id = p_order_item_id;

    IF v_item_product_id IS NULL THEN
        RAISE EXCEPTION 'Order line item % not found.', p_order_item_id;
    END IF;

    IF v_item_product_id <> p_product_id THEN
        RAISE EXCEPTION 'Line item % does not match product %.', p_order_item_id, p_product_id;
    END IF;

    IF v_customer_user_id <> v_buyer_id THEN
        RAISE EXCEPTION 'Access denied: You do not own the order associated with line item %.', p_order_item_id;
    END IF;

    IF v_order_status <> 'Delivered' THEN
        RAISE EXCEPTION 'Product reviews are only permitted for Delivered orders (Current status: %).', v_order_status;
    END IF;

    -- Duplicate Check via UNIQUE constraint
    BEGIN
        INSERT INTO public.product_reviews (
            product_id, order_item_id, buyer_user_id, rating, comment, is_verified_purchase
        ) VALUES (
            p_product_id, p_order_item_id, v_buyer_id, p_rating, p_comment, TRUE
        ) RETURNING id INTO v_review_id;
    EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'You have already submitted a review for this purchased line item.';
    END;

    v_result := jsonb_build_object(
        'success', TRUE,
        'review_id', v_review_id,
        'product_id', p_product_id,
        'rating', p_rating
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.submit_product_review(UUID, UUID, INT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 17. SERVER-AUTHORITATIVE RPC: SEND CHAT MESSAGE
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.send_chat_message(
    p_room_id UUID,
    p_message_text TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_sender_id UUID;
    v_room RECORD;
    v_recipient_id UUID;
    v_msg_id UUID;
    v_result JSONB;
BEGIN
    v_sender_id := auth.uid();
    IF v_sender_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF p_message_text IS NULL OR trim(p_message_text) = '' THEN
        RAISE EXCEPTION 'Message text cannot be empty.';
    END IF;

    -- Fetch Chat Room Details
    SELECT cr.id, cr.buyer_user_id, ss.owner_id AS seller_owner_id
    INTO v_room
    FROM public.chat_rooms cr
    JOIN public.seller_stores ss ON ss.id = cr.seller_store_id
    WHERE cr.id = p_room_id;

    IF v_room.id IS NULL THEN
        RAISE EXCEPTION 'Chat room % not found.', p_room_id;
    END IF;

    -- Room Membership Check
    IF v_sender_id <> v_room.buyer_user_id AND v_sender_id <> v_room.seller_owner_id AND NOT public.has_permission('chat', 'monitor') THEN
        RAISE EXCEPTION 'Access denied: You are not a participant in chat room %.', p_room_id;
    END IF;

    -- Determine Recipient ID
    IF v_sender_id = v_room.buyer_user_id THEN
        v_recipient_id := v_room.seller_owner_id;
    ELSE
        v_recipient_id := v_room.buyer_user_id;
    END IF;

    -- Insert Message
    INSERT INTO public.chat_messages (
        room_id, sender_id, message_text
    ) VALUES (
        p_room_id, v_sender_id, p_message_text
    ) RETURNING id INTO v_msg_id;

    -- Create Notification for Recipient
    PERFORM public.internal_create_notification(
        v_recipient_id,
        'NEW_CHAT_MESSAGE',
        'New Chat Message',
        'You have a new message: ' || substring(p_message_text from 1 for 50),
        'CHAT',
        p_room_id::text,
        'NOTIF-MSG-' || v_msg_id::text
    );

    v_result := jsonb_build_object(
        'success', TRUE,
        'message_id', v_msg_id,
        'room_id', p_room_id,
        'sender_id', v_sender_id
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.send_chat_message(UUID, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 18. SERVER-AUTHORITATIVE RPC: CREATE CHAT ROOM (SAFE & AUTH-DERIVED)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_chat_room(
    p_seller_store_id UUID,
    p_product_id UUID DEFAULT NULL,
    p_order_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_buyer_id UUID;
    v_room_id UUID;
    v_result JSONB;
BEGIN
    v_buyer_id := auth.uid();
    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.seller_stores WHERE id = p_seller_store_id) THEN
        RAISE EXCEPTION 'Seller store % not found.', p_seller_store_id;
    END IF;

    INSERT INTO public.chat_rooms (
        buyer_user_id, seller_store_id, product_id, order_id
    ) VALUES (
        v_buyer_id, p_seller_store_id, p_product_id, p_order_id
    ) ON CONFLICT (buyer_user_id, seller_store_id, product_id)
    DO UPDATE SET created_at = chat_rooms.created_at
    RETURNING id INTO v_room_id;

    v_result := jsonb_build_object(
        'success', TRUE,
        'room_id', v_room_id,
        'buyer_user_id', v_buyer_id,
        'seller_store_id', p_seller_store_id
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.create_chat_room(UUID, UUID, TEXT) TO authenticated;
-- ============================================================================
-- MIGRATION: 20260812000000_phase_b_unified_roles_and_tables.sql
-- PURPOSE: Phase B Core Marketplace Infrastructure:
--          1. Persistent Carts & Cart Items with Strict RLS
--          2. Buyer Delivery Addresses with Strict RLS
--          3. Truthful Server-Authoritative Price Quoting RPC (quote_order)
--          4. Seller Fulfillment State Machine RPC (seller_update_fulfillment_status)
--          5. Verified Buyer Product Review RPC (submit_product_review)
--          6. Return Request RPCs (submit_return_request, review_return_request)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. PERSISTENT CARTS & CART ITEMS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.carts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.carts ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.cart_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id UUID NOT NULL REFERENCES public.carts(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    quantity INT NOT NULL CHECK (quantity > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(cart_id, product_id)
);

ALTER TABLE public.cart_items ENABLE ROW LEVEL SECURITY;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_carts_user_id ON public.carts(user_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_cart_id ON public.cart_items(cart_id);
CREATE INDEX IF NOT EXISTS idx_cart_items_product_id ON public.cart_items(product_id);

-- RLS Policies for Carts
DROP POLICY IF EXISTS "Users can manage own cart" ON public.carts;
CREATE POLICY "Users can manage own cart" ON public.carts
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- RLS Policies for Cart Items
DROP POLICY IF EXISTS "Users can manage own cart items" ON public.cart_items;
CREATE POLICY "Users can manage own cart items" ON public.cart_items
    FOR ALL
    TO authenticated
    USING (
        cart_id IN (SELECT id FROM public.carts WHERE user_id = auth.uid())
    )
    WITH CHECK (
        cart_id IN (SELECT id FROM public.carts WHERE user_id = auth.uid())
    );

-- Grants
GRANT SELECT, INSERT, UPDATE, DELETE ON public.carts TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cart_items TO authenticated;

-- ----------------------------------------------------------------------------
-- 2. BUYER DELIVERY ADDRESSES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT 'Home',
    recipient_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    address_line TEXT NOT NULL,
    city TEXT NOT NULL,
    province TEXT NOT NULL DEFAULT 'Punjab',
    union_council TEXT,
    landmark TEXT,
    gate_instructions TEXT,
    delivery_slot TEXT DEFAULT 'Morning',
    postal_code TEXT DEFAULT '54000',
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON public.addresses(user_id);

-- RLS Policies for Addresses
DROP POLICY IF EXISTS "Users can manage own addresses" ON public.addresses;
CREATE POLICY "Users can manage own addresses" ON public.addresses
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.addresses TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. SERVER-AUTHORITATIVE PRICE QUOTE RPC (quote_order)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.quote_order(
    p_items JSONB,
    p_coupon_code TEXT DEFAULT NULL,
    p_city TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_item JSONB;
    v_product_id UUID;
    v_requested_qty INT;
    v_product RECORD;
    v_effective_price NUMERIC(12,2);
    v_line_total NUMERIC(12,2);
    v_subtotal NUMERIC(12,2) := 0.00;
    v_discount NUMERIC(12,2) := 0.00;
    v_shipping_fee NUMERIC(12,2) := 200.00; -- Standard flat delivery
    v_grand_total NUMERIC(12,2) := 0.00;
    v_item_count INT := 0;
    v_quoted_items JSONB := '[]'::jsonb;
BEGIN
    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Cart is empty'
        );
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        v_product_id := (v_item->>'product_id')::UUID;
        v_requested_qty := COALESCE((v_item->>'quantity')::INT, 1);

        IF v_requested_qty <= 0 THEN
            v_requested_qty := 1;
        END IF;

        SELECT id, name, price, sale_price, stock_quantity, is_active, approval_status, image_url
        INTO v_product
        FROM public.products
        WHERE id = v_product_id;

        IF NOT FOUND THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Product ' || v_product_id::TEXT || ' not found'
            );
        END IF;

        IF NOT v_product.is_active OR v_product.approval_status != 'Approved' THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Product "' || v_product.name || '" is currently unavailable'
            );
        END IF;

        IF v_product.stock_quantity < v_requested_qty THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Insufficient stock for product "' || v_product.name || '". Available: ' || v_product.stock_quantity::TEXT
            );
        END IF;

        v_effective_price := COALESCE(v_product.sale_price, v_product.price);
        v_line_total := v_effective_price * v_requested_qty;
        v_subtotal := v_subtotal + v_line_total;
        v_item_count := v_item_count + v_requested_qty;

        v_quoted_items := v_quoted_items || jsonb_build_object(
            'product_id', v_product.id,
            'name', v_product.name,
            'unit_price', v_effective_price,
            'quantity', v_requested_qty,
            'line_total', v_line_total,
            'image_url', v_product.image_url
        );
    END LOOP;

    -- Dynamic Shipping Rules: Free shipping for orders PKR 5,000 and above
    IF v_subtotal >= 5000.00 THEN
        v_shipping_fee := 0.00;
    END IF;

    -- Validate Optional Promo Coupon
    IF p_coupon_code IS NOT NULL AND TRIM(p_coupon_code) != '' THEN
        IF UPPER(TRIM(p_coupon_code)) = 'WELCOME500' AND v_subtotal >= 2000.00 THEN
            v_discount := 500.00;
        ELSIF UPPER(TRIM(p_coupon_code)) = 'EID2026' AND v_subtotal >= 1000.00 THEN
            v_discount := 200.00;
        ELSIF UPPER(TRIM(p_coupon_code)) = 'APNA10' THEN
            v_discount := ROUND(v_subtotal * 0.10, 2);
        END IF;
    END IF;

    IF v_discount > v_subtotal THEN
        v_discount := v_subtotal;
    END IF;

    v_grand_total := v_subtotal - v_discount + v_shipping_fee;

    RETURN jsonb_build_object(
        'success', true,
        'subtotal', v_subtotal,
        'discount', v_discount,
        'shipping_fee', v_shipping_fee,
        'grand_total', v_grand_total,
        'item_count', v_item_count,
        'items', v_quoted_items
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.quote_order(JSONB, TEXT, TEXT) TO authenticated, anon;

-- ----------------------------------------------------------------------------
-- 4. SELLER FULFILLMENT STATE MACHINE RPC
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.seller_update_fulfillment_status(
    p_order_id TEXT,
    p_new_status TEXT,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_order RECORD;
    v_seller_store RECORD;
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    -- Locate seller store owned by caller
    SELECT id, is_approved INTO v_seller_store
    FROM public.seller_stores
    WHERE owner_id = v_current_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User does not own a registered seller store.' USING ERRCODE = '42501';
    END IF;

    -- Lock order for update
    SELECT id, order_number, status, seller_store_id
    INTO v_order
    FROM public.buyer_orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Verify ownership
    IF v_order.seller_store_id != v_seller_store.id THEN
        RAISE EXCEPTION 'Unauthorized to update fulfillment status for this store.' USING ERRCODE = '42501';
    END IF;

    -- Enforce Strict Forward State Transitions
    IF v_order.status = 'Pending' AND p_new_status NOT IN ('Processing', 'Cancelled') THEN
        RAISE EXCEPTION 'Pending order can only transition to Processing or Cancelled.' USING ERRCODE = '22023';
    ELSIF v_order.status = 'Processing' AND p_new_status NOT IN ('Shipped', 'Cancelled') THEN
        RAISE EXCEPTION 'Processing order can only transition to Shipped or Cancelled.' USING ERRCODE = '22023';
    ELSIF v_order.status = 'Shipped' AND p_new_status NOT IN ('Delivered') THEN
        RAISE EXCEPTION 'Shipped order can only transition to Delivered.' USING ERRCODE = '22023';
    ELSIF v_order.status IN ('Delivered', 'Cancelled') THEN
        RAISE EXCEPTION 'Terminal orders cannot change status.' USING ERRCODE = '22023';
    END IF;

    -- Update Order Status
    UPDATE public.buyer_orders
    SET status = p_new_status,
        updated_at = NOW()
    WHERE id = p_order_id;

    -- Append status audit trail
    INSERT INTO public.order_status_history (order_id, status, notes, created_by)
    VALUES (p_order_id, p_new_status, p_notes, v_current_user_id);

    RETURN jsonb_build_object(
        'success', true,
        'order_id', p_order_id,
        'old_status', v_order.status,
        'new_status', p_new_status
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.seller_update_fulfillment_status(TEXT, TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 5. VERIFIED PRODUCT REVIEW SUBMISSION RPC
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_product_review(
    p_product_id UUID,
    p_rating NUMERIC,
    p_review_text TEXT,
    p_images JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_has_delivered_order BOOLEAN := FALSE;
    v_review_id UUID;
    v_new_avg_rating NUMERIC(3,2);
    v_total_reviews INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF p_rating < 1.0 OR p_rating > 5.0 THEN
        RAISE EXCEPTION 'Rating must be between 1.0 and 5.0' USING ERRCODE = '22023';
    END IF;

    -- Verify that caller actually purchased and received this product
    SELECT EXISTS (
        SELECT 1
        FROM public.buyer_orders bo
        JOIN public.order_items oi ON oi.order_id = bo.id
        WHERE bo.customer_user_id = v_user_id
          AND oi.product_id = p_product_id
          AND bo.status = 'Delivered'
    ) INTO v_has_delivered_order;

    IF NOT v_has_delivered_order THEN
        RAISE EXCEPTION 'Verified purchase required. You can only review products that have been delivered to you.' USING ERRCODE = '42501';
    END IF;

    -- Insert or update review
    INSERT INTO public.product_reviews (
        product_id,
        user_id,
        rating,
        review_text,
        is_verified_purchase,
        created_at
    )
    VALUES (
        p_product_id,
        v_user_id,
        p_rating,
        p_review_text,
        TRUE,
        NOW()
    )
    ON CONFLICT (product_id, user_id) DO UPDATE
    SET rating = EXCLUDED.rating,
        review_text = EXCLUDED.review_text,
        updated_at = NOW()
    RETURNING id INTO v_review_id;

    -- Calculate updated product average rating
    SELECT ROUND(AVG(rating)::NUMERIC, 2), COUNT(*)
    INTO v_new_avg_rating, v_total_reviews
    FROM public.product_reviews
    WHERE product_id = p_product_id;

    -- Update product table rating
    UPDATE public.products
    SET rating = v_new_avg_rating
    WHERE id = p_product_id;

    RETURN jsonb_build_object(
        'success', true,
        'review_id', v_review_id,
        'new_rating', v_new_avg_rating,
        'total_reviews', v_total_reviews
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_product_review(UUID, NUMERIC, TEXT, JSONB) TO authenticated;

-- ----------------------------------------------------------------------------
-- 6. RETURNS & REFUNDS RPCs
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_return_request(
    p_order_id TEXT,
    p_product_id UUID,
    p_reason TEXT,
    p_details TEXT DEFAULT NULL,
    p_images JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_order RECORD;
    v_return_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    SELECT id, customer_user_id, status, created_at
    INTO v_order
    FROM public.buyer_orders
    WHERE id = p_order_id;

    IF NOT FOUND OR v_order.customer_user_id != v_user_id THEN
        RAISE EXCEPTION 'Order not found or unauthorized.' USING ERRCODE = '42501';
    END IF;

    IF v_order.status != 'Delivered' THEN
        RAISE EXCEPTION 'Return requests can only be submitted for Delivered orders.' USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.return_requests (
        order_id,
        user_id,
        product_id,
        reason,
        details,
        status,
        created_at
    )
    VALUES (
        p_order_id,
        v_user_id,
        p_product_id,
        p_reason,
        p_details,
        'Pending',
        NOW()
    )
    RETURNING id INTO v_return_id;

    RETURN jsonb_build_object(
        'success', true,
        'return_id', v_return_id,
        'status', 'Pending'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_return_request(TEXT, UUID, TEXT, TEXT, JSONB) TO authenticated;

CREATE OR REPLACE FUNCTION public.review_return_request(
    p_return_id UUID,
    p_decision TEXT, -- 'Approved' or 'Rejected'
    p_admin_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_authorized BOOLEAN := FALSE;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF p_decision NOT IN ('Approved', 'Rejected') THEN
        RAISE EXCEPTION 'Decision must be Approved or Rejected.' USING ERRCODE = '22023';
    END IF;

    -- Check if admin or store owner
    SELECT EXISTS (
        SELECT 1 FROM public.user_roles WHERE user_id = v_user_id AND role IN ('admin', 'super_admin')
    ) INTO v_is_authorized;

    IF NOT v_is_authorized THEN
        RAISE EXCEPTION 'Unauthorized to review return requests.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.return_requests
    SET status = p_decision,
        admin_notes = p_admin_notes,
        resolved_at = NOW()
    WHERE id = p_return_id;

    RETURN jsonb_build_object(
        'success', true,
        'return_id', p_return_id,
        'status', p_decision
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.review_return_request(UUID, TEXT, TEXT) TO authenticated;
-- ============================================================================
-- MIGRATION: 20260813000000_phase_c_seller_admin_ops.sql
-- PURPOSE: Phase C Seller & Admin Operations:
--          1. Payout Requests Table with Strict RLS & Ledger Isolation
--          2. Brands Table with Category Governance RLS
--          3. Category Table Full RLS for Administrative CRUD
--          4. Seller Payout Request RPC (seller_request_payout)
--          5. Admin Process Payout RPC (admin_process_payout)
--          6. Admin Seller Suspension & Payout Lock Enforcement RPCs
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SELLER PAYOUT REQUESTS TABLE & AUDIT CONSTRAINTS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.seller_payout_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_store_id UUID NOT NULL REFERENCES public.seller_stores(id) ON DELETE CASCADE,
    requested_by UUID NOT NULL REFERENCES auth.users(id),
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    bank_name TEXT NOT NULL,
    account_number TEXT NOT NULL,
    account_title TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected', 'Processed')),
    rejection_reason TEXT,
    processed_by UUID REFERENCES auth.users(id),
    gateway_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.seller_payout_requests ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_payout_store_id ON public.seller_payout_requests(seller_store_id);
CREATE INDEX IF NOT EXISTS idx_payout_requested_by ON public.seller_payout_requests(requested_by);
CREATE INDEX IF NOT EXISTS idx_payout_status ON public.seller_payout_requests(status);

-- RLS Policies for Payout Requests
DROP POLICY IF EXISTS "Sellers can view own payout requests" ON public.seller_payout_requests;
CREATE POLICY "Sellers can view own payout requests" ON public.seller_payout_requests
    FOR SELECT
    TO authenticated
    USING (
        requested_by = auth.uid()
        OR seller_store_id IN (SELECT id FROM public.seller_stores WHERE owner_id = auth.uid())
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "Sellers can create payout requests for own store" ON public.seller_payout_requests;
CREATE POLICY "Sellers can create payout requests for own store" ON public.seller_payout_requests
    FOR INSERT
    TO authenticated
    WITH CHECK (
        requested_by = auth.uid()
        AND seller_store_id IN (SELECT id FROM public.seller_stores WHERE owner_id = auth.uid())
    );

DROP POLICY IF EXISTS "Admins can update payout requests" ON public.seller_payout_requests;
CREATE POLICY "Admins can update payout requests" ON public.seller_payout_requests
    FOR UPDATE
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

GRANT SELECT, INSERT ON public.seller_payout_requests TO authenticated;

-- ----------------------------------------------------------------------------
-- 2. BRANDS TABLE & RLS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    logo_url TEXT,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.brands ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view active brands" ON public.brands;
CREATE POLICY "Anyone can view active brands" ON public.brands
    FOR SELECT
    TO anon, authenticated
    USING (is_active = true OR public.is_admin());

DROP POLICY IF EXISTS "Admins can manage brands" ON public.brands;
CREATE POLICY "Admins can manage brands" ON public.brands
    FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

GRANT SELECT ON public.brands TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.brands TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. CATEGORIES TABLE RLS ENHANCEMENT FOR ADMIN CRUD
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Anyone can view active categories" ON public.categories;
CREATE POLICY "Anyone can view active categories" ON public.categories
    FOR SELECT
    TO anon, authenticated
    USING (is_active = true OR public.is_admin());

DROP POLICY IF EXISTS "Admins can manage categories" ON public.categories;
CREATE POLICY "Admins can manage categories" ON public.categories
    FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

GRANT SELECT ON public.categories TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.categories TO authenticated;

-- ----------------------------------------------------------------------------
-- 4. SELLER PAYOUT REQUEST RPC (seller_request_payout)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.seller_request_payout(
    p_store_id UUID,
    p_amount NUMERIC(12,2),
    p_bank_name TEXT,
    p_account_number TEXT,
    p_account_title TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_store RECORD;
    v_new_payout_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated request');
    END IF;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid payout amount');
    END IF;

    SELECT id, owner_id, is_approved, is_suspended, is_payout_locked, balance, pending_payout
    INTO v_store
    FROM public.seller_stores
    WHERE id = p_store_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Store not found');
    END IF;

    IF v_store.owner_id != auth.uid() AND NOT public.is_admin() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: You do not own this store');
    END IF;

    IF NOT v_store.is_approved THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot request payout: Store is not approved');
    END IF;

    IF COALESCE(v_store.is_suspended, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot request payout: Store account is suspended');
    END IF;

    IF COALESCE(v_store.is_payout_locked, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot request payout: Store payouts are currently locked');
    END IF;

    IF v_store.balance < p_amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient available balance');
    END IF;

    -- Update store balance atomically
    UPDATE public.seller_stores
    SET balance = balance - p_amount,
        pending_payout = COALESCE(pending_payout, 0.00) + p_amount,
        updated_at = NOW()
    WHERE id = p_store_id;

    -- Insert payout record
    INSERT INTO public.seller_payout_requests (
        seller_store_id,
        requested_by,
        amount,
        bank_name,
        account_number,
        account_title,
        status
    )
    VALUES (
        p_store_id,
        auth.uid(),
        p_amount,
        p_bank_name,
        p_account_number,
        p_account_title,
        'Pending'
    )
    RETURNING id INTO v_new_payout_id;

    RETURN jsonb_build_object(
        'success', true,
        'payout_id', v_new_payout_id,
        'amount', p_amount,
        'remaining_balance', v_store.balance - p_amount
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. ADMIN PROCESS PAYOUT RPC (admin_process_payout)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_process_payout(
    p_payout_id UUID,
    p_action TEXT,
    p_reason TEXT DEFAULT NULL,
    p_reference TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_payout RECORD;
BEGIN
    IF auth.uid() IS NULL OR NOT public.is_admin() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Administrator privileges required.');
    END IF;

    SELECT id, seller_store_id, amount, status
    INTO v_payout
    FROM public.seller_payout_requests
    WHERE id = p_payout_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Payout request not found');
    END IF;

    IF v_payout.status != 'Pending' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Payout request is already ' || v_payout.status);
    END IF;

    IF p_action = 'Approve' OR p_action = 'Process' THEN
        UPDATE public.seller_payout_requests
        SET status = 'Processed',
            processed_by = auth.uid(),
            gateway_reference = p_reference,
            updated_at = NOW()
        WHERE id = p_payout_id;

        UPDATE public.seller_stores
        SET pending_payout = GREATEST(0.00, COALESCE(pending_payout, 0.00) - v_payout.amount),
            last_payout = v_payout.amount,
            updated_at = NOW()
        WHERE id = v_payout.seller_store_id;

        RETURN jsonb_build_object('success', true, 'status', 'Processed');

    ELSIF p_action = 'Reject' THEN
        UPDATE public.seller_payout_requests
        SET status = 'Rejected',
            rejection_reason = p_reason,
            processed_by = auth.uid(),
            updated_at = NOW()
        WHERE id = p_payout_id;

        -- Restore amount to store balance
        UPDATE public.seller_stores
        SET balance = balance + v_payout.amount,
            pending_payout = GREATEST(0.00, COALESCE(pending_payout, 0.00) - v_payout.amount),
            updated_at = NOW()
        WHERE id = v_payout.seller_store_id;

        RETURN jsonb_build_object('success', true, 'status', 'Rejected');
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'Invalid action: Must be Approve, Process, or Reject');
    END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- 6. ADMIN SELLER SUSPENSION & PAYOUT LOCK RPCS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_toggle_seller_suspension(
    p_store_id UUID,
    p_is_suspended BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF auth.uid() IS NULL OR NOT public.is_admin() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Administrator privileges required.');
    END IF;

    UPDATE public.seller_stores
    SET is_suspended = p_is_suspended,
        updated_at = NOW()
    WHERE id = p_store_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Store not found');
    END IF;

    -- If suspended, deactivate listings
    IF p_is_suspended THEN
        UPDATE public.products
        SET is_active = false,
            updated_at = NOW()
        WHERE seller_store_id = p_store_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'is_suspended', p_is_suspended);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_toggle_payout_lock(
    p_store_id UUID,
    p_is_locked BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF auth.uid() IS NULL OR NOT public.is_admin() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Administrator privileges required.');
    END IF;

    UPDATE public.seller_stores
    SET is_payout_locked = p_is_locked,
        updated_at = NOW()
    WHERE id = p_store_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Store not found');
    END IF;

    RETURN jsonb_build_object('success', true, 'is_payout_locked', p_is_locked);
END;
$$;

-- Revoke execution from PUBLIC & anon
REVOKE EXECUTE ON FUNCTION public.seller_request_payout(UUID, NUMERIC, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_process_payout(UUID, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_toggle_seller_suspension(UUID, BOOLEAN) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_toggle_payout_lock(UUID, BOOLEAN) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.seller_request_payout(UUID, NUMERIC, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_process_payout(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_toggle_seller_suspension(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_toggle_payout_lock(UUID, BOOLEAN) TO authenticated;
-- ============================================================================
-- 20260814000000_phase_e_growth_payments_variants.sql
-- PHASE E: GROWTH MIGRATION (M23 to M29)
-- Multi-payment methods, User Wishlists, Variant Selection, Flash Sales & Tracking
-- ============================================================================

-- 1. User Wishlists Table
CREATE TABLE IF NOT EXISTS public.user_wishlists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_product_wishlist UNIQUE (user_id, product_id)
);

ALTER TABLE public.user_wishlists ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own wishlist"
    ON public.user_wishlists FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Users can add to their own wishlist"
    ON public.user_wishlists FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can delete from their own wishlist"
    ON public.user_wishlists FOR DELETE
    TO authenticated
    USING (user_id = auth.uid());

GRANT SELECT, INSERT, DELETE ON public.user_wishlists TO authenticated;

-- 2. Flash Sale Products RPC
CREATE OR REPLACE FUNCTION public.get_flash_sale_products(
    p_limit INT DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    description TEXT,
    price NUMERIC,
    sale_price NUMERIC,
    discount_percentage NUMERIC,
    image_url TEXT,
    category TEXT,
    stock_quantity INT,
    rating NUMERIC
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        p.id,
        p.name,
        p.description,
        p.price,
        p.sale_price,
        ROUND(((p.price - p.sale_price) / p.price) * 100, 0) AS discount_percentage,
        p.image_url,
        p.category,
        p.stock_quantity,
        p.rating
    FROM public.products p
    WHERE p.is_active = TRUE
      AND p.approval_status = 'Approved'
      AND p.sale_price IS NOT NULL
      AND p.sale_price < p.price
    ORDER BY discount_percentage DESC, p.created_at DESC
    LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_flash_sale_products(INT) TO anon, authenticated;

-- 3. Order Tracking Events RPC
CREATE OR REPLACE FUNCTION public.get_order_tracking_events(
    p_order_id TEXT
)
RETURNS TABLE (
    id UUID,
    order_id TEXT,
    status TEXT,
    description TEXT,
    location TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT 
        ote.id,
        ote.order_id,
        ote.event_type AS status,
        ote.description,
        ote.location,
        ote.created_at
    FROM public.order_tracking_events ote
    JOIN public.buyer_orders bo ON bo.id = ote.order_id
    WHERE ote.order_id = p_order_id
      AND (
          bo.customer_user_id = auth.uid()
          OR EXISTS (
              SELECT 1 FROM public.store_fulfillments sf
              JOIN public.seller_stores ss ON ss.id = sf.seller_store_id
              WHERE sf.order_id = p_order_id AND ss.owner_id = auth.uid()
          )
          OR EXISTS (
              SELECT 1 FROM public.user_roles ur
              WHERE ur.user_id = auth.uid()
                AND ur.role IN ('admin', 'super_admin', 'owner')
          )
      )
    ORDER BY ote.created_at ASC;
$$;

GRANT EXECUTE ON FUNCTION public.get_order_tracking_events(TEXT) TO authenticated;

-- 4. Multi-Payment create_atomic_order update
CREATE OR REPLACE FUNCTION public.create_atomic_order(
    p_items JSONB,
    p_shipping_address JSONB,
    p_payment_method TEXT,
    p_idempotency_key TEXT,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_buyer_id UUID;
    v_order_id UUID;
    v_order_number TEXT;
    v_total_amount NUMERIC(12,2) := 0;
    v_shipping_fee NUMERIC(12,2) := 150.00;
    v_grand_total NUMERIC(12,2) := 0;
    v_item RECORD;
    v_product RECORD;
    v_unit_price NUMERIC(12,2);
    v_line_total NUMERIC(12,2);
    v_commission_rate NUMERIC(5,2);
    v_commission_amount NUMERIC(12,2);
    v_seller_earning NUMERIC(12,2);
    v_existing_order JSONB;
BEGIN
    -- Derive verified authenticated user
    v_buyer_id := auth.uid();
    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to create order.';
    END IF;

    -- Validate payment method
    IF p_payment_method NOT IN ('Cash on Delivery', 'JazzCash', 'Easypaisa', 'Debit/Credit Card', 'Card') THEN
        RAISE EXCEPTION 'Unsupported payment method: %', p_payment_method;
    END IF;

    -- Check idempotency
    SELECT jsonb_build_object('order_id', id, 'order_number', order_number, 'status', status)
    INTO v_existing_order
    FROM public.buyer_orders
    WHERE idempotency_key = p_idempotency_key;

    IF v_existing_order IS NOT NULL THEN
        RETURN v_existing_order;
    END IF;

    -- Generate unique order number
    v_order_number := 'ORD-' || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 8));

    -- Insert draft order header
    INSERT INTO public.buyer_orders (
        buyer_id,
        order_number,
        total_amount,
        shipping_fee,
        grand_total,
        status,
        payment_method,
        payment_status,
        shipping_address,
        idempotency_key,
        notes
    ) VALUES (
        v_buyer_id,
        v_order_number,
        0,
        v_shipping_fee,
        v_shipping_fee,
        'Pending',
        p_payment_method,
        CASE WHEN p_payment_method = 'Cash on Delivery' THEN 'Pending' ELSE 'Paid' END,
        p_shipping_address,
        p_idempotency_key,
        p_notes
    ) RETURNING id INTO v_order_id;

    -- Process order line items
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(
        product_id UUID,
        quantity INT,
        variant_id UUID
    )
    LOOP
        -- Lock and verify product
        SELECT id, seller_store_id, price, sale_price, stock_quantity, is_active, approval_status
        INTO v_product
        FROM public.products
        WHERE id = v_item.product_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Product % not found.', v_item.product_id;
        END IF;

        IF NOT v_product.is_active OR v_product.approval_status != 'Approved' THEN
            RAISE EXCEPTION 'Product % is not available for purchase.', v_item.product_id;
        END IF;

        IF v_product.stock_quantity < v_item.quantity THEN
            RAISE EXCEPTION 'Insufficient stock for product %. Available: %, Requested: %',
                v_item.product_id, v_product.stock_quantity, v_item.quantity;
        END IF;

        -- Effective price
        v_unit_price := COALESCE(v_product.sale_price, v_product.price);
        v_line_total := v_unit_price * v_item.quantity;
        v_total_amount := v_total_amount + v_line_total;

        -- Get store commission rate
        SELECT COALESCE(commission_rate, 10.00) INTO v_commission_rate
        FROM public.seller_stores
        WHERE id = v_product.seller_store_id;

        v_commission_amount := ROUND((v_line_total * (v_commission_rate / 100.00)), 2);
        v_seller_earning := v_line_total - v_commission_amount;

        -- Decrement stock
        UPDATE public.products
        SET stock_quantity = stock_quantity - v_item.quantity
        WHERE id = v_product.id;

        -- Insert order item
        INSERT INTO public.order_items (
            order_id,
            product_id,
            seller_store_id,
            quantity,
            unit_price,
            total_price,
            commission_rate,
            commission_amount,
            seller_earning
        ) VALUES (
            v_order_id,
            v_product.id,
            v_product.seller_store_id,
            v_item.quantity,
            v_unit_price,
            v_line_total,
            v_commission_rate,
            v_commission_amount,
            v_seller_earning
        );
    END LOOP;

    -- Update final order totals
    v_grand_total := v_total_amount + v_shipping_fee;

    UPDATE public.buyer_orders
    SET 
        total_amount = v_total_amount,
        grand_total = v_grand_total,
        status = 'Confirmed'
    WHERE id = v_order_id;

    -- Record initial tracking event
    INSERT INTO public.order_tracking_events (
        order_id,
        status,
        description,
        location
    ) VALUES (
        v_order_id,
        'Order Placed',
        'Your order has been placed and payment confirmed via ' || p_payment_method,
        'Apna Store Processing Hub'
    );

    RETURN jsonb_build_object(
        'order_id', v_order_id,
        'order_number', v_order_number,
        'grand_total', v_grand_total,
        'status', 'Confirmed'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_atomic_order(JSONB, JSONB, TEXT, TEXT, TEXT) TO authenticated;

