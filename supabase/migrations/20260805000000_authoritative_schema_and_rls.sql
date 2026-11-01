-- ============================================================================
-- APNA STORE — REVISED AUTHORITATIVE DATABASE SCHEMA, ROLES & RLS POLICIES
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
    ADD COLUMN IF NOT EXISTS phone TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS phone_number TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS mobile_number TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS avatar_url TEXT DEFAULT '';

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role'
    ) THEN
        ALTER TABLE public.profiles ALTER COLUMN role DROP DEFAULT;
        ALTER TABLE public.profiles ALTER COLUMN role TYPE public.app_role USING role::text::public.app_role;
        ALTER TABLE public.profiles ALTER COLUMN role SET DEFAULT 'buyer'::public.app_role;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_cast 
        WHERE castsource = 'public.app_role'::regtype AND casttarget = 'public.user_role'::regtype
    ) THEN
        CREATE CAST (public.app_role AS public.user_role) WITH INOUT AS IMPLICIT;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_cast 
        WHERE castsource = 'public.user_role'::regtype AND casttarget = 'public.app_role'::regtype
    ) THEN
        CREATE CAST (public.user_role AS public.app_role) WITH INOUT AS IMPLICIT;
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

CREATE OR REPLACE FUNCTION public.sync_profile_phone_fields()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.phone IS NOT NULL AND NEW.phone <> '' THEN
        NEW.mobile_number := COALESCE(NULLIF(NEW.mobile_number, ''), NEW.phone);
        NEW.phone_number := COALESCE(NULLIF(NEW.phone_number, ''), NEW.phone);
    ELSIF NEW.mobile_number IS NOT NULL AND NEW.mobile_number <> '' THEN
        NEW.phone := NEW.mobile_number;
        NEW.phone_number := COALESCE(NULLIF(NEW.phone_number, ''), NEW.mobile_number);
    ELSIF NEW.phone_number IS NOT NULL AND NEW.phone_number <> '' THEN
        NEW.phone := NEW.phone_number;
        NEW.mobile_number := COALESCE(NULLIF(NEW.mobile_number, ''), NEW.phone_number);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_profile_phone ON public.profiles;
CREATE TRIGGER trg_sync_profile_phone
BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.sync_profile_phone_fields();

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

ALTER TABLE public.seller_stores ADD COLUMN IF NOT EXISTS name TEXT;

CREATE OR REPLACE FUNCTION public.sync_seller_store_name()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.name IS NOT NULL AND NEW.name <> '' AND (NEW.shop_name IS NULL OR NEW.shop_name = '') THEN
        NEW.shop_name := NEW.name;
    ELSIF NEW.shop_name IS NOT NULL AND NEW.shop_name <> '' AND (NEW.name IS NULL OR NEW.name = '') THEN
        NEW.name := NEW.shop_name;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_seller_store_name ON public.seller_stores;
CREATE TRIGGER trg_sync_seller_store_name
BEFORE INSERT OR UPDATE ON public.seller_stores
FOR EACH ROW EXECUTE FUNCTION public.sync_seller_store_name();

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

ALTER TABLE public.products
    ADD COLUMN IF NOT EXISTS sku TEXT DEFAULT '',
    ADD COLUMN IF NOT EXISTS regular_price NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS slug TEXT DEFAULT '';

CREATE OR REPLACE FUNCTION public.sync_product_price_and_sku()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.regular_price IS NOT NULL AND NEW.price IS NULL THEN
        NEW.price := NEW.regular_price;
    ELSIF NEW.price IS NOT NULL AND NEW.regular_price IS NULL THEN
        NEW.regular_price := NEW.price;
    END IF;
    IF NEW.sku IS NULL OR NEW.sku = '' THEN
        NEW.sku := 'SKU-' || substr(COALESCE(NEW.id::text, gen_random_uuid()::text), 1, 8);
    END IF;
    IF NEW.approval_status IS NOT NULL THEN
        IF lower(NEW.approval_status) = 'approved' THEN
            NEW.approval_status := 'Approved';
        ELSIF lower(NEW.approval_status) IN ('pending', 'pendingreview', 'pending_review') THEN
            NEW.approval_status := 'PendingReview';
        ELSIF lower(NEW.approval_status) = 'draft' THEN
            NEW.approval_status := 'Draft';
        ELSIF lower(NEW.approval_status) = 'rejected' THEN
            NEW.approval_status := 'Rejected';
        ELSIF lower(NEW.approval_status) = 'archived' THEN
            NEW.approval_status := 'Archived';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_product_price_and_sku ON public.products;
CREATE TRIGGER trg_sync_product_price_and_sku
BEFORE INSERT OR UPDATE ON public.products
FOR EACH ROW EXECUTE FUNCTION public.sync_product_price_and_sku();

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

ALTER TABLE public.buyer_orders
    ALTER COLUMN id SET DEFAULT ('ORD-' || substr(gen_random_uuid()::text, 1, 8)),
    ALTER COLUMN customer_name DROP NOT NULL,
    ALTER COLUMN customer_email DROP NOT NULL,
    ALTER COLUMN customer_name SET DEFAULT 'Customer',
    ALTER COLUMN customer_email SET DEFAULT 'customer@example.com';

ALTER TABLE public.buyer_orders
    ADD COLUMN IF NOT EXISTS total_amount NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS grand_total NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS shipping_fee NUMERIC(12,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS voucher_discount NUMERIC(12,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS total_discount NUMERIC(12,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS customer_notes TEXT,
    ADD COLUMN IF NOT EXISTS notes TEXT,
    ADD COLUMN IF NOT EXISTS seller_store_id UUID,
    ADD COLUMN IF NOT EXISTS idempotency_key TEXT,
    ADD COLUMN IF NOT EXISTS order_number TEXT,
    ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'Pending';

CREATE OR REPLACE FUNCTION public.sync_buyer_orders_amounts()
RETURNS TRIGGER AS $$
BEGIN
    NEW.customer_name := COALESCE(NEW.customer_name, 'Customer');
    NEW.customer_email := COALESCE(NEW.customer_email, 'customer@example.com');
    IF NEW.total_amount IS NOT NULL AND (NEW.amount IS NULL OR NEW.amount = 0) THEN
        NEW.amount := NEW.total_amount;
    ELSIF NEW.amount IS NOT NULL AND (NEW.total_amount IS NULL OR NEW.total_amount = 0) THEN
        NEW.total_amount := NEW.amount;
    END IF;
    IF NEW.voucher_discount IS NOT NULL AND (NEW.total_discount IS NULL OR NEW.total_discount = 0) THEN
        NEW.total_discount := NEW.voucher_discount;
    ELSIF NEW.total_discount IS NOT NULL AND (NEW.voucher_discount IS NULL OR NEW.voucher_discount = 0) THEN
        NEW.voucher_discount := NEW.total_discount;
    END IF;
    IF NEW.grand_total IS NULL THEN
        NEW.grand_total := GREATEST(0.00, COALESCE(NEW.total_amount, NEW.amount, 0) - COALESCE(NEW.total_discount, NEW.voucher_discount, 0) + COALESCE(NEW.shipping_fee, 0));
    END IF;
    IF NEW.order_number IS NULL OR NEW.order_number = '' THEN
        NEW.order_number := COALESCE(NEW.id, 'ORD-' || substr(gen_random_uuid()::text, 1, 8));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_buyer_orders_amounts ON public.buyer_orders;
CREATE TRIGGER trg_sync_buyer_orders_amounts
BEFORE INSERT OR UPDATE ON public.buyer_orders
FOR EACH ROW EXECUTE FUNCTION public.sync_buyer_orders_amounts();

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
GRANT INSERT (id, seller_store_id, document_type, document_url, cnic_number, ntn_number, status, submitted_by) ON public.seller_kyc_documents TO authenticated;

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
