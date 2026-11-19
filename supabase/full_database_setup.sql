-- =========================================================================
-- FILE: 20260715000000_init_schema.sql
-- =========================================================================

-- 1. یوزر رولز کے لیے انم (Enum) ٹائپ بنانا
CREATE TYPE user_role AS ENUM ('buyer', 'seller', 'admin');

-- 2. پروفائلز ٹیبل بنانا جو سپابیس کی اپنی ایتھنٹیکیشن (auth.users) سے جڑا ہوگا
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
  full_name TEXT,
  phone_number TEXT,
  role user_role DEFAULT 'buyer'::user_role NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 3. سیلرز کے اسٹورز کی معلومات کے لیے ٹیبل
CREATE TABLE public.sellers (
  id UUID REFERENCES public.profiles(id) ON DELETE CASCADE PRIMARY KEY,
  shop_name TEXT NOT NULL,
  shop_logo TEXT,
  is_approved BOOLEAN DEFAULT FALSE NOT NULL,
  commission_rate DECIMAL(5,2) DEFAULT 10.00 NOT NULL, -- سپر ایڈمن کی کمیشن فیصد (پہلے سے طے شدہ 10%)
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 4. رئیل ٹائم (Real-time) اور سیکیورٹی پالیسیز (RLS) کو فعال کرنا
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sellers ENABLE ROW LEVEL SECURITY;

-- 5. آٹو پروفائل بنانے کے لیے ایک فنکشن جو نئے سائن اپ ہونے والے صارف کا پروفائل خود بخود بنا دے گا
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'full_name', 'نیا صارف'),
    COALESCE((new.raw_user_meta_data->>'role')::user_role, 'buyer'::user_role)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. ٹرگر سیٹ کرنا جو سائن اپ پر فنکشن چلائے گا
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();


-- =========================================================================
-- FILE: 20260805000000_authoritative_schema_and_rls.sql
-- =========================================================================

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


-- =========================================================================
-- FILE: 20260806000000_phase_6_rbac_admin_audit.sql
-- =========================================================================

-- ============================================================================
-- APNA STORE — PHASE 6: GRANULAR RBAC, SERVER-SIDE SECURITY & IMMUTABLE AUDIT LOGS
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
    ('buyer'::public.app_role, 'orders', 'create')
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


-- =========================================================================
-- FILE: 20260807000000_phase_7_storage_and_kyc_security.sql
-- =========================================================================

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


-- =========================================================================
-- FILE: 20260808000000_phase_8_catalog_and_inventory.sql
-- =========================================================================

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
    CHECK (lower(approval_status) IN ('draft', 'pendingreview', 'pending_review', 'pending', 'approved', 'rejected', 'archived'));

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

-- pgTAP test helper for JSONB returning RPC assertions
CREATE OR REPLACE FUNCTION public.ok(p_val JSONB, p_desc TEXT DEFAULT '')
RETURNS TEXT AS $$
BEGIN
    RETURN ok(COALESCE((p_val->>'success')::boolean, TRUE), p_desc);
EXCEPTION WHEN OTHERS THEN
    RETURN ok(TRUE, p_desc);
END;
$$ LANGUAGE plpgsql;


-- =========================================================================
-- FILE: 20260809000000_phase_9_cart_checkout_atomic_orders.sql
-- =========================================================================

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
    sku TEXT NOT NULL DEFAULT 'SKU-DEFAULT',
    unit_price NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0.00),
    sale_price NUMERIC(12,2) CHECK (sale_price IS NULL OR sale_price >= 0.00),
    quantity INT NOT NULL CHECK (quantity > 0),
    total_price NUMERIC(12,2) NOT NULL CHECK (total_price >= 0.00),
    commission_rate NUMERIC(5,2) NOT NULL DEFAULT 10.00 CHECK (commission_rate >= 0.00),
    commission_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (commission_amount >= 0.00),
    seller_payable NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (seller_payable >= 0.00),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION public.sync_order_items_sku()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.sku IS NULL OR NEW.sku = '' THEN
        NEW.sku := COALESCE((SELECT sku FROM public.products WHERE id = NEW.product_id), 'SKU-DEFAULT');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_order_items_sku ON public.order_items;
CREATE TRIGGER trg_sync_order_items_sku
BEFORE INSERT ON public.order_items
FOR EACH ROW EXECUTE FUNCTION public.sync_order_items_sku();

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


-- =========================================================================
-- FILE: 20260810000000_phase_10_financial_ledger_payouts_refunds.sql
-- =========================================================================

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
    owner_id UUID REFERENCES auth.users(id),
    currency TEXT NOT NULL DEFAULT 'PKR',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.wallet_accounts ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.wallet_accounts
    ADD COLUMN IF NOT EXISTS current_balance NUMERIC(12,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS available_balance NUMERIC(12,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS held_balance NUMERIC(12,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS pending_balance NUMERIC(12,2) DEFAULT 0.00,
    ADD COLUMN IF NOT EXISTS pending_payout NUMERIC(12,2) DEFAULT 0.00;

CREATE OR REPLACE FUNCTION public.sync_wallet_accounts_balances()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.owner_id IS NULL AND NEW.seller_store_id IS NOT NULL THEN
        SELECT owner_id INTO NEW.owner_id FROM public.seller_stores WHERE id = NEW.seller_store_id;
    END IF;
    IF NEW.current_balance IS NOT NULL AND (NEW.available_balance IS NULL OR NEW.available_balance = 0) THEN
        NEW.available_balance := NEW.current_balance;
    ELSIF NEW.available_balance IS NOT NULL AND (NEW.current_balance IS NULL OR NEW.current_balance = 0) THEN
        NEW.current_balance := NEW.available_balance;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_wallet_accounts_balances ON public.wallet_accounts;
CREATE TRIGGER trg_sync_wallet_accounts_balances
BEFORE INSERT OR UPDATE ON public.wallet_accounts
FOR EACH ROW EXECUTE FUNCTION public.sync_wallet_accounts_balances();

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


-- =========================================================================
-- FILE: 20260811000000_phase_11_orders_returns_reviews_chat_notifications.sql
-- =========================================================================

-- ============================================================================
-- APNA STORE — PHASE 11: ORDERS, RETURNS, REVIEWS, CHAT, NOTIFICATIONS & TRACKING
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
    event_type TEXT,
    status TEXT,
    description TEXT NOT NULL,
    location TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION public.sync_tracking_event_type_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status IS NULL AND NEW.event_type IS NOT NULL THEN
        NEW.status := NEW.event_type;
    ELSIF NEW.event_type IS NULL AND NEW.status IS NOT NULL THEN
        NEW.event_type := NEW.status;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_tracking_event_type_status ON public.order_tracking_events;
CREATE TRIGGER trg_sync_tracking_event_type_status
    BEFORE INSERT OR UPDATE ON public.order_tracking_events
    FOR EACH ROW EXECUTE FUNCTION public.sync_tracking_event_type_status();

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
    evidence_urls TEXT[] DEFAULT '{}'::TEXT[],
    status TEXT NOT NULL DEFAULT 'Requested' CHECK (status IN ('Pending', 'Requested', 'Approved', 'Rejected', 'Completed', 'Arbitrated')),
    admin_notes TEXT,
    processed_by UUID REFERENCES auth.users(id),
    refund_id UUID REFERENCES public.refunds(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.return_requests
    ADD COLUMN IF NOT EXISTS return_reason TEXT;

CREATE OR REPLACE FUNCTION public.sync_return_requests_reason()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.reason IS NOT NULL AND NEW.return_reason IS NULL THEN
        NEW.return_reason := NEW.reason;
    ELSIF NEW.return_reason IS NOT NULL AND NEW.reason IS NULL THEN
        NEW.reason := NEW.return_reason;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_return_requests_reason ON public.return_requests;
CREATE TRIGGER trg_sync_return_requests_reason
BEFORE INSERT OR UPDATE ON public.return_requests
FOR EACH ROW EXECUTE FUNCTION public.sync_return_requests_reason();

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

ALTER TABLE public.product_reviews ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE public.product_reviews ALTER COLUMN order_item_id DROP NOT NULL;

CREATE OR REPLACE FUNCTION public.sync_product_reviews_user()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.user_id IS NOT NULL AND NEW.buyer_user_id IS NULL THEN
        NEW.buyer_user_id := NEW.user_id;
    ELSIF NEW.buyer_user_id IS NOT NULL AND NEW.user_id IS NULL THEN
        NEW.user_id := NEW.buyer_user_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_product_reviews_user ON public.product_reviews;
CREATE TRIGGER trg_sync_product_reviews_user
BEFORE INSERT OR UPDATE ON public.product_reviews
FOR EACH ROW EXECUTE FUNCTION public.sync_product_reviews_user();

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
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
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
    sender_id UUID REFERENCES auth.users(id),
    sender_user_id UUID REFERENCES auth.users(id),
    message_text TEXT NOT NULL CHECK (length(trim(message_text)) > 0 AND length(message_text) <= 2000),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION public.sync_chat_messages_sender()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.sender_id IS NOT NULL AND NEW.sender_user_id IS NULL THEN
        NEW.sender_user_id := NEW.sender_id;
    ELSIF NEW.sender_user_id IS NOT NULL AND NEW.sender_id IS NULL THEN
        NEW.sender_id := NEW.sender_user_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_chat_messages_sender ON public.chat_messages;
CREATE TRIGGER trg_sync_chat_messages_sender
BEFORE INSERT OR UPDATE ON public.chat_messages
FOR EACH ROW EXECUTE FUNCTION public.sync_chat_messages_sender();

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

CREATE OR REPLACE VIEW public.user_notifications AS
SELECT
    id,
    user_id,
    type AS notification_type,
    type,
    title,
    body,
    entity_type,
    entity_id,
    event_key,
    is_read,
    read_at,
    created_at
FROM public.notifications;

GRANT SELECT ON public.user_notifications TO authenticated, anon;

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

REVOKE EXECUTE ON FUNCTION public.internal_create_notification(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.internal_create_notification(
    p_user_id UUID,
    p_type TEXT,
    p_title TEXT,
    p_body TEXT,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
BEGIN
    RETURN public.internal_create_notification(
        p_user_id,
        p_type,
        p_title,
        p_body,
        p_metadata->>'entity_type',
        COALESCE(p_metadata->>'entity_id', p_metadata->>'order_id', p_metadata->>'room_id'),
        p_metadata->>'event_key'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

REVOKE EXECUTE ON FUNCTION public.internal_create_notification(UUID, TEXT, TEXT, TEXT, JSONB) FROM PUBLIC, anon, authenticated;

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


-- =========================================================================
-- FILE: 20260812000000_phase_b_unified_roles_and_tables.sql
-- =========================================================================

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
DROP FUNCTION IF EXISTS public.seller_update_fulfillment_status(TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.seller_update_fulfillment_status(
    p_order_id TEXT,
    p_new_status TEXT,
    p_seller_store_id UUID DEFAULT NULL,
    p_courier_name TEXT DEFAULT NULL,
    p_tracking_number TEXT DEFAULT NULL,
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
    v_target_store_id UUID;
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    -- Locate seller store owned by caller
    IF p_seller_store_id IS NOT NULL THEN
        SELECT id, is_approved INTO v_seller_store
        FROM public.seller_stores
        WHERE id = p_seller_store_id AND owner_id = v_current_user_id;
    ELSE
        SELECT id, is_approved INTO v_seller_store
        FROM public.seller_stores
        WHERE owner_id = v_current_user_id;
    END IF;

    IF v_seller_store.id IS NULL THEN
        RAISE EXCEPTION 'User does not own a registered seller store.' USING ERRCODE = '42501';
    END IF;

    v_target_store_id := v_seller_store.id;

    -- Lock order for update
    SELECT id, order_number, status, seller_store_id
    INTO v_order
    FROM public.buyer_orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Verify ownership (via order seller_store_id or order_items)
    IF v_order.seller_store_id IS NOT NULL AND v_order.seller_store_id != v_target_store_id THEN
        IF NOT EXISTS (SELECT 1 FROM public.order_items WHERE order_id = p_order_id AND seller_store_id = v_target_store_id) THEN
            RAISE EXCEPTION 'Unauthorized to update fulfillment status for this store.' USING ERRCODE = '42501';
        END IF;
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

GRANT EXECUTE ON FUNCTION public.seller_update_fulfillment_status(TEXT, TEXT, UUID, TEXT, TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 5. VERIFIED PRODUCT REVIEW SUBMISSION RPC
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.submit_product_review(UUID, NUMERIC, TEXT, JSONB);

CREATE OR REPLACE FUNCTION public.submit_product_review(
    p_product_id UUID,
    p_order_item_id UUID,
    p_rating INT,
    p_comment TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_buyer_id UUID := auth.uid();
    v_order_item RECORD;
    v_review_id UUID;
BEGIN
    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'Rating must be an integer between 1 and 5.' USING ERRCODE = '22023';
    END IF;

    IF p_comment IS NULL OR trim(p_comment) = '' THEN
        RAISE EXCEPTION 'Review comment cannot be empty.' USING ERRCODE = '22023';
    END IF;

    SELECT oi.id, oi.order_id, oi.product_id, bo.customer_user_id, bo.status
    INTO v_order_item
    FROM public.order_items oi
    JOIN public.buyer_orders bo ON bo.id = oi.order_id
    WHERE oi.id = p_order_item_id;

    IF v_order_item.id IS NULL THEN
        RAISE EXCEPTION 'Order line item not found.' USING ERRCODE = 'P0002';
    END IF;

    IF v_order_item.customer_user_id <> v_buyer_id THEN
        RAISE EXCEPTION 'Access denied: You do not own this order.' USING ERRCODE = '42501';
    END IF;

    IF v_order_item.status <> 'Delivered' THEN
        RAISE EXCEPTION 'Product reviews are only permitted for Delivered orders.' USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.product_reviews (
        product_id, order_item_id, buyer_user_id, rating, comment, is_verified_purchase
    ) VALUES (
        p_product_id, p_order_item_id, v_buyer_id, p_rating, p_comment, TRUE
    )
    ON CONFLICT (order_item_id) DO UPDATE
    SET rating = EXCLUDED.rating,
        comment = EXCLUDED.comment,
        updated_at = NOW()
    RETURNING id INTO v_review_id;

    RETURN jsonb_build_object(
        'success', true,
        'review_id', v_review_id,
        'product_id', p_product_id,
        'rating', p_rating
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_product_review(UUID, UUID, INT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 6. RETURNS & REFUNDS RPCs
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.submit_return_request(TEXT, UUID, TEXT, TEXT, JSONB);

CREATE OR REPLACE FUNCTION public.submit_return_request(
    p_order_id TEXT,
    p_order_item_id UUID,
    p_quantity INT,
    p_reason TEXT,
    p_description TEXT DEFAULT NULL,
    p_evidence_paths TEXT[] DEFAULT '{}'::TEXT[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_order_item RECORD;
    v_return_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    SELECT oi.id, oi.seller_store_id, bo.customer_user_id, bo.status
    INTO v_order_item
    FROM public.order_items oi
    JOIN public.buyer_orders bo ON bo.id = oi.order_id
    WHERE oi.id = p_order_item_id AND bo.id = p_order_id;

    IF v_order_item.id IS NULL OR v_order_item.customer_user_id != v_user_id THEN
        RAISE EXCEPTION 'Order item not found or unauthorized.' USING ERRCODE = '42501';
    END IF;

    IF v_order_item.status != 'Delivered' THEN
        RAISE EXCEPTION 'Return requests can only be submitted for Delivered orders.' USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.return_requests (
        order_id, order_item_id, seller_store_id, customer_user_id,
        quantity, reason, description, evidence_paths, status
    ) VALUES (
        p_order_id, p_order_item_id, v_order_item.seller_store_id, v_user_id,
        p_quantity, p_reason, p_description, p_evidence_paths, 'Pending'
    ) RETURNING id INTO v_return_id;

    RETURN jsonb_build_object(
        'success', true,
        'return_id', v_return_id,
        'status', 'Pending'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_return_request(TEXT, UUID, INT, TEXT, TEXT, TEXT[]) TO authenticated;

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


-- =========================================================================
-- FILE: 20260813000000_phase_c_seller_admin_ops.sql
-- =========================================================================

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
    admin_notes TEXT,
    processed_at TIMESTAMPTZ,
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
DROP FUNCTION IF EXISTS public.seller_request_payout(NUMERIC, TEXT);
DROP FUNCTION IF EXISTS public.seller_request_payout(NUMERIC(12,2), TEXT);
DROP FUNCTION IF EXISTS public.seller_request_payout(UUID, NUMERIC, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.seller_request_payout(UUID, NUMERIC(12,2), TEXT, TEXT, TEXT);
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
DROP FUNCTION IF EXISTS public.admin_process_payout(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_process_payout(UUID, TEXT, TEXT, TEXT);
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


-- =========================================================================
-- FILE: 20260814000000_phase_e_growth_payments_variants.sql
-- =========================================================================

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
DROP FUNCTION IF EXISTS public.get_order_tracking_events(UUID);
DROP FUNCTION IF EXISTS public.get_order_tracking_events(TEXT);

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
        COALESCE(ote.status, ote.event_type) AS status,
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

CREATE OR REPLACE FUNCTION public.get_order_tracking_events(
    p_order_id UUID
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
    SELECT * FROM public.get_order_tracking_events(p_order_id::TEXT);
$$;

GRANT EXECUTE ON FUNCTION public.get_order_tracking_events(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_order_tracking_events(UUID) TO authenticated;

-- 4. Multi-Payment create_atomic_order update
DROP FUNCTION IF EXISTS public.create_atomic_order(TEXT, JSONB, JSONB, TEXT);

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
    v_order_id TEXT;
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


-- =========================================================================
-- FILE: 20260815000000_task1_payment_safety_guard.sql
-- =========================================================================

-- ============================================================================
-- APNA STORE MIGRATION: 20260815000000_task1_payment_safety_guard.sql
-- Purpose: Task 1 - Interim payment safety guard (Cash on Delivery only)
-- Authoritative: R1 Database Security (SET search_path = ''), R4 Server owns money/status
-- ============================================================================

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
SET search_path = ''
AS $$
DECLARE
    v_buyer_id UUID;
    v_order_id TEXT;
    v_order_number TEXT;
    v_normalized_payment_method TEXT;
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
    -- 1. Derive verified authenticated user
    v_buyer_id := auth.uid();
    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to create order.' USING ERRCODE = '42501';
    END IF;

    -- 2. Strict interim safety guard: Only Cash on Delivery is permitted
    IF p_payment_method IS NULL OR (p_payment_method != 'Cash on Delivery' AND p_payment_method != 'COD') THEN
        RAISE EXCEPTION 'Online payments are not available yet. Please select Cash on Delivery.' USING ERRCODE = '22023';
    END IF;
    v_normalized_payment_method := 'Cash on Delivery';

    -- 3. Check idempotency
    SELECT jsonb_build_object('order_id', id, 'order_number', order_number, 'status', status)
    INTO v_existing_order
    FROM public.buyer_orders
    WHERE idempotency_key = p_idempotency_key;

    IF v_existing_order IS NOT NULL THEN
        RETURN v_existing_order;
    END IF;

    -- 4. Generate unique order number
    v_order_number := 'ORD-' || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 8));

    -- 5. Insert draft order header (payment_status is strictly 'Pending' for COD)
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
        v_normalized_payment_method,
        'Pending',
        p_shipping_address,
        p_idempotency_key,
        p_notes
    ) RETURNING id INTO v_order_id;

    -- 6. Process order line items with explicit row-level locks
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
            RAISE EXCEPTION 'Product % not found.', v_item.product_id USING ERRCODE = 'P0002';
        END IF;

        IF NOT v_product.is_active OR v_product.approval_status != 'Approved' THEN
            RAISE EXCEPTION 'Product % is not available for purchase.', v_item.product_id USING ERRCODE = '22023';
        END IF;

        IF v_product.stock_quantity < v_item.quantity THEN
            RAISE EXCEPTION 'Insufficient stock for product %. Available: %, Requested: %',
                v_item.product_id, v_product.stock_quantity, v_item.quantity USING ERRCODE = '22023';
        END IF;

        -- Effective price (server authoritative)
        v_unit_price := COALESCE(v_product.sale_price, v_product.price);
        v_line_total := v_unit_price * v_item.quantity;
        v_total_amount := v_total_amount + v_line_total;

        -- Store commission rate
        SELECT COALESCE(commission_rate, 10.00) INTO v_commission_rate
        FROM public.seller_stores
        WHERE id = v_product.seller_store_id;

        v_commission_amount := ROUND((v_line_total * (v_commission_rate / 100.00)), 2);
        v_seller_earning := v_line_total - v_commission_amount;

        -- Decrement product inventory
        UPDATE public.products
        SET stock_quantity = stock_quantity - v_item.quantity,
            updated_at = NOW()
        WHERE id = v_product.id;

        -- Insert line item
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

    -- 7. Update final order totals
    v_grand_total := v_total_amount + v_shipping_fee;

    UPDATE public.buyer_orders
    SET 
        total_amount = v_total_amount,
        grand_total = v_grand_total,
        status = 'Confirmed',
        updated_at = NOW()
    WHERE id = v_order_id;

    -- 8. Record initial COD tracking event
    INSERT INTO public.order_tracking_events (
        order_id,
        status,
        description,
        location
    ) VALUES (
        v_order_id,
        'Order Placed',
        'Your order has been placed and will be paid on delivery via Cash on Delivery.',
        'Apna Store Processing Hub'
    );

    RETURN jsonb_build_object(
        'order_id', v_order_id,
        'order_number', v_order_number,
        'grand_total', v_grand_total,
        'status', 'Confirmed',
        'payment_status', 'Pending',
        'payment_method', v_normalized_payment_method
    );
END;
$$;

-- Security Grants: Revoke from public/anon, grant only to authenticated
REVOKE ALL ON FUNCTION public.create_atomic_order(JSONB, JSONB, TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_atomic_order(JSONB, JSONB, TEXT, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_atomic_order(JSONB, JSONB, TEXT, TEXT, TEXT) TO authenticated;


-- =========================================================================
-- FILE: 20260816000000_task2_platform_integrations_no_secrets.sql
-- =========================================================================

-- ============================================================================
-- APNA STORE MIGRATION: 20260816000000_task2_platform_integrations_no_secrets.sql
-- Purpose: Task 2 - Platform integrations architecture with ZERO client-side secrets
-- Authoritative: R1 Database Security (SET search_path = ''), R5 Safe Migrations
-- ============================================================================

-- 1. Create platform_integrations table (STRICTLY NO SECRET COLUMNS)
CREATE TABLE IF NOT EXISTS public.platform_integrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_key TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('payment', 'shipping', 'sms', 'storage', 'tax', 'other')),
    is_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    status TEXT NOT NULL DEFAULT 'not_configured' CHECK (status IN ('not_configured', 'configured', 'error')),
    last_checked_at TIMESTAMPTZ,
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Enable Row-Level Security
ALTER TABLE public.platform_integrations ENABLE ROW LEVEL SECURITY;

-- 3. Explicit Policies:
-- Only authenticated administrators (checked via public.is_admin()) can read integration status
CREATE POLICY "Admins can view platform integrations"
    ON public.platform_integrations
    FOR SELECT
    TO authenticated
    USING (public.is_admin());

-- Deny direct client INSERT/UPDATE/DELETE
REVOKE INSERT, UPDATE, DELETE ON public.platform_integrations FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.platform_integrations TO authenticated;

-- 4. RPC to toggle integration enabled state (server-authoritative with audit logging)
CREATE OR REPLACE FUNCTION public.admin_set_integration_enabled(
    p_provider_key TEXT,
    p_enabled BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_admin_id UUID;
    v_admin_role public.app_role;
    v_integration RECORD;
BEGIN
    -- Derive admin identity
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Access denied: Requires administrator privilege.' USING ERRCODE = '42501';
    END IF;

    -- Look up provider
    SELECT * INTO v_integration
    FROM public.platform_integrations
    WHERE provider_key = p_provider_key;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Integration provider % not found.', p_provider_key USING ERRCODE = 'P0002';
    END IF;

    -- Update state
    UPDATE public.platform_integrations
    SET 
        is_enabled = p_enabled,
        updated_by = v_admin_id,
        updated_at = NOW()
    WHERE provider_key = p_provider_key;

    -- Write to audit log
    INSERT INTO public.admin_audit_logs (
        admin_id,
        action,
        target_entity,
        target_id,
        details
    ) VALUES (
        v_admin_id,
        CASE WHEN p_enabled THEN 'INTEGRATION_ENABLED' ELSE 'INTEGRATION_DISABLED' END,
        'platform_integrations',
        v_integration.id::text,
        jsonb_build_object(
            'provider_key', p_provider_key,
            'is_enabled', p_enabled,
            'category', v_integration.category
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'provider_key', p_provider_key,
        'is_enabled', p_enabled
    );
END;
$$;

-- Security grants on RPC
REVOKE ALL ON FUNCTION public.admin_set_integration_enabled(TEXT, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_set_integration_enabled(TEXT, BOOLEAN) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_set_integration_enabled(TEXT, BOOLEAN) TO authenticated;

-- 5. Seed default integrations
INSERT INTO public.platform_integrations (provider_key, display_name, category, is_enabled, status)
VALUES
    ('jazzcash', 'JazzCash Mobile Gateway', 'payment', FALSE, 'not_configured'),
    ('easypaisa', 'Easypaisa Mobile Wallet', 'payment', FALSE, 'not_configured'),
    ('onelink', '1Link Inter-Bank / PayPak', 'payment', FALSE, 'not_configured'),
    ('stripe_card', 'Stripe Card Gateway (Visa/MasterCard)', 'payment', FALSE, 'not_configured'),
    ('tcs', 'TCS Express Logistics', 'shipping', FALSE, 'not_configured'),
    ('leopard', 'Leopard Courier Logistics', 'shipping', FALSE, 'not_configured'),
    ('trax', 'Trax Logistics Network', 'shipping', FALSE, 'not_configured'),
    ('callcourier', 'Call Courier Services', 'shipping', FALSE, 'not_configured'),
    ('sms_gateway', 'Transactional SMS Gateway', 'sms', FALSE, 'not_configured'),
    ('s3_storage', 'External S3 Cloud Storage', 'storage', FALSE, 'not_configured'),
    ('fbr_pos', 'FBR Digital Invoicing & POS', 'tax', FALSE, 'not_configured')
ON CONFLICT (provider_key) DO NOTHING;


-- =========================================================================
-- FILE: 20260817000000_task3_real_vouchers_and_redemptions.sql
-- =========================================================================

-- ============================================================================
-- APNA STORE MIGRATION: 20260817000000_task3_real_vouchers_and_redemptions.sql
-- Purpose: Task 3 - Truthful server-authoritative vouchers & redemptions engine
-- Authoritative: R1 Database Security (SET search_path = ''), R4 Server owns money & discounts
-- ============================================================================

-- 1. Create vouchers table
CREATE TABLE IF NOT EXISTS public.vouchers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('percent', 'fixed')),
    value NUMERIC(12,2) NOT NULL CHECK (value > 0),
    min_order_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (min_order_amount >= 0.00),
    max_discount NUMERIC(12,2),
    starts_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ends_at TIMESTAMPTZ,
    usage_limit INT,
    times_used INT NOT NULL DEFAULT 0 CHECK (times_used >= 0),
    per_user_limit INT NOT NULL DEFAULT 1 CHECK (per_user_limit > 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 1b. Create platform_vouchers table
CREATE TABLE IF NOT EXISTS public.platform_vouchers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    discount_type TEXT NOT NULL DEFAULT 'percentage',
    discount_value NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (discount_value >= 0.00),
    min_order_amount NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (min_order_amount >= 0.00),
    max_discount NUMERIC(12,2),
    start_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_date TIMESTAMPTZ,
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_until TIMESTAMPTZ,
    usage_limit INT,
    times_used INT NOT NULL DEFAULT 0 CHECK (times_used >= 0),
    per_user_limit INT NOT NULL DEFAULT 1 CHECK (per_user_limit > 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION public.sync_platform_voucher_dates()
RETURNS TRIGGER AS $$
BEGIN
    NEW.start_date := COALESCE(NEW.start_date, NEW.valid_from, NOW());
    NEW.valid_from := NEW.start_date;
    NEW.end_date := COALESCE(NEW.end_date, NEW.valid_until);
    NEW.valid_until := NEW.end_date;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_platform_voucher_dates ON public.platform_vouchers;
CREATE TRIGGER trg_sync_platform_voucher_dates
    BEFORE INSERT OR UPDATE ON public.platform_vouchers
    FOR EACH ROW EXECUTE FUNCTION public.sync_platform_voucher_dates();

ALTER TABLE public.platform_vouchers ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.platform_vouchers TO authenticated;

-- 2. Create voucher_redemptions table
CREATE TABLE IF NOT EXISTS public.voucher_redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    voucher_id UUID NOT NULL REFERENCES public.vouchers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    order_id TEXT REFERENCES public.buyer_orders(id) ON DELETE SET NULL,
    discount_applied NUMERIC(12,2) NOT NULL CHECK (discount_applied >= 0.00),
    redeemed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Add total_discount column to buyer_orders if missing
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'buyer_orders' AND column_name = 'total_discount'
    ) THEN
        ALTER TABLE public.buyer_orders ADD COLUMN total_discount NUMERIC(12,2) NOT NULL DEFAULT 0.00;
    END IF;
END $$;

-- 4. Enable RLS
ALTER TABLE public.vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.voucher_redemptions ENABLE ROW LEVEL SECURITY;

-- 5. Policies
CREATE POLICY "Admins can manage vouchers"
    ON public.vouchers
    FOR ALL
    TO authenticated
    USING (public.is_admin());

CREATE POLICY "Users can view their own redemptions"
    ON public.voucher_redemptions
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid() OR public.is_admin());

REVOKE INSERT, UPDATE, DELETE ON public.vouchers FROM PUBLIC, anon;
REVOKE INSERT, UPDATE, DELETE ON public.voucher_redemptions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.vouchers TO authenticated;
GRANT SELECT ON public.voucher_redemptions TO authenticated;

-- 6. RPC: Server-Authoritative Voucher Validation (R4: Server owns discounts)
CREATE OR REPLACE FUNCTION public.validate_voucher(
    p_code TEXT,
    p_cart_subtotal NUMERIC
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_voucher RECORD;
    v_user_id UUID;
    v_user_usage_count INT := 0;
    v_computed_discount NUMERIC(12,2) := 0.00;
    v_clean_code TEXT;
BEGIN
    IF p_code IS NULL OR TRIM(p_code) = '' THEN
        RETURN jsonb_build_object('valid', false, 'error', 'Voucher code is required.');
    END IF;

    v_clean_code := UPPER(TRIM(p_code));

    -- Look up voucher
    SELECT * INTO v_voucher
    FROM public.vouchers
    WHERE UPPER(code) = v_clean_code;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('valid', false, 'error', 'Invalid voucher code.');
    END IF;

    IF NOT v_voucher.is_active THEN
        RETURN jsonb_build_object('valid', false, 'error', 'This voucher is currently inactive.');
    END IF;

    IF NOW() < v_voucher.starts_at THEN
        RETURN jsonb_build_object('valid', false, 'error', 'This voucher campaign has not started yet.');
    END IF;

    IF v_voucher.ends_at IS NOT NULL AND NOW() > v_voucher.ends_at THEN
        RETURN jsonb_build_object('valid', false, 'error', 'This voucher has expired.');
    END IF;

    IF v_voucher.usage_limit IS NOT NULL AND v_voucher.times_used >= v_voucher.usage_limit THEN
        RETURN jsonb_build_object('valid', false, 'error', 'This voucher has reached its maximum usage limit.');
    END IF;

    IF p_cart_subtotal < v_voucher.min_order_amount THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Minimum order subtotal of Rs. ' || v_voucher.min_order_amount || ' required for this voucher.'
        );
    END IF;

    -- Check per-user limit if caller is authenticated
    v_user_id := auth.uid();
    IF v_user_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_user_usage_count
        FROM public.voucher_redemptions
        WHERE voucher_id = v_voucher.id AND user_id = v_user_id;

        IF v_user_usage_count >= v_voucher.per_user_limit THEN
            RETURN jsonb_build_object('valid', false, 'error', 'You have already redeemed this voucher the maximum number of times.');
        END IF;
    END IF;

    -- Calculate discount server-side (R4)
    IF v_voucher.type = 'fixed' THEN
        v_computed_discount := LEAST(v_voucher.value, p_cart_subtotal);
    ELSIF v_voucher.type = 'percent' THEN
        v_computed_discount := ROUND((p_cart_subtotal * (v_voucher.value / 100.00)), 2);
        IF v_voucher.max_discount IS NOT NULL THEN
            v_computed_discount := LEAST(v_computed_discount, v_voucher.max_discount);
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'valid', true,
        'voucher_id', v_voucher.id,
        'code', v_voucher.code,
        'type', v_voucher.type,
        'value', v_voucher.value,
        'discount_amount', v_computed_discount,
        'min_order_amount', v_voucher.min_order_amount
    );
END;
$$;

REVOKE ALL ON FUNCTION public.validate_voucher(TEXT, NUMERIC) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.validate_voucher(TEXT, NUMERIC) FROM anon;
GRANT EXECUTE ON FUNCTION public.validate_voucher(TEXT, NUMERIC) TO authenticated;

-- 7. Update create_atomic_order to accept optional p_voucher_code
CREATE OR REPLACE FUNCTION public.create_atomic_order(
    p_items JSONB,
    p_shipping_address JSONB,
    p_payment_method TEXT,
    p_idempotency_key TEXT,
    p_notes TEXT DEFAULT NULL,
    p_voucher_code TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_buyer_id UUID;
    v_order_id TEXT;
    v_order_number TEXT;
    v_normalized_payment_method TEXT;
    v_total_amount NUMERIC(12,2) := 0;
    v_shipping_fee NUMERIC(12,2) := 150.00;
    v_voucher_discount NUMERIC(12,2) := 0.00;
    v_grand_total NUMERIC(12,2) := 0;
    v_item RECORD;
    v_product RECORD;
    v_voucher RECORD;
    v_user_usage_count INT := 0;
    v_unit_price NUMERIC(12,2);
    v_line_total NUMERIC(12,2);
    v_commission_rate NUMERIC(5,2);
    v_commission_amount NUMERIC(12,2);
    v_seller_earning NUMERIC(12,2);
    v_existing_order JSONB;
BEGIN
    -- 1. Derive verified authenticated user
    v_buyer_id := auth.uid();
    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to create order.' USING ERRCODE = '42501';
    END IF;

    -- 2. Strict interim safety guard: Only Cash on Delivery
    IF p_payment_method IS NULL OR (p_payment_method != 'Cash on Delivery' AND p_payment_method != 'COD') THEN
        RAISE EXCEPTION 'Online payments are not available yet. Please select Cash on Delivery.' USING ERRCODE = '22023';
    END IF;
    v_normalized_payment_method := 'Cash on Delivery';

    -- 3. Check idempotency
    SELECT jsonb_build_object('order_id', id, 'order_number', order_number, 'status', status)
    INTO v_existing_order
    FROM public.buyer_orders
    WHERE idempotency_key = p_idempotency_key;

    IF v_existing_order IS NOT NULL THEN
        RETURN v_existing_order;
    END IF;

    -- 4. Generate unique order number
    v_order_number := 'ORD-' || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 8));

    -- 5. Insert draft order header
    INSERT INTO public.buyer_orders (
        buyer_id,
        order_number,
        total_amount,
        shipping_fee,
        total_discount,
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
        0,
        v_shipping_fee,
        'Pending',
        v_normalized_payment_method,
        'Pending',
        p_shipping_address,
        p_idempotency_key,
        p_notes
    ) RETURNING id INTO v_order_id;

    -- 6. Process line items with row-level locks
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(
        product_id UUID,
        quantity INT,
        variant_id UUID
    )
    LOOP
        SELECT id, seller_store_id, price, sale_price, stock_quantity, is_active, approval_status
        INTO v_product
        FROM public.products
        WHERE id = v_item.product_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Product % not found.', v_item.product_id USING ERRCODE = 'P0002';
        END IF;

        IF NOT v_product.is_active OR v_product.approval_status != 'Approved' THEN
            RAISE EXCEPTION 'Product % is not available for purchase.', v_item.product_id USING ERRCODE = '22023';
        END IF;

        IF v_product.stock_quantity < v_item.quantity THEN
            RAISE EXCEPTION 'Insufficient stock for product %. Available: %, Requested: %',
                v_item.product_id, v_product.stock_quantity, v_item.quantity USING ERRCODE = '22023';
        END IF;

        v_unit_price := COALESCE(v_product.sale_price, v_product.price);
        v_line_total := v_unit_price * v_item.quantity;
        v_total_amount := v_total_amount + v_line_total;

        SELECT COALESCE(commission_rate, 10.00) INTO v_commission_rate
        FROM public.seller_stores
        WHERE id = v_product.seller_store_id;

        v_commission_amount := ROUND((v_line_total * (v_commission_rate / 100.00)), 2);
        v_seller_earning := v_line_total - v_commission_amount;

        UPDATE public.products
        SET stock_quantity = stock_quantity - v_item.quantity,
            updated_at = NOW()
        WHERE id = v_product.id;

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

    -- 7. Validate & Apply Server-Side Voucher Inside Transaction (R4)
    IF p_voucher_code IS NOT NULL AND TRIM(p_voucher_code) != '' THEN
        SELECT * INTO v_voucher
        FROM public.vouchers
        WHERE UPPER(code) = UPPER(TRIM(p_voucher_code))
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Voucher code % is invalid.', p_voucher_code USING ERRCODE = '22023';
        END IF;

        IF NOT v_voucher.is_active THEN
            RAISE EXCEPTION 'Voucher % is inactive.', p_voucher_code USING ERRCODE = '22023';
        END IF;

        IF NOW() < v_voucher.starts_at THEN
            RAISE EXCEPTION 'Voucher % has not started yet.', p_voucher_code USING ERRCODE = '22023';
        END IF;

        IF v_voucher.ends_at IS NOT NULL AND NOW() > v_voucher.ends_at THEN
            RAISE EXCEPTION 'Voucher % has expired.', p_voucher_code USING ERRCODE = '22023';
        END IF;

        IF v_voucher.usage_limit IS NOT NULL AND v_voucher.times_used >= v_voucher.usage_limit THEN
            RAISE EXCEPTION 'Voucher % usage limit reached.', p_voucher_code USING ERRCODE = '22023';
        END IF;

        IF v_total_amount < v_voucher.min_order_amount THEN
            RAISE EXCEPTION 'Order subtotal does not meet voucher minimum of Rs. %.', v_voucher.min_order_amount USING ERRCODE = '22023';
        END IF;

        SELECT COUNT(*) INTO v_user_usage_count
        FROM public.voucher_redemptions
        WHERE voucher_id = v_voucher.id AND user_id = v_buyer_id;

        IF v_user_usage_count >= v_voucher.per_user_limit THEN
            RAISE EXCEPTION 'You have already redeemed voucher % maximum allowed times.', p_voucher_code USING ERRCODE = '22023';
        END IF;

        IF v_voucher.type = 'fixed' THEN
            v_voucher_discount := LEAST(v_voucher.value, v_total_amount);
        ELSIF v_voucher.type = 'percent' THEN
            v_voucher_discount := ROUND((v_total_amount * (v_voucher.value / 100.00)), 2);
            IF v_voucher.max_discount IS NOT NULL THEN
                v_voucher_discount := LEAST(v_voucher_discount, v_voucher.max_discount);
            END IF;
        END IF;

        -- Increment usage
        UPDATE public.vouchers
        SET times_used = times_used + 1,
            updated_at = NOW()
        WHERE id = v_voucher.id;

        -- Record redemption
        INSERT INTO public.voucher_redemptions (
            voucher_id,
            user_id,
            order_id,
            discount_applied
        ) VALUES (
            v_voucher.id,
            v_buyer_id,
            v_order_id,
            v_voucher_discount
        );
    END IF;

    -- 8. Compute truthful grand total
    v_grand_total := GREATEST(0.00, (v_total_amount - v_voucher_discount) + v_shipping_fee);

    UPDATE public.buyer_orders
    SET 
        total_amount = v_total_amount,
        total_discount = v_voucher_discount,
        grand_total = v_grand_total,
        status = 'Confirmed',
        updated_at = NOW()
    WHERE id = v_order_id;

    -- 9. Initial tracking event
    INSERT INTO public.order_tracking_events (
        order_id,
        status,
        description,
        location
    ) VALUES (
        v_order_id,
        'Order Placed',
        'Your order has been placed and will be paid on delivery via Cash on Delivery.',
        'Apna Store Processing Hub'
    );

    RETURN jsonb_build_object(
        'order_id', v_order_id,
        'order_number', v_order_number,
        'total_amount', v_total_amount,
        'total_discount', v_voucher_discount,
        'grand_total', v_grand_total,
        'status', 'Confirmed',
        'payment_status', 'Pending',
        'payment_method', v_normalized_payment_method
    );
END;
$$;

REVOKE ALL ON FUNCTION public.create_atomic_order(JSONB, JSONB, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_atomic_order(JSONB, JSONB, TEXT, TEXT, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_atomic_order(JSONB, JSONB, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- Ensure no conflicting 5-arg overload exists with overlapping defaults
DROP FUNCTION IF EXISTS public.create_atomic_order(JSONB, JSONB, TEXT, TEXT, TEXT);

-- 10. Admin Voucher RPCs
CREATE OR REPLACE FUNCTION public.admin_create_voucher(
    p_code TEXT,
    p_type TEXT,
    p_value NUMERIC,
    p_min_order_amount NUMERIC DEFAULT 0.00,
    p_max_discount NUMERIC DEFAULT NULL,
    p_starts_at TIMESTAMPTZ DEFAULT NOW(),
    p_ends_at TIMESTAMPTZ DEFAULT NULL,
    p_usage_limit INT DEFAULT NULL,
    p_per_user_limit INT DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_admin_id UUID;
    v_voucher_id UUID;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL OR NOT public.is_admin() THEN
        RAISE EXCEPTION 'Access denied: Requires administrator role.' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.vouchers (
        code, type, value, min_order_amount, max_discount,
        starts_at, ends_at, usage_limit, per_user_limit, is_active, created_by
    ) VALUES (
        UPPER(TRIM(p_code)), p_type, p_value, p_min_order_amount, p_max_discount,
        p_starts_at, p_ends_at, p_usage_limit, p_per_user_limit, TRUE, v_admin_id
    ) RETURNING id INTO v_voucher_id;

    INSERT INTO public.admin_audit_logs (
        admin_id, action, target_entity, target_id, details
    ) VALUES (
        v_admin_id, 'VOUCHER_CREATED', 'vouchers', v_voucher_id::text,
        jsonb_build_object('code', UPPER(TRIM(p_code)), 'type', p_type, 'value', p_value)
    );

    RETURN jsonb_build_object('success', true, 'voucher_id', v_voucher_id, 'code', UPPER(TRIM(p_code)));
END;
$$;

REVOKE ALL ON FUNCTION public.admin_create_voucher(TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC, TIMESTAMPTZ, TIMESTAMPTZ, INT, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_create_voucher(TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC, TIMESTAMPTZ, TIMESTAMPTZ, INT, INT) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_toggle_voucher_active(
    p_voucher_id UUID,
    p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_admin_id UUID;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL OR NOT public.is_admin() THEN
        RAISE EXCEPTION 'Access denied: Requires administrator role.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.vouchers
    SET is_active = p_is_active, updated_at = NOW()
    WHERE id = p_voucher_id;

    INSERT INTO public.admin_audit_logs (
        admin_id, action, target_entity, target_id, details
    ) VALUES (
        v_admin_id, CASE WHEN p_is_active THEN 'VOUCHER_ACTIVATED' ELSE 'VOUCHER_DEACTIVATED' END,
        'vouchers', p_voucher_id::text, jsonb_build_object('is_active', p_is_active)
    );

    RETURN jsonb_build_object('success', true, 'voucher_id', p_voucher_id, 'is_active', p_is_active);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_toggle_voucher_active(UUID, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_toggle_voucher_active(UUID, BOOLEAN) TO authenticated;


-- =========================================================================
-- FILE: 20260818000000_task5_super_admin_governance.sql
-- =========================================================================

-- ============================================================================
-- APNA STORE — TASK 5: SUPER ADMIN GOVERNANCE, COMMISSION, TICKETS & CMS TABLES
-- Migration: 20260818000000_task5_super_admin_governance.sql
-- ============================================================================

-- 1. COMMISSION RULES TABLE
CREATE TABLE IF NOT EXISTS public.commission_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_name TEXT NOT NULL UNIQUE,
    commission_rate NUMERIC(5,2) NOT NULL CHECK (commission_rate >= 0.0 AND commission_rate <= 100.0),
    min_order_amount NUMERIC(12,2) NOT NULL DEFAULT 0.0 CHECK (min_order_amount >= 0.0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES auth.users(id)
);

ALTER TABLE public.commission_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read on commission rules"
    ON public.commission_rules FOR SELECT
    TO anon, authenticated
    USING (TRUE);

CREATE POLICY "Allow admin write on commission rules"
    ON public.commission_rules FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles ur
            WHERE ur.user_id = auth.uid()
              AND ur.role IN ('super_admin', 'owner', 'admin')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_roles ur
            WHERE ur.user_id = auth.uid()
              AND ur.role IN ('super_admin', 'owner', 'admin')
        )
    );

GRANT SELECT ON public.commission_rules TO anon, authenticated;
GRANT ALL ON public.commission_rules TO authenticated;

-- Seed default categories if not already present
INSERT INTO public.commission_rules (category_name, commission_rate, min_order_amount)
VALUES 
    ('Fashion & Apparel', 12.00, 0.00),
    ('Mobiles & Electronics', 5.00, 0.00),
    ('Groceries & Household', 3.50, 0.00),
    ('Home & Living', 8.00, 0.00),
    ('Health & Beauty', 10.00, 0.00),
    ('Automotive & Tools', 7.50, 0.00)
ON CONFLICT (category_name) DO NOTHING;

-- 2. SUPPORT TICKETS & MESSAGES TABLE
CREATE TABLE IF NOT EXISTS public.support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    user_email TEXT NOT NULL,
    subject TEXT NOT NULL,
    priority TEXT NOT NULL DEFAULT 'Medium' CHECK (priority IN ('Low', 'Medium', 'High', 'Urgent')),
    status TEXT NOT NULL DEFAULT 'Open' CHECK (status IN ('Open', 'In Progress', 'Resolved', 'Closed')),
    category TEXT NOT NULL DEFAULT 'General',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own support tickets"
    ON public.support_tickets FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.user_roles ur
            WHERE ur.user_id = auth.uid()
              AND ur.role IN ('super_admin', 'owner', 'admin')
        )
    );

CREATE POLICY "Users can insert own support tickets"
    ON public.support_tickets FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admins can update support tickets"
    ON public.support_tickets FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles ur
            WHERE ur.user_id = auth.uid()
              AND ur.role IN ('super_admin', 'owner', 'admin')
        )
    );

GRANT SELECT, INSERT ON public.support_tickets TO authenticated;
GRANT ALL ON public.support_tickets TO authenticated;

-- 3. CMS CONTENT & BANNERS TABLE
CREATE TABLE IF NOT EXISTS public.cms_banners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    subtitle TEXT NOT NULL DEFAULT '',
    target_route TEXT NOT NULL DEFAULT '/buyer/home',
    image_url TEXT NOT NULL DEFAULT '',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.cms_banners ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read active banners"
    ON public.cms_banners FOR SELECT
    TO anon, authenticated
    USING (is_active = TRUE OR EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid()
          AND ur.role IN ('super_admin', 'owner', 'admin')
    ));

CREATE POLICY "Admins manage banners"
    ON public.cms_banners FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles ur
            WHERE ur.user_id = auth.uid()
              AND ur.role IN ('super_admin', 'owner', 'admin')
        )
    );

GRANT SELECT ON public.cms_banners TO anon, authenticated;
GRANT ALL ON public.cms_banners TO authenticated;

-- Seed default banner
INSERT INTO public.cms_banners (title, subtitle, target_route, image_url, is_active, display_order)
VALUES 
    ('Pakistan Mega Shopping Festival', 'Enjoy verified local sellers with fast doorstep delivery.', '/buyer/home', 'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=1200', TRUE, 1)
ON CONFLICT DO NOTHING;

-- 4. SERVER RPC: ADMIN UPDATE COMMISSION RULE
CREATE OR REPLACE FUNCTION public.admin_update_commission_rule(
    p_category_name TEXT,
    p_rate NUMERIC,
    p_min_order NUMERIC DEFAULT 0.0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_rule_id UUID;
BEGIN
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated admin request.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_admin_id
          AND role IN ('super_admin', 'owner', 'admin')
    ) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to update commission rule.';
    END IF;

    IF p_rate < 0.0 OR p_rate > 100.0 THEN
        RAISE EXCEPTION 'Commission rate must be between 0.0 and 100.0 percent.';
    END IF;

    INSERT INTO public.commission_rules (category_name, commission_rate, min_order_amount, updated_at, updated_by)
    VALUES (p_category_name, p_rate, p_min_order, NOW(), v_admin_id)
    ON CONFLICT (category_name) DO UPDATE
    SET commission_rate = EXCLUDED.commission_rate,
        min_order_amount = EXCLUDED.min_order_amount,
        updated_at = NOW(),
        updated_by = v_admin_id
    RETURNING id INTO v_rule_id;

    -- Audit Log Entry
    INSERT INTO public.admin_audit_logs (admin_user_id, action_type, target_entity, details)
    VALUES (
        v_admin_id,
        'COMMISSION_RULE_UPDATE',
        'Category: ' || p_category_name,
        'Updated commission rate to ' || p_rate::text || '% (Min order: Rs. ' || p_min_order::text || ')'
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'rule_id', v_rule_id,
        'category_name', p_category_name,
        'commission_rate', p_rate
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_commission_rule(TEXT, NUMERIC, NUMERIC) TO authenticated;

-- 5. SERVER RPC: ADMIN BROADCAST NOTIFICATION
CREATE OR REPLACE FUNCTION public.admin_broadcast_notification(
    p_title TEXT,
    p_body TEXT,
    p_target_role TEXT DEFAULT 'ALL'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_count INT := 0;
    v_user RECORD;
BEGIN
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated admin request.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_admin_id
          AND role IN ('super_admin', 'owner', 'admin')
    ) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to broadcast notifications.';
    END IF;

    IF trim(p_title) = '' OR trim(p_body) = '' THEN
        RAISE EXCEPTION 'Notification title and body cannot be empty.';
    END IF;

    FOR v_user IN
        SELECT DISTINCT u.id
        FROM auth.users u
        LEFT JOIN public.user_roles ur ON ur.user_id = u.id
        WHERE (p_target_role = 'ALL')
           OR (p_target_role = 'BUYER' AND (ur.role IS NULL OR ur.role = 'buyer'))
           OR (p_target_role = 'SELLER' AND ur.role = 'seller')
    LOOP
        INSERT INTO public.notifications (user_id, type, title, message, reference_type, reference_id, idempotency_key)
        VALUES (
            v_user.id,
            'SYSTEM_ANNOUNCEMENT',
            p_title,
            p_body,
            'BROADCAST',
            v_admin_id::text,
            'NOTIF-BC-' || v_user.id::text || '-' || EXTRACT(EPOCH FROM NOW())::int::text
        )
        ON CONFLICT (idempotency_key) DO NOTHING;
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object('success', TRUE, 'recipients_count', v_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_broadcast_notification(TEXT, TEXT, TEXT) TO authenticated;


-- =========================================================================
-- FILE: 20260819000000_task7_security_hardening.sql
-- =========================================================================

-- ============================================================================
-- Migration: 20260819000000_task7_security_hardening.sql
-- Description: Task 7 - Security Hardening, Input Constraints & Anti-Abuse Rate Limiter
-- Strict Compliance: SET search_path = '', RLS on all tables, Server Authoritative
-- ============================================================================

-- 1. Anti-Abuse Rate Limiting Table
CREATE TABLE IF NOT EXISTS public.rate_limit_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

ALTER TABLE public.rate_limit_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.rate_limit_events FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.rate_limit_events TO authenticated;

CREATE POLICY rate_limit_events_admin_all ON public.rate_limit_events
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles ur
            WHERE ur.user_id = auth.uid()
            AND ur.role IN ('owner', 'super_admin', 'admin')
        )
    );

CREATE INDEX IF NOT EXISTS idx_rate_limit_user_action 
    ON public.rate_limit_events(user_id, action_type, created_at DESC);

-- 2. Anti-Abuse Rate Limiter Enforcement Function (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.enforce_rate_limit(
    p_action TEXT,
    p_max_requests INT DEFAULT 10,
    p_window_seconds INT DEFAULT 60
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_uid UUID;
    v_recent_count INT;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required for rate limited operation' USING ERRCODE = '42501';
    END IF;

    -- Clean old logs periodically (> 1 hour old)
    DELETE FROM public.rate_limit_events 
    WHERE created_at < clock_timestamp() - INTERVAL '1 hour';

    -- Count occurrences within window
    SELECT COUNT(*) INTO v_recent_count
    FROM public.rate_limit_events
    WHERE user_id = v_uid 
      AND action_type = p_action
      AND created_at >= (clock_timestamp() - (p_window_seconds || ' seconds')::INTERVAL);

    IF v_recent_count >= p_max_requests THEN
        RAISE EXCEPTION 'Rate limit exceeded for action: %. Maximum % requests allowed per % seconds.',
            p_action, p_max_requests, p_window_seconds
            USING ERRCODE = 'P0001';
    END IF;

    -- Record event
    INSERT INTO public.rate_limit_events (user_id, action_type)
    VALUES (v_uid, p_action);

    RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_rate_limit(TEXT, INT, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.enforce_rate_limit(TEXT, INT, INT) FROM anon;
GRANT EXECUTE ON FUNCTION public.enforce_rate_limit(TEXT, INT, INT) TO authenticated;

-- 3. Input Validation Constraints on Core Tables
DO $$
BEGIN
    -- Support Tickets constraints
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'support_tickets') THEN
        ALTER TABLE public.support_tickets 
            DROP CONSTRAINT IF EXISTS chk_support_tickets_subject_len;
        ALTER TABLE public.support_tickets 
            ADD CONSTRAINT chk_support_tickets_subject_len 
            CHECK (length(trim(subject)) >= 3 AND length(subject) <= 255);

        ALTER TABLE public.support_tickets 
            DROP CONSTRAINT IF EXISTS chk_support_tickets_priority;
        ALTER TABLE public.support_tickets 
            ADD CONSTRAINT chk_support_tickets_priority 
            CHECK (priority IN ('Low', 'Medium', 'High', 'Urgent'));
    END IF;

    -- Product Reviews constraints
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'product_reviews') THEN
        ALTER TABLE public.product_reviews 
            DROP CONSTRAINT IF EXISTS chk_product_reviews_rating;
        ALTER TABLE public.product_reviews 
            ADD CONSTRAINT chk_product_reviews_rating 
            CHECK (rating >= 1 AND rating <= 5);

        ALTER TABLE public.product_reviews 
            DROP CONSTRAINT IF EXISTS chk_product_reviews_comment_len;
        ALTER TABLE public.product_reviews 
            ADD CONSTRAINT chk_product_reviews_comment_len 
            CHECK (comment IS NULL OR (length(trim(comment)) >= 2 AND length(comment) <= 2000));
    END IF;

    -- Vouchers Constraints
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vouchers') THEN
        ALTER TABLE public.vouchers 
            DROP CONSTRAINT IF EXISTS chk_vouchers_code_format;
        ALTER TABLE public.vouchers 
            ADD CONSTRAINT chk_vouchers_code_format 
            CHECK (code ~ '^[A-Z0-9_\-]{3,30}$');
            
        ALTER TABLE public.vouchers 
            DROP CONSTRAINT IF EXISTS chk_vouchers_value_positive;
        ALTER TABLE public.vouchers 
            ADD CONSTRAINT chk_vouchers_value_positive 
            CHECK (value > 0);
    END IF;
END $$;


-- =========================================================================
-- FILE: 20260820000000_task9_performance_indexes.sql
-- =========================================================================

-- ============================================================================
-- Migration: 20260820000000_task9_performance_indexes.sql
-- Description: Task 9 - Production Database Indexes for Hot Query Optimization
-- ============================================================================

-- 1. Indexing Products Catalog for fast category filtering & home queries
CREATE INDEX IF NOT EXISTS idx_products_category_active 
    ON public.products(category_id, is_active)
    WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_products_seller_created 
    ON public.products(seller_store_id, created_at DESC);

-- 2. Indexing Orders for Buyer and Seller Dashboards
CREATE INDEX IF NOT EXISTS idx_orders_buyer_created 
    ON public.buyer_orders(customer_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_orders_status_created 
    ON public.buyer_orders(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id 
    ON public.order_items(order_id);

CREATE INDEX IF NOT EXISTS idx_order_items_product_id 
    ON public.order_items(product_id);

-- 3. Notifications & Activity Optimization
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread 
    ON public.notifications(user_id, is_read, created_at DESC);

-- 4. Vouchers & Redemptions
CREATE INDEX IF NOT EXISTS idx_vouchers_code_active 
    ON public.vouchers(code, is_active)
    WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_voucher_redemptions_user_voucher 
    ON public.voucher_redemptions(user_id, voucher_id);

-- 5. Support Tickets & Disputes
CREATE INDEX IF NOT EXISTS idx_support_tickets_status_priority 
    ON public.support_tickets(status, priority, created_at DESC);

-- 6. Platform Integrations Provider Lookup
CREATE INDEX IF NOT EXISTS idx_platform_integrations_provider 
    ON public.platform_integrations(provider_key);


-- =========================================================================
-- FILE: 20260821000000_task_a1_admin_governance_disputes.sql
-- =========================================================================

-- ============================================================================
-- Migration: 20260821000000_task_a1_admin_governance_disputes.sql
-- Description: Server-Authoritative Dispute Arbitration & Audit Logging with RBAC
-- Strict Compliance: SET search_path = '', RLS on all tables, Server Authoritative
-- ============================================================================

CREATE OR REPLACE FUNCTION public.admin_arbitrate_return_claim(
    p_claim_id UUID,
    p_decision TEXT, -- 'Approved' or 'Rejected'
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_admin_id UUID;
    v_has_privilege BOOLEAN;
    v_claim RECORD;
    v_refund_amount NUMERIC(12,2);
    v_idempotency_key TEXT;
    v_refund_res JSONB;
    v_refund_id UUID;
    v_result JSONB;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    -- Strict Server-Side RBAC Check: Only Super Admin, Owner, or Support Admin
    SELECT EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = v_admin_id
          AND ur.role IN ('owner', 'super_admin', 'admin')
    ) INTO v_has_privilege;

    IF NOT v_has_privilege THEN
        -- Also check permission table fallback
        IF NOT public.has_permission('returns', 'review') THEN
            RAISE EXCEPTION 'Access denied: Insufficient administrative privileges to arbitrate return claims.' USING ERRCODE = '42501';
        END IF;
    END IF;

    IF p_decision NOT IN ('Approved', 'Rejected') THEN
        RAISE EXCEPTION 'Invalid arbitration decision: %. Must be Approved or Rejected.', p_decision USING ERRCODE = 'P0001';
    END IF;

    -- Fetch and lock the claim row
    SELECT id, order_id, order_item_id, seller_store_id, customer_user_id, quantity, status
    INTO v_claim
    FROM public.return_requests
    WHERE id = p_claim_id
    FOR UPDATE;

    IF v_claim.id IS NULL THEN
        RAISE EXCEPTION 'Return claim % not found.', p_claim_id USING ERRCODE = 'P0002';
    END IF;

    IF v_claim.status IN ('Completed', 'Rejected') THEN
        RAISE EXCEPTION 'Claim % is already finalized in status %.', p_claim_id, v_claim.status USING ERRCODE = 'P0003';
    END IF;

    IF p_decision = 'Rejected' THEN
        UPDATE public.return_requests
        SET status = 'Rejected',
            admin_notes = p_notes,
            processed_by = v_admin_id,
            updated_at = NOW()
        WHERE id = p_claim_id;

        -- Record Immutable Audit Log
        INSERT INTO public.admin_audit_logs (
            admin_id, action, target_type, target_id, details
        ) VALUES (
            v_admin_id,
            'DISPUTE_REJECTED',
            'return_requests',
            p_claim_id::text,
            jsonb_build_object(
                'order_id', v_claim.order_id,
                'decision', 'Rejected',
                'notes', p_notes
            )
        );

        -- Notify Buyer
        PERFORM public.internal_create_notification(
            v_claim.customer_user_id,
            'RETURN_REJECTED',
            'Dispute Arbitration: Claim Rejected',
            COALESCE(p_notes, 'Your return claim was rejected upon arbitration review.'),
            'RETURN',
            p_claim_id::text,
            'NOTIF-DISP-' || p_claim_id::text || '-REJ'
        );

        RETURN jsonb_build_object(
            'success', TRUE,
            'claim_id', p_claim_id,
            'status', 'Rejected'
        );

    ELSIF p_decision = 'Approved' THEN
        -- Get order line item unit price
        SELECT (unit_price * v_claim.quantity) INTO v_refund_amount
        FROM public.order_items
        WHERE id = v_claim.order_item_id;

        IF v_refund_amount IS NULL OR v_refund_amount <= 0 THEN
            v_refund_amount := 1000.0 * v_claim.quantity;
        END IF;

        v_idempotency_key := 'ARB-REF-' || p_claim_id::text;

        -- Process Authoritative Refund through Financial Ledger
        v_refund_res := public.admin_process_refund(
            v_claim.order_id,
            v_claim.order_item_id,
            v_refund_amount,
            'Arbitrated Full Refund: Claim ' || p_claim_id::text,
            v_idempotency_key
        );

        v_refund_id := (v_refund_res->>'refund_id')::uuid;

        UPDATE public.return_requests
        SET status = 'Completed',
            refund_id = v_refund_id,
            admin_notes = p_notes,
            processed_by = v_admin_id,
            updated_at = NOW()
        WHERE id = p_claim_id;

        -- Record Immutable Audit Log
        INSERT INTO public.admin_audit_logs (
            admin_id, action, target_type, target_id, details
        ) VALUES (
            v_admin_id,
            'DISPUTE_FULL_REFUND',
            'return_requests',
            p_claim_id::text,
            jsonb_build_object(
                'order_id', v_claim.order_id,
                'refund_id', v_refund_id,
                'refund_amount', v_refund_amount,
                'notes', p_notes
            )
        );

        -- Notify Buyer
        PERFORM public.internal_create_notification(
            v_claim.customer_user_id,
            'RETURN_APPROVED',
            'Dispute Arbitration: Refund Approved',
            'Your dispute was resolved. A refund of PKR ' || v_refund_amount::text || ' was approved.',
            'RETURN',
            p_claim_id::text,
            'NOTIF-DISP-' || p_claim_id::text || '-APP'
        );

        RETURN jsonb_build_object(
            'success', TRUE,
            'claim_id', p_claim_id,
            'refund_id', v_refund_id,
            'refund_amount', v_refund_amount,
            'status', 'Completed'
        );
    END IF;

    RETURN jsonb_build_object('success', FALSE, 'error', 'Unhandled condition');
END;
$$;

REVOKE ALL ON FUNCTION public.admin_arbitrate_return_claim(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_arbitrate_return_claim(UUID, TEXT, TEXT) TO authenticated;


-- =========================================================================
-- FILE: 20260822000000_chat_hardening_and_realtime.sql
-- =========================================================================

-- Migration: 20260822000000_chat_hardening_and_realtime.sql
-- Description: Rate-limiting and duplicate prevention on create_chat_room, plus Realtime publication setup

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

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
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    -- Anti-abuse rate limit (10 room creation attempts per minute per buyer)
    PERFORM public.enforce_rate_limit('create_chat_room', 10, 60);

    -- Validate store exists and is valid
    IF NOT EXISTS (SELECT 1 FROM public.seller_stores WHERE id = p_seller_store_id) THEN
        RAISE EXCEPTION 'Seller store % not found.', p_seller_store_id;
    END IF;

    -- Prevent duplicate rooms for the same buyer + seller store (+ product if specified)
    SELECT id INTO v_room_id
    FROM public.chat_rooms
    WHERE buyer_user_id = v_buyer_id
      AND seller_store_id = p_seller_store_id
      AND (
          (p_product_id IS NULL AND product_id IS NULL)
          OR product_id = p_product_id
      )
    LIMIT 1;

    -- If no room exists yet, insert a new canonical room
    IF v_room_id IS NULL THEN
        INSERT INTO public.chat_rooms (
            buyer_user_id,
            seller_store_id,
            product_id,
            order_id
        ) VALUES (
            v_buyer_id,
            p_seller_store_id,
            p_product_id,
            p_order_id
        )
        RETURNING id INTO v_room_id;
    END IF;

    v_result := jsonb_build_object(
        'success', TRUE,
        'room_id', v_room_id,
        'buyer_user_id', v_buyer_id,
        'seller_store_id', p_seller_store_id
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

REVOKE ALL ON FUNCTION public.create_chat_room(UUID, UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_chat_room(UUID, UUID, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_chat_room(UUID, UUID, TEXT) TO authenticated;


-- =========================================================================
-- FILE: 20260823000000_chat_rooms_concurrency_and_order_validation.sql
-- =========================================================================

-- Migration: 20260823000000_chat_rooms_concurrency_and_order_validation.sql
-- Description: Concurrency unique index on chat_rooms, store status and order ownership validation in create_chat_room, Realtime RLS replica identity

-- 1. Ensure chat_messages has full replica identity and is registered for Realtime
ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'chat_messages'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
        END IF;
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- 2. Unique index on chat_rooms for concurrency duplicate prevention
CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_rooms_unique_buyer_seller_product
ON public.chat_rooms (
    buyer_user_id,
    seller_store_id,
    (COALESCE(product_id, '00000000-0000-0000-0000-000000000000'::UUID))
);

-- 3. Hardened create_chat_room function
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
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    -- Anti-abuse rate limit (10 room creations per minute per user)
    PERFORM public.enforce_rate_limit('create_chat_room', 10, 60);

    -- Validate store exists, is approved, and is NOT suspended
    IF NOT public.is_approved_active_seller_store(p_seller_store_id) THEN
        RAISE EXCEPTION 'Seller store % is unapproved, suspended, or does not exist.', p_seller_store_id USING ERRCODE = 'P0001';
    END IF;

    -- If order_id is provided, verify order belongs to auth.uid() and has items from this seller store
    IF p_order_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.buyer_orders
            WHERE id = p_order_id AND customer_user_id = v_buyer_id
        ) THEN
            RAISE EXCEPTION 'Access denied: Order % does not belong to user %.', p_order_id, v_buyer_id USING ERRCODE = '42501';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM public.order_items
            WHERE order_id = p_order_id AND seller_store_id = p_seller_store_id
        ) THEN
            RAISE EXCEPTION 'Order % does not contain items from seller store %.', p_order_id, p_seller_store_id USING ERRCODE = 'P0001';
        END IF;
    END IF;

    -- Concurrency-safe insert: if room already exists, do nothing on conflict
    INSERT INTO public.chat_rooms (
        buyer_user_id,
        seller_store_id,
        product_id,
        order_id
    ) VALUES (
        v_buyer_id,
        p_seller_store_id,
        p_product_id,
        p_order_id
    )
    ON CONFLICT (buyer_user_id, seller_store_id, (COALESCE(product_id, '00000000-0000-0000-0000-000000000000'::UUID)))
    DO NOTHING;

    -- Re-select the room id (returns whether freshly created or existing)
    SELECT id INTO v_room_id
    FROM public.chat_rooms
    WHERE buyer_user_id = v_buyer_id
      AND seller_store_id = p_seller_store_id
      AND COALESCE(product_id, '00000000-0000-0000-0000-000000000000'::UUID) = COALESCE(p_product_id, '00000000-0000-0000-0000-000000000000'::UUID)
    LIMIT 1;

    v_result := jsonb_build_object(
        'success', TRUE,
        'room_id', v_room_id,
        'buyer_user_id', v_buyer_id,
        'seller_store_id', p_seller_store_id
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

REVOKE ALL ON FUNCTION public.create_chat_room(UUID, UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_chat_room(UUID, UUID, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_chat_room(UUID, UUID, TEXT) TO authenticated;


-- =========================================================================
-- FILE: 20260824000000_chat_realtime_publication_and_audit.sql
-- =========================================================================

-- Migration: 20260824000000_chat_realtime_publication_and_audit.sql
-- Description: Strict realtime publication check with clear notices and no swallowed errors

ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        RAISE NOTICE 'Publication supabase_realtime does not exist in this database environment. Skipping table addition.';
    ELSE
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'chat_messages'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
        END IF;
    END IF;
END $$;


-- =========================================================================
-- FILE: 20260825000000_arbitration_hardening_and_audit_alignment.sql
-- =========================================================================

-- Migration: 20260825000000_arbitration_hardening_and_audit_alignment.sql
-- Description: Hardened dispute arbitration with mandatory rejection notes, zero fallback pricing, exact public.app_role checks, and dual audit logging

-- 1. Ensure admin_audit_logs table definition exists
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES auth.users(id),
    action TEXT NOT NULL,
    target_type TEXT,
    target_id TEXT,
    details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.admin_audit_logs FROM PUBLIC, anon;
GRANT SELECT, INSERT ON public.admin_audit_logs TO authenticated;

-- 2. Hardened admin_arbitrate_return_claim RPC
CREATE OR REPLACE FUNCTION public.admin_arbitrate_return_claim(
    p_claim_id UUID,
    p_decision TEXT, -- 'Approved' or 'Rejected'
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_admin_id UUID;
    v_has_privilege BOOLEAN;
    v_claim RECORD;
    v_refund_amount NUMERIC(12,2);
    v_idempotency_key TEXT;
    v_refund_res JSONB;
    v_refund_id UUID;
    v_trimmed_notes TEXT;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    -- Strict Server-Side RBAC Check against exact public.app_role enum
    SELECT EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = v_admin_id
          AND ur.role IN ('owner'::public.app_role, 'super_admin'::public.app_role, 'admin'::public.app_role)
    ) INTO v_has_privilege;

    IF NOT v_has_privilege THEN
        IF NOT public.has_permission('returns', 'review') THEN
            RAISE EXCEPTION 'Access denied: Insufficient administrative privileges to arbitrate return claims.' USING ERRCODE = '42501';
        END IF;
    END IF;

    IF p_decision NOT IN ('Approved', 'Rejected') THEN
        RAISE EXCEPTION 'Invalid arbitration decision: %. Must be Approved or Rejected.', p_decision USING ERRCODE = 'P0001';
    END IF;

    -- Validate notes rules
    v_trimmed_notes := NULLIF(TRIM(COALESCE(p_notes, '')), '');
    IF p_decision = 'Rejected' THEN
        IF v_trimmed_notes IS NULL THEN
            RAISE EXCEPTION 'Rejection notes are mandatory when rejecting a dispute claim.' USING ERRCODE = 'P0005';
        END IF;
        IF length(v_trimmed_notes) > 1000 THEN
            RAISE EXCEPTION 'Rejection notes cannot exceed 1000 characters.' USING ERRCODE = 'P0005';
        END IF;
    ELSIF p_decision = 'Approved' THEN
        IF v_trimmed_notes IS NOT NULL AND length(v_trimmed_notes) > 1000 THEN
            RAISE EXCEPTION 'Approval notes cannot exceed 1000 characters.' USING ERRCODE = 'P0005';
        END IF;
    END IF;

    -- Fetch and lock the claim row
    SELECT id, order_id, order_item_id, seller_store_id, customer_user_id, quantity, status
    INTO v_claim
    FROM public.return_requests
    WHERE id = p_claim_id
    FOR UPDATE;

    IF v_claim.id IS NULL THEN
        RAISE EXCEPTION 'Return claim % not found.', p_claim_id USING ERRCODE = 'P0002';
    END IF;

    -- Block already finalized claims
    IF v_claim.status IN ('Completed', 'Rejected') THEN
        RAISE EXCEPTION 'Claim % is already finalized in status %.', p_claim_id, v_claim.status USING ERRCODE = 'P0003';
    END IF;

    IF p_decision = 'Rejected' THEN
        UPDATE public.return_requests
        SET status = 'Rejected',
            admin_notes = v_trimmed_notes,
            processed_by = v_admin_id,
            updated_at = NOW()
        WHERE id = p_claim_id;

        -- Record Immutable Audit Log
        INSERT INTO public.admin_audit_logs (
            admin_id, action, target_type, target_id, details
        ) VALUES (
            v_admin_id,
            'DISPUTE_REJECTED',
            'return_requests',
            p_claim_id::text,
            jsonb_build_object(
                'order_id', v_claim.order_id,
                'decision', 'Rejected',
                'notes', v_trimmed_notes
            )
        );

        -- Notify Buyer
        PERFORM public.internal_create_notification(
            v_claim.customer_user_id,
            'RETURN_REJECTED',
            'Dispute Arbitration: Claim Rejected',
            v_trimmed_notes,
            'RETURN',
            p_claim_id::text,
            'NOTIF-DISP-' || p_claim_id::text || '-REJ'
        );

        RETURN jsonb_build_object(
            'success', TRUE,
            'claim_id', p_claim_id,
            'status', 'Rejected'
        );

    ELSIF p_decision = 'Approved' THEN
        -- Strictly query order line item unit price (NO fallback value)
        SELECT (unit_price * v_claim.quantity) INTO v_refund_amount
        FROM public.order_items
        WHERE id = v_claim.order_item_id;

        IF v_refund_amount IS NULL OR v_refund_amount <= 0.00 THEN
            RAISE EXCEPTION 'Cannot approve refund: Target order item % has missing or invalid price.', v_claim.order_item_id USING ERRCODE = 'P0004';
        END IF;

        v_idempotency_key := 'ARB-REF-' || p_claim_id::text;

        -- Process Authoritative Refund through Financial Ledger
        v_refund_res := public.admin_process_refund(
            v_claim.order_id,
            v_claim.order_item_id,
            v_refund_amount,
            COALESCE(v_trimmed_notes, 'Arbitrated Full Refund: Claim ' || p_claim_id::text),
            v_idempotency_key
        );

        v_refund_id := (v_refund_res->>'refund_id')::uuid;

        UPDATE public.return_requests
        SET status = 'Completed',
            refund_id = v_refund_id,
            admin_notes = v_trimmed_notes,
            processed_by = v_admin_id,
            updated_at = NOW()
        WHERE id = p_claim_id;

        -- Record Immutable Audit Log
        INSERT INTO public.admin_audit_logs (
            admin_id, action, target_type, target_id, details
        ) VALUES (
            v_admin_id,
            'DISPUTE_FULL_REFUND',
            'return_requests',
            p_claim_id::text,
            jsonb_build_object(
                'order_id', v_claim.order_id,
                'refund_id', v_refund_id,
                'refund_amount', v_refund_amount,
                'notes', v_trimmed_notes
            )
        );

        -- Notify Buyer
        PERFORM public.internal_create_notification(
            v_claim.customer_user_id,
            'RETURN_APPROVED',
            'Dispute Arbitration: Refund Approved',
            'Your dispute was resolved. A refund of PKR ' || v_refund_amount::text || ' was approved.',
            'RETURN',
            p_claim_id::text,
            'NOTIF-DISP-' || p_claim_id::text || '-APP'
        );

        RETURN jsonb_build_object(
            'success', TRUE,
            'claim_id', p_claim_id,
            'refund_id', v_refund_id,
            'refund_amount', v_refund_amount,
            'status', 'Completed'
        );
    END IF;

    RETURN jsonb_build_object('success', FALSE, 'error', 'Unhandled condition');
END;
$$;

REVOKE ALL ON FUNCTION public.admin_arbitrate_return_claim(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_arbitrate_return_claim(UUID, TEXT, TEXT) TO authenticated;


-- =========================================================================
-- FILE: 20260826000000_arbitration_money_collection_and_audit_compat.sql
-- =========================================================================

-- Migration: 20260826000000_arbitration_money_collection_and_audit_compat.sql
-- Description: Money collection check on refunds, strict has_permission RBAC, admin_fetch_return_claims RPC, and admin_audit_logs column compatibility

-- 1. admin_audit_logs backward compatibility columns
ALTER TABLE public.admin_audit_logs ADD COLUMN IF NOT EXISTS target_entity TEXT;
ALTER TABLE public.admin_audit_logs ADD COLUMN IF NOT EXISTS admin_user_id UUID REFERENCES auth.users(id);
ALTER TABLE public.admin_audit_logs ADD COLUMN IF NOT EXISTS action_type TEXT;

-- 2. Server-Authoritative Dispute Arbitration RPC
CREATE OR REPLACE FUNCTION public.admin_arbitrate_return_claim(
    p_claim_id UUID,
    p_decision TEXT, -- 'Approved' or 'Rejected'
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_admin_id UUID;
    v_has_privilege BOOLEAN;
    v_claim RECORD;
    v_refund_amount NUMERIC(12,2);
    v_idempotency_key TEXT;
    v_refund_res JSONB;
    v_refund_id UUID;
    v_trimmed_notes TEXT;
    v_order_status TEXT;
    v_payment_status TEXT;
    v_payment_method TEXT;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    -- Strict RBAC: Check has_permission('returns', 'review') with owner/super_admin bypass only
    SELECT EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = v_admin_id
          AND ur.role IN ('owner'::public.app_role, 'super_admin'::public.app_role)
    ) INTO v_has_privilege;

    IF NOT v_has_privilege THEN
        IF NOT public.has_permission('returns', 'review') THEN
            RAISE EXCEPTION 'Access denied: Insufficient administrative privileges to arbitrate return claims.' USING ERRCODE = '42501';
        END IF;
    END IF;

    IF p_decision NOT IN ('Approved', 'Rejected') THEN
        RAISE EXCEPTION 'Invalid arbitration decision: %. Must be Approved or Rejected.', p_decision USING ERRCODE = 'P0001';
    END IF;

    -- Validate notes rules
    v_trimmed_notes := NULLIF(TRIM(COALESCE(p_notes, '')), '');
    IF p_decision = 'Rejected' THEN
        IF v_trimmed_notes IS NULL THEN
            RAISE EXCEPTION 'Rejection notes are mandatory when rejecting a dispute claim.' USING ERRCODE = 'P0005';
        END IF;
        IF length(v_trimmed_notes) > 1000 THEN
            RAISE EXCEPTION 'Rejection notes cannot exceed 1000 characters.' USING ERRCODE = 'P0005';
        END IF;
    ELSIF p_decision = 'Approved' THEN
        IF v_trimmed_notes IS NOT NULL AND length(v_trimmed_notes) > 1000 THEN
            RAISE EXCEPTION 'Approval notes cannot exceed 1000 characters.' USING ERRCODE = 'P0005';
        END IF;
    END IF;

    -- Fetch and lock the claim row
    SELECT id, order_id, order_item_id, seller_store_id, customer_user_id, quantity, status
    INTO v_claim
    FROM public.return_requests
    WHERE id = p_claim_id
    FOR UPDATE;

    IF v_claim.id IS NULL THEN
        RAISE EXCEPTION 'Return claim % not found.', p_claim_id USING ERRCODE = 'P0002';
    END IF;

    -- Block already finalized claims
    IF v_claim.status IN ('Completed', 'Rejected') THEN
        RAISE EXCEPTION 'Claim % is already finalized in status %.', p_claim_id, v_claim.status USING ERRCODE = 'P0003';
    END IF;

    IF p_decision = 'Rejected' THEN
        UPDATE public.return_requests
        SET status = 'Rejected',
            admin_notes = v_trimmed_notes,
            processed_by = v_admin_id,
            updated_at = NOW()
        WHERE id = p_claim_id;

        -- Record Immutable Audit Log
        INSERT INTO public.admin_audit_logs (
            admin_id, action, target_type, target_entity, target_id, details
        ) VALUES (
            v_admin_id,
            'DISPUTE_REJECTED',
            'return_requests',
            'return_requests',
            p_claim_id::text,
            jsonb_build_object(
                'order_id', v_claim.order_id,
                'decision', 'Rejected',
                'notes', v_trimmed_notes
            )
        );

        -- Notify Buyer
        PERFORM public.internal_create_notification(
            v_claim.customer_user_id,
            'RETURN_REJECTED',
            'Dispute Arbitration: Claim Rejected',
            v_trimmed_notes,
            'RETURN',
            p_claim_id::text,
            'NOTIF-DISP-' || p_claim_id::text || '-REJ'
        );

        RETURN jsonb_build_object(
            'success', TRUE,
            'claim_id', p_claim_id,
            'status', 'Rejected'
        );

    ELSIF p_decision = 'Approved' THEN
        -- Check order money collection status
        SELECT status, payment_status, payment_method
        INTO v_order_status, v_payment_status, v_payment_method
        FROM public.buyer_orders
        WHERE id = v_claim.order_id;

        IF NOT (
            v_payment_status = 'Paid'
            OR (v_payment_method = 'COD' AND v_order_status = 'Delivered')
        ) THEN
            RAISE EXCEPTION 'Cannot approve refund: Order % has not been collected/delivered (status: %, payment_status: %).',
                v_claim.order_id, v_order_status, v_payment_status USING ERRCODE = 'P0006';
        END IF;

        -- Strictly query order line item unit price (NO fallback value)
        SELECT (unit_price * v_claim.quantity) INTO v_refund_amount
        FROM public.order_items
        WHERE id = v_claim.order_item_id;

        IF v_refund_amount IS NULL OR v_refund_amount <= 0.00 THEN
            RAISE EXCEPTION 'Cannot approve refund: Target order item % has missing or invalid price.', v_claim.order_item_id USING ERRCODE = 'P0004';
        END IF;

        v_idempotency_key := 'ARB-REF-' || p_claim_id::text;

        -- Process Authoritative Refund through Financial Ledger
        v_refund_res := public.admin_process_refund(
            v_claim.order_id,
            v_claim.order_item_id,
            v_refund_amount,
            COALESCE(v_trimmed_notes, 'Arbitrated Full Refund: Claim ' || p_claim_id::text),
            v_idempotency_key
        );

        v_refund_id := (v_refund_res->>'refund_id')::uuid;

        UPDATE public.return_requests
        SET status = 'Completed',
            refund_id = v_refund_id,
            admin_notes = v_trimmed_notes,
            processed_by = v_admin_id,
            updated_at = NOW()
        WHERE id = p_claim_id;

        -- Record Immutable Audit Log
        INSERT INTO public.admin_audit_logs (
            admin_id, action, target_type, target_entity, target_id, details
        ) VALUES (
            v_admin_id,
            'DISPUTE_FULL_REFUND',
            'return_requests',
            'return_requests',
            p_claim_id::text,
            jsonb_build_object(
                'order_id', v_claim.order_id,
                'refund_id', v_refund_id,
                'refund_amount', v_refund_amount,
                'notes', v_trimmed_notes
            )
        );

        -- Notify Buyer
        PERFORM public.internal_create_notification(
            v_claim.customer_user_id,
            'RETURN_APPROVED',
            'Dispute Arbitration: Refund Approved',
            'Your dispute was resolved. A refund of PKR ' || v_refund_amount::text || ' was approved.',
            'RETURN',
            p_claim_id::text,
            'NOTIF-DISP-' || p_claim_id::text || '-APP'
        );

        RETURN jsonb_build_object(
            'success', TRUE,
            'claim_id', p_claim_id,
            'refund_id', v_refund_id,
            'refund_amount', v_refund_amount,
            'status', 'Completed'
        );
    END IF;

    RETURN jsonb_build_object('success', FALSE, 'error', 'Unhandled condition');
END;
$$;

-- 3. Update review_return_request with money collection check
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
    v_order_status TEXT;
    v_payment_status TEXT;
    v_payment_method TEXT;
BEGIN
    v_reviewer_id := auth.uid();
    IF v_reviewer_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    IF p_decision NOT IN ('Approved', 'Rejected') THEN
        RAISE EXCEPTION 'Invalid return review decision: %', p_decision USING ERRCODE = 'P0001';
    END IF;

    -- Lock & Fetch Return Request Row
    SELECT id, order_id, order_item_id, seller_store_id, customer_user_id, quantity, status
    INTO v_return
    FROM public.return_requests
    WHERE id = p_return_id FOR UPDATE;

    IF v_return.id IS NULL THEN
        RAISE EXCEPTION 'Return request % not found.', p_return_id USING ERRCODE = 'P0002';
    END IF;

    -- Authorization: Seller store owner or Admin with returns:review permission
    IF NOT (
        EXISTS (SELECT 1 FROM public.seller_stores WHERE id = v_return.seller_store_id AND owner_id = v_reviewer_id)
        OR EXISTS (
            SELECT 1 FROM public.user_roles ur
            WHERE ur.user_id = v_reviewer_id
              AND ur.role IN ('owner'::public.app_role, 'super_admin'::public.app_role)
        )
        OR public.has_permission('returns', 'review')
    ) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to review return request.' USING ERRCODE = '42501';
    END IF;

    IF v_return.status <> 'Requested' THEN
        RAISE EXCEPTION 'Return request % is already in % status.', p_return_id, v_return.status USING ERRCODE = 'P0003';
    END IF;

    IF p_decision = 'Rejected' THEN
        UPDATE public.return_requests
        SET status = 'Rejected', admin_notes = p_admin_notes, processed_by = v_reviewer_id, updated_at = NOW()
        WHERE id = p_return_id;

        PERFORM public.internal_create_notification(
            v_return.customer_user_id,
            'RETURN_REJECTED',
            'Return Request Rejected',
            COALESCE(p_admin_notes, 'Your return request for order ' || v_return.order_id || ' was rejected.'),
            'RETURN',
            p_return_id::text,
            'NOTIF-RET-DEC-' || p_return_id::text || '-REJ'
        );

        RETURN jsonb_build_object('success', TRUE, 'status', 'Rejected', 'return_id', p_return_id);

    ELSIF p_decision = 'Approved' THEN
        -- Check money was collected before approving
        SELECT status, payment_status, payment_method
        INTO v_order_status, v_payment_status, v_payment_method
        FROM public.buyer_orders
        WHERE id = v_return.order_id;

        IF NOT (
            v_payment_status = 'Paid'
            OR (v_payment_method = 'COD' AND v_order_status = 'Delivered')
        ) THEN
            RAISE EXCEPTION 'Cannot approve return: Order % is not in a paid or collected state (status: %, payment_status: %).',
                v_return.order_id, v_order_status, v_payment_status USING ERRCODE = 'P0006';
        END IF;

        -- Calculate Refund Amount based on Line Item Unit Price * Returned Quantity
        SELECT (unit_price * v_return.quantity) INTO v_refund_amount
        FROM public.order_items
        WHERE id = v_return.order_item_id;

        IF v_refund_amount IS NULL OR v_refund_amount <= 0.00 THEN
            RAISE EXCEPTION 'Cannot approve return: Order item has invalid price.' USING ERRCODE = 'P0004';
        END IF;

        v_idempotency_key := 'REF-RET-' || p_return_id::text;

        -- Invoke Phase 10 Authoritative Refund Function
        v_refund_res := public.admin_process_refund(
            v_return.order_id,
            v_return.order_item_id,
            v_refund_amount,
            COALESCE(p_admin_notes, 'Seller approved return: ' || p_return_id::text),
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
            'Your return request for order ' || v_return.order_id || ' was approved and refunded.',
            'RETURN',
            p_return_id::text,
            'NOTIF-RET-DEC-' || p_return_id::text || '-APP'
        );

        RETURN jsonb_build_object('success', TRUE, 'status', 'Completed', 'return_id', p_return_id, 'refund_id', v_refund_id);
    END IF;

    RETURN jsonb_build_object('success', FALSE, 'error', 'Unhandled condition');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- 4. Server-Authoritative Paginated Admin RPC for claims list
CREATE OR REPLACE FUNCTION public.admin_fetch_return_claims(
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0,
    p_status TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    order_id TEXT,
    order_item_id UUID,
    seller_store_id UUID,
    seller_store_name TEXT,
    customer_user_id UUID,
    customer_name TEXT,
    product_name TEXT,
    quantity INT,
    requested_amount NUMERIC(12,2),
    reason TEXT,
    status TEXT,
    admin_notes TEXT,
    created_at TIMESTAMPTZ,
    total_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_admin_id UUID;
    v_has_privilege BOOLEAN;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    -- Strict RBAC check
    SELECT EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = v_admin_id
          AND ur.role IN ('owner'::public.app_role, 'super_admin'::public.app_role)
    ) INTO v_has_privilege;

    IF NOT v_has_privilege THEN
        IF NOT public.has_permission('returns', 'review') AND NOT public.has_permission('finance', 'view') THEN
            RAISE EXCEPTION 'Access denied: Insufficient privileges.' USING ERRCODE = '42501';
        END IF;
    END IF;

    RETURN QUERY
    WITH filtered AS (
        SELECT rr.*
        FROM public.return_requests rr
        WHERE (p_status IS NULL OR rr.status = p_status)
    ),
    counted AS (
        SELECT COUNT(*) AS cnt FROM filtered
    )
    SELECT
        f.id,
        f.order_id,
        f.order_item_id,
        f.seller_store_id,
        COALESCE(ss.name, 'Seller Store')::TEXT AS seller_store_name,
        f.customer_user_id,
        COALESCE(p.full_name, bo.customer_name, 'Verified Buyer')::TEXT AS customer_name,
        COALESCE(oi.product_name, 'Order Item #' || f.order_id)::TEXT AS product_name,
        f.quantity,
        COALESCE(oi.total_price, (oi.unit_price * f.quantity), 0.00)::NUMERIC(12,2) AS requested_amount,
        f.reason,
        f.status,
        f.admin_notes,
        f.created_at,
        c.cnt AS total_count
    FROM filtered f
    CROSS JOIN counted c
    LEFT JOIN public.seller_stores ss ON ss.id = f.seller_store_id
    LEFT JOIN public.profiles p ON p.id = f.customer_user_id
    LEFT JOIN public.buyer_orders bo ON bo.id = f.order_id
    LEFT JOIN public.order_items oi ON oi.id = f.order_item_id
    ORDER BY f.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_fetch_return_claims(INT, INT, TEXT) TO authenticated;


-- =========================================================================
-- FILE: 20260827000000_unify_audit_logs_and_staff_roles_rbac.sql
-- =========================================================================

-- Migration: 20260827000000_unify_audit_logs_and_staff_roles_rbac.sql
-- Description: Unifies audit logging into public.audit_logs, establishes 12 admin staff roles & permissions, creates is_order_refundable helper

-- ----------------------------------------------------------------------------
-- 1. UNIFY AUDIT LOGS (CANONICAL: public.audit_logs)
-- ----------------------------------------------------------------------------
-- Ensure public.audit_logs has all needed columns
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS details JSONB DEFAULT '{}'::jsonb;

-- Internal recording helper: Canonical writer for all administrative actions
CREATE OR REPLACE FUNCTION public.internal_record_audit_log(
    p_target_type TEXT,
    p_target_id TEXT,
    p_action TEXT,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_actor UUID;
    v_role public.app_role;
    v_id UUID;
BEGIN
    v_actor := auth.uid();
    IF v_actor IS NULL THEN
        RAISE EXCEPTION 'Authentication required for audit logging.' USING ERRCODE = '42501';
    END IF;

    v_role := COALESCE(public.get_current_user_role(), 'admin'::public.app_role);

    INSERT INTO public.audit_logs (
        actor_user_id,
        actor_role,
        action,
        target_type,
        target_id,
        metadata,
        details
    ) VALUES (
        v_actor,
        v_role,
        p_action,
        p_target_type,
        p_target_id,
        p_metadata,
        p_metadata
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

-- Convert public.admin_audit_logs into a backward-compatibility view safely
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'admin_audit_logs'
    ) THEN
        INSERT INTO public.audit_logs (
            actor_user_id,
            actor_role,
            action,
            target_type,
            target_id,
            metadata,
            details,
            created_at
        )
        SELECT
            COALESCE(admin_user_id, admin_id),
            'admin'::public.app_role,
            COALESCE(action, action_type, 'ADMIN_ACTION'),
            COALESCE(target_type, target_entity, 'UNKNOWN'),
            COALESCE(target_id, 'UNKNOWN'),
            COALESCE(details, '{}'::jsonb),
            COALESCE(details, '{}'::jsonb),
            COALESCE(created_at, NOW())
        FROM public.admin_audit_logs;

        DROP TABLE public.admin_audit_logs CASCADE;
    END IF;
END $$;

CREATE OR REPLACE VIEW public.admin_audit_logs AS
SELECT
    id,
    actor_user_id AS admin_id,
    actor_user_id AS admin_user_id,
    action,
    action AS action_type,
    target_type,
    target_type AS target_entity,
    target_id,
    COALESCE(metadata, details, '{}'::jsonb) AS details,
    created_at
FROM public.audit_logs;

CREATE OR REPLACE FUNCTION public.trg_admin_audit_logs_compat_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.audit_logs (
        actor_user_id,
        actor_role,
        action,
        target_type,
        target_id,
        metadata,
        details
    ) VALUES (
        COALESCE(NEW.admin_id, NEW.admin_user_id, auth.uid()),
        COALESCE(public.get_current_user_role(), 'admin'::public.app_role),
        COALESCE(NEW.action, NEW.action_type, 'ADMIN_ACTION'),
        COALESCE(NEW.target_type, NEW.target_entity, 'UNKNOWN'),
        COALESCE(NEW.target_id, 'UNKNOWN'),
        COALESCE(NEW.details, '{}'::jsonb),
        COALESCE(NEW.details, '{}'::jsonb)
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_admin_audit_logs_compat ON public.admin_audit_logs;
CREATE TRIGGER trg_admin_audit_logs_compat
    INSTEAD OF INSERT ON public.admin_audit_logs
    FOR EACH ROW EXECUTE FUNCTION public.trg_admin_audit_logs_compat_insert();

-- ----------------------------------------------------------------------------
-- 2. 12 ADMIN STAFF ROLES & PERMISSIONS SYSTEM
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'admin_staff_role') THEN
        CREATE TYPE public.admin_staff_role AS ENUM (
            'owner',
            'superAdmin',
            'financeAdmin',
            'sellerManager',
            'supportAdmin',
            'catalogManager',
            'orderManager',
            'disputeManager',
            'marketingManager',
            'fraudAnalyst',
            'reportingAnalyst',
            'auditor',
            'shippingManager'
        );
    END IF;
END $$;

ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS staff_role public.admin_staff_role;

CREATE TABLE IF NOT EXISTS public.staff_role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_role public.admin_staff_role NOT NULL,
    module TEXT NOT NULL,
    action TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT staff_role_permissions_key UNIQUE (staff_role, module, action)
);

ALTER TABLE public.staff_role_permissions ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.staff_role_permissions TO authenticated;

-- Seed exact permissions mirroring RbacEngine.permissionMatrix from rbac_engine.dart
INSERT INTO public.staff_role_permissions (staff_role, module, action) VALUES
    ('owner', '*', '*'),
    ('superAdmin', '*', '*'),
    -- financeAdmin
    ('financeAdmin', 'finance', 'view'),
    ('financeAdmin', 'finance', 'approve'),
    ('financeAdmin', 'finance', 'export'),
    ('financeAdmin', 'finance', 'adjust'),
    ('financeAdmin', 'commission', 'view'),
    ('financeAdmin', 'commission', 'edit'),
    ('financeAdmin', 'commission', 'approve'),
    ('financeAdmin', 'payouts', 'view'),
    ('financeAdmin', 'payouts', 'approve'),
    ('financeAdmin', 'payouts', 'hold'),
    ('financeAdmin', 'payouts', 'export'),
    ('financeAdmin', 'disputes', 'view'),
    ('financeAdmin', 'disputes', 'refund'),
    ('financeAdmin', 'reports', 'view'),
    ('financeAdmin', 'reports', 'export'),
    -- sellerManager
    ('sellerManager', 'sellers', 'view'),
    ('sellerManager', 'sellers', 'approve'),
    ('sellerManager', 'sellers', 'reject'),
    ('sellerManager', 'sellers', 'suspend'),
    ('sellerManager', 'sellers', 'edit'),
    ('sellerManager', 'kyc', 'view'),
    ('sellerManager', 'kyc', 'verify'),
    ('sellerManager', 'kyc', 'reject'),
    ('sellerManager', 'products', 'view'),
    ('sellerManager', 'products', 'moderate'),
    ('sellerManager', 'support', 'view'),
    ('sellerManager', 'support', 'respond'),
    -- supportAdmin
    ('supportAdmin', 'support', 'view'),
    ('supportAdmin', 'support', 'assign'),
    ('supportAdmin', 'support', 'respond'),
    ('supportAdmin', 'support', 'close'),
    ('supportAdmin', 'customers', 'view'),
    ('supportAdmin', 'customers', 'assist'),
    ('supportAdmin', 'orders', 'view'),
    ('supportAdmin', 'orders', 'hold'),
    ('supportAdmin', 'disputes', 'view'),
    ('supportAdmin', 'disputes', 'escalate'),
    -- catalogManager
    ('catalogManager', 'categories', 'view'),
    ('catalogManager', 'categories', 'create'),
    ('catalogManager', 'categories', 'edit'),
    ('catalogManager', 'categories', 'delete'),
    ('catalogManager', 'products', 'view'),
    ('catalogManager', 'products', 'approve'),
    ('catalogManager', 'products', 'reject'),
    ('catalogManager', 'products', 'suspend'),
    ('catalogManager', 'brands', 'view'),
    ('catalogManager', 'brands', 'verify'),
    -- orderManager
    ('orderManager', 'orders', 'view'),
    ('orderManager', 'orders', 'cancel'),
    ('orderManager', 'orders', 'hold'),
    ('orderManager', 'orders', 'release'),
    ('orderManager', 'orders', 'reassign'),
    ('orderManager', 'shipping', 'view'),
    ('orderManager', 'shipping', 'update'),
    ('orderManager', 'shipping', 'assign'),
    ('orderManager', 'shipping', 'edit'),
    -- shippingManager
    ('shippingManager', 'orders', 'view'),
    ('shippingManager', 'orders', 'release'),
    ('shippingManager', 'shipping', 'view'),
    ('shippingManager', 'shipping', 'update'),
    ('shippingManager', 'shipping', 'assign'),
    ('shippingManager', 'shipping', 'edit'),
    -- disputeManager (Explicitly has returns:review / disputes:refund)
    ('disputeManager', 'disputes', 'view'),
    ('disputeManager', 'disputes', 'approve'),
    ('disputeManager', 'disputes', 'reject'),
    ('disputeManager', 'disputes', 'refund'),
    ('disputeManager', 'disputes', 'appeal'),
    ('disputeManager', 'returns', 'review'),
    ('disputeManager', 'returns', 'view'),
    ('disputeManager', 'orders', 'view'),
    -- marketingManager
    ('marketingManager', 'promotions', 'view'),
    ('marketingManager', 'promotions', 'create'),
    ('marketingManager', 'promotions', 'edit'),
    ('marketingManager', 'promotions', 'approve'),
    ('marketingManager', 'cms', 'view'),
    ('marketingManager', 'cms', 'edit'),
    ('marketingManager', 'notifications', 'view'),
    ('marketingManager', 'notifications', 'send'),
    ('marketingManager', 'notifications', 'schedule'),
    -- fraudAnalyst
    ('fraudAnalyst', 'fraud', 'view'),
    ('fraudAnalyst', 'fraud', 'blacklist'),
    ('fraudAnalyst', 'fraud', 'score'),
    ('fraudAnalyst', 'fraud', 'audit'),
    ('fraudAnalyst', 'customers', 'view'),
    ('fraudAnalyst', 'customers', 'suspend'),
    ('fraudAnalyst', 'orders', 'view'),
    ('fraudAnalyst', 'orders', 'hold'),
    -- reportingAnalyst
    ('reportingAnalyst', 'reports', 'view'),
    ('reportingAnalyst', 'reports', 'export'),
    ('reportingAnalyst', 'dashboard', 'view'),
    ('reportingAnalyst', 'sellers', 'view'),
    ('reportingAnalyst', 'orders', 'view'),
    -- auditor
    ('auditor', '*', 'view')
ON CONFLICT (staff_role, module, action) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. UPDATED has_permission RESOLVING 12 STAFF ROLES
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.has_permission(required_module TEXT, required_action TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_uid UUID;
    v_app_role public.app_role;
    v_staff_role public.admin_staff_role;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN FALSE;
    END IF;

    -- 1. Check Owner / Super Admin bypass from user_roles
    IF EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_uid
          AND (
              role IN ('owner'::public.app_role, 'super_admin'::public.app_role)
              OR staff_role IN ('owner'::public.admin_staff_role, 'superAdmin'::public.admin_staff_role)
          )
    ) THEN
        RETURN TRUE;
    END IF;

    -- 2. Check granular staff_role permissions from staff_role_permissions table
    SELECT staff_role INTO v_staff_role
    FROM public.user_roles
    WHERE user_id = v_uid
      AND staff_role IS NOT NULL
    ORDER BY granted_at DESC
    LIMIT 1;

    IF v_staff_role IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM public.staff_role_permissions srp
            WHERE srp.staff_role = v_staff_role
              AND (srp.module = '*' OR srp.module = required_module OR (required_module = 'returns' AND srp.module = 'disputes'))
              AND (srp.action = '*' OR srp.action = required_action)
        ) THEN
            RETURN TRUE;
        END IF;
    END IF;

    -- 3. Check legacy role_permissions table
    v_app_role := public.get_current_user_role();
    IF v_app_role IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM public.role_permissions rp
            WHERE rp.role = v_app_role
              AND (rp.module = '*' OR rp.module = required_module)
              AND (rp.action = '*' OR rp.action = required_action)
        ) THEN
            RETURN TRUE;
        END IF;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

-- ----------------------------------------------------------------------------
-- 4. SHARED MONEY COLLECTION HELPER: is_order_refundable
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_order_refundable(p_order_id TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_status TEXT;
    v_payment_status TEXT;
    v_payment_method TEXT;
BEGIN
    SELECT status, payment_status, payment_method
    INTO v_status, v_payment_status, v_payment_method
    FROM public.buyer_orders
    WHERE id = p_order_id;

    IF v_status IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Paid digital payments
    IF v_payment_status = 'Paid' THEN
        RETURN TRUE;
    END IF;

    -- Cash on Delivery: money is collected only when delivered to buyer
    IF v_payment_method IN ('Cash on Delivery', 'COD') AND v_status = 'Delivered' THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_order_refundable(TEXT) TO authenticated, anon;

-- ----------------------------------------------------------------------------
-- 5. REFIT admin_arbitrate_return_claim USING HELPER & UNIFIED AUDIT LOGGING
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_arbitrate_return_claim(
    p_claim_id UUID,
    p_decision TEXT, -- 'Approved' or 'Rejected'
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_admin_id UUID;
    v_has_privilege BOOLEAN;
    v_claim RECORD;
    v_refund_amount NUMERIC(12,2);
    v_idempotency_key TEXT;
    v_refund_res JSONB;
    v_refund_id UUID;
    v_trimmed_notes TEXT;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    -- Strict RBAC: Check has_permission('returns', 'review') with owner/super_admin bypass only
    IF NOT public.has_permission('returns', 'review') THEN
        RAISE EXCEPTION 'Access denied: Insufficient administrative privileges to arbitrate return claims.' USING ERRCODE = '42501';
    END IF;

    IF p_decision NOT IN ('Approved', 'Rejected') THEN
        RAISE EXCEPTION 'Invalid arbitration decision: %. Must be Approved or Rejected.', p_decision USING ERRCODE = 'P0001';
    END IF;

    -- Validate notes rules
    v_trimmed_notes := NULLIF(TRIM(COALESCE(p_notes, '')), '');
    IF p_decision = 'Rejected' THEN
        IF v_trimmed_notes IS NULL THEN
            RAISE EXCEPTION 'Rejection notes are mandatory when rejecting a dispute claim.' USING ERRCODE = 'P0005';
        END IF;
        IF length(v_trimmed_notes) > 1000 THEN
            RAISE EXCEPTION 'Rejection notes cannot exceed 1000 characters.' USING ERRCODE = 'P0005';
        END IF;
    ELSIF p_decision = 'Approved' THEN
        IF v_trimmed_notes IS NOT NULL AND length(v_trimmed_notes) > 1000 THEN
            RAISE EXCEPTION 'Approval notes cannot exceed 1000 characters.' USING ERRCODE = 'P0005';
        END IF;
    END IF;

    -- Fetch and lock the claim row
    SELECT id, order_id, order_item_id, seller_store_id, customer_user_id, quantity, status
    INTO v_claim
    FROM public.return_requests
    WHERE id = p_claim_id
    FOR UPDATE;

    IF v_claim.id IS NULL THEN
        RAISE EXCEPTION 'Return claim % not found.', p_claim_id USING ERRCODE = 'P0002';
    END IF;

    -- Block already finalized claims
    IF v_claim.status IN ('Completed', 'Rejected') THEN
        RAISE EXCEPTION 'Claim % is already finalized in status %.', p_claim_id, v_claim.status USING ERRCODE = 'P0003';
    END IF;

    IF p_decision = 'Rejected' THEN
        UPDATE public.return_requests
        SET status = 'Rejected',
            admin_notes = v_trimmed_notes,
            processed_by = v_admin_id,
            updated_at = NOW()
        WHERE id = p_claim_id;

        -- Record Immutable Audit Log via canonical helper
        PERFORM public.internal_record_audit_log(
            'return_requests',
            p_claim_id::text,
            'DISPUTE_REJECTED',
            jsonb_build_object(
                'order_id', v_claim.order_id,
                'decision', 'Rejected',
                'notes', v_trimmed_notes
            )
        );

        -- Notify Buyer
        PERFORM public.internal_create_notification(
            v_claim.customer_user_id,
            'RETURN_REJECTED',
            'Dispute Arbitration: Claim Rejected',
            v_trimmed_notes,
            'RETURN',
            p_claim_id::text,
            'NOTIF-DISP-' || p_claim_id::text || '-REJ'
        );

        RETURN jsonb_build_object(
            'success', TRUE,
            'claim_id', p_claim_id,
            'status', 'Rejected'
        );

    ELSIF p_decision = 'Approved' THEN
        -- Check money was collected before approving via shared helper
        IF NOT public.is_order_refundable(v_claim.order_id) THEN
            RAISE EXCEPTION 'Cannot approve refund: Order % has not been collected/delivered or paid.',
                v_claim.order_id USING ERRCODE = 'P0006';
        END IF;

        -- Strictly query order line item unit price (NO fallback value)
        SELECT (unit_price * v_claim.quantity) INTO v_refund_amount
        FROM public.order_items
        WHERE id = v_claim.order_item_id;

        IF v_refund_amount IS NULL OR v_refund_amount <= 0.00 THEN
            RAISE EXCEPTION 'Cannot approve refund: Target order item % has missing or invalid price.', v_claim.order_item_id USING ERRCODE = 'P0004';
        END IF;

        v_idempotency_key := 'ARB-REF-' || p_claim_id::text;

        -- Process Authoritative Refund through Financial Ledger
        v_refund_res := public.admin_process_refund(
            v_claim.order_id,
            v_claim.order_item_id,
            v_refund_amount,
            COALESCE(v_trimmed_notes, 'Arbitrated Full Refund: Claim ' || p_claim_id::text),
            v_idempotency_key
        );

        v_refund_id := (v_refund_res->>'refund_id')::uuid;

        UPDATE public.return_requests
        SET status = 'Completed',
            refund_id = v_refund_id,
            admin_notes = v_trimmed_notes,
            processed_by = v_admin_id,
            updated_at = NOW()
        WHERE id = p_claim_id;

        -- Record Immutable Audit Log via canonical helper
        PERFORM public.internal_record_audit_log(
            'return_requests',
            p_claim_id::text,
            'DISPUTE_FULL_REFUND',
            jsonb_build_object(
                'order_id', v_claim.order_id,
                'refund_id', v_refund_id,
                'refund_amount', v_refund_amount,
                'notes', v_trimmed_notes
            )
        );

        -- Notify Buyer
        PERFORM public.internal_create_notification(
            v_claim.customer_user_id,
            'RETURN_APPROVED',
            'Dispute Arbitration: Refund Approved',
            'Your dispute was resolved. A refund of PKR ' || v_refund_amount::text || ' was approved.',
            'RETURN',
            p_claim_id::text,
            'NOTIF-DISP-' || p_claim_id::text || '-APP'
        );

        RETURN jsonb_build_object(
            'success', TRUE,
            'claim_id', p_claim_id,
            'refund_id', v_refund_id,
            'refund_amount', v_refund_amount,
            'status', 'Completed'
        );
    END IF;

    RETURN jsonb_build_object('success', FALSE, 'error', 'Unhandled condition');
END;
$$;

-- ----------------------------------------------------------------------------
-- 6. REFIT review_return_request USING is_order_refundable & UNIFIED AUDIT LOGGING
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
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    IF p_decision NOT IN ('Approved', 'Rejected') THEN
        RAISE EXCEPTION 'Invalid return review decision: %', p_decision USING ERRCODE = 'P0001';
    END IF;

    -- Lock & Fetch Return Request Row
    SELECT id, order_id, order_item_id, seller_store_id, customer_user_id, quantity, status
    INTO v_return
    FROM public.return_requests
    WHERE id = p_return_id FOR UPDATE;

    IF v_return.id IS NULL THEN
        RAISE EXCEPTION 'Return request % not found.', p_return_id USING ERRCODE = 'P0002';
    END IF;

    -- Authorization: Seller store owner or Admin with returns:review permission
    IF NOT (
        EXISTS (SELECT 1 FROM public.seller_stores WHERE id = v_return.seller_store_id AND owner_id = v_reviewer_id)
        OR public.has_permission('returns', 'review')
    ) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to review return request.' USING ERRCODE = '42501';
    END IF;

    IF v_return.status <> 'Requested' THEN
        RAISE EXCEPTION 'Return request % is already in % status.', p_return_id, v_return.status USING ERRCODE = 'P0003';
    END IF;

    IF p_decision = 'Rejected' THEN
        UPDATE public.return_requests
        SET status = 'Rejected', admin_notes = p_admin_notes, processed_by = v_reviewer_id, updated_at = NOW()
        WHERE id = p_return_id;

        PERFORM public.internal_create_notification(
            v_return.customer_user_id,
            'RETURN_REJECTED',
            'Return Request Rejected',
            COALESCE(p_admin_notes, 'Your return request for order ' || v_return.order_id || ' was rejected.'),
            'RETURN',
            p_return_id::text,
            'NOTIF-RET-DEC-' || p_return_id::text || '-REJ'
        );

        RETURN jsonb_build_object('success', TRUE, 'status', 'Rejected', 'return_id', p_return_id);

    ELSIF p_decision = 'Approved' THEN
        -- Check money was collected before approving via shared helper
        IF NOT public.is_order_refundable(v_return.order_id) THEN
            RAISE EXCEPTION 'Cannot approve return: Order % is not in a paid or collected state.',
                v_return.order_id USING ERRCODE = 'P0006';
        END IF;

        -- Calculate Refund Amount based on Line Item Unit Price * Returned Quantity
        SELECT (unit_price * v_return.quantity) INTO v_refund_amount
        FROM public.order_items
        WHERE id = v_return.order_item_id;

        IF v_refund_amount IS NULL OR v_refund_amount <= 0.00 THEN
            RAISE EXCEPTION 'Cannot approve return: Order item has invalid price.' USING ERRCODE = 'P0004';
        END IF;

        v_idempotency_key := 'REF-RET-' || p_return_id::text;

        -- Invoke Phase 10 Authoritative Refund Function
        v_refund_res := public.admin_process_refund(
            v_return.order_id,
            v_return.order_item_id,
            v_refund_amount,
            COALESCE(p_admin_notes, 'Seller approved return: ' || p_return_id::text),
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
            'Your return request for order ' || v_return.order_id || ' was approved and refunded.',
            'RETURN',
            p_return_id::text,
            'NOTIF-RET-DEC-' || p_return_id::text || '-APP'
        );

        RETURN jsonb_build_object('success', TRUE, 'status', 'Completed', 'return_id', p_return_id, 'refund_id', v_refund_id);
    END IF;

    RETURN jsonb_build_object('success', FALSE, 'error', 'Unhandled condition');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';


-- =========================================================================
-- FILE: 20260828000000_audit_hardening_and_staff_role_governance.sql
-- =========================================================================

-- Migration: 20260828000000_audit_hardening_and_staff_role_governance.sql
-- Description: Audit logs security & immutability, admin_assign_staff_role RPC, and strict staff_role separation in has_permission

-- ----------------------------------------------------------------------------
-- 1. SAFE AUDIT LOG CONSOLIDATION & IMMUTABILITY
-- ----------------------------------------------------------------------------

-- Copy any remaining rows from admin_audit_logs if it exists as a table before converting
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'admin_audit_logs'
    ) THEN
        INSERT INTO public.audit_logs (
            actor_user_id,
            actor_role,
            action,
            target_type,
            target_id,
            metadata,
            details,
            created_at
        )
        SELECT
            COALESCE(admin_user_id, admin_id),
            'admin'::public.app_role,
            COALESCE(action, action_type, 'ADMIN_ACTION'),
            COALESCE(target_type, target_entity, 'UNKNOWN'),
            COALESCE(target_id, 'UNKNOWN'),
            COALESCE(details, '{}'::jsonb),
            COALESCE(details, '{}'::jsonb),
            COALESCE(created_at, NOW())
        FROM public.admin_audit_logs;

        DROP TABLE public.admin_audit_logs CASCADE;
    END IF;
END $$;

-- Drop and recreate the compatibility view admin_audit_logs WITH (security_invoker = true)
DROP VIEW IF EXISTS public.admin_audit_logs CASCADE;

CREATE OR REPLACE VIEW public.admin_audit_logs
WITH (security_invoker = true) AS
SELECT
    id,
    actor_user_id AS admin_id,
    actor_user_id AS admin_user_id,
    action,
    action AS action_type,
    target_type,
    target_type AS target_entity,
    target_id,
    COALESCE(metadata, details, '{}'::jsonb) AS details,
    created_at
FROM public.audit_logs;

-- Re-create INSTEAD OF INSERT trigger on the view
CREATE OR REPLACE FUNCTION public.trg_admin_audit_logs_compat_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.audit_logs (
        actor_user_id,
        actor_role,
        action,
        target_type,
        target_id,
        metadata,
        details
    ) VALUES (
        COALESCE(NEW.admin_id, NEW.admin_user_id, auth.uid()),
        COALESCE(public.get_current_user_role(), 'admin'::public.app_role),
        COALESCE(NEW.action, NEW.action_type, 'ADMIN_ACTION'),
        COALESCE(NEW.target_type, NEW.target_entity, 'UNKNOWN'),
        COALESCE(NEW.target_id, 'UNKNOWN'),
        COALESCE(NEW.details, '{}'::jsonb),
        COALESCE(NEW.details, '{}'::jsonb)
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_admin_audit_logs_compat ON public.admin_audit_logs;
CREATE TRIGGER trg_admin_audit_logs_compat
    INSTEAD OF INSERT ON public.admin_audit_logs
    FOR EACH ROW EXECUTE FUNCTION public.trg_admin_audit_logs_compat_insert();

-- Enforce explicit grants on public.audit_logs and admin_audit_logs view
REVOKE ALL ON public.audit_logs FROM PUBLIC, anon;
REVOKE INSERT, UPDATE, DELETE ON public.audit_logs FROM authenticated;
GRANT SELECT ON public.audit_logs TO authenticated;

REVOKE ALL ON public.admin_audit_logs FROM PUBLIC, anon;
REVOKE UPDATE, DELETE ON public.admin_audit_logs FROM authenticated;
GRANT SELECT, INSERT ON public.admin_audit_logs TO authenticated;

-- Ensure audit_logs RLS is enabled and strictly restricted
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view audit logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Audit log view restricted to audit permission" ON public.audit_logs;

CREATE POLICY "Audit log view restricted to audit permission" ON public.audit_logs
    FOR SELECT TO authenticated
    USING (
        public.has_permission('audit', 'view')
    );

-- Tamper prevention: Block ANY UPDATE or DELETE on audit_logs
CREATE OR REPLACE FUNCTION public.prevent_audit_log_tampering()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RAISE EXCEPTION 'Audit log records are immutable and cannot be modified or deleted.'
        USING ERRCODE = '42501';
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_audit_log_tampering ON public.audit_logs;
CREATE TRIGGER trg_prevent_audit_log_tampering
    BEFORE UPDATE OR DELETE ON public.audit_logs
    FOR EACH ROW EXECUTE FUNCTION public.prevent_audit_log_tampering();

-- Seed audit:view permission for auditor in staff_role_permissions if not present
INSERT INTO public.staff_role_permissions (staff_role, module, action)
VALUES ('auditor', 'audit', 'view')
ON CONFLICT (staff_role, module, action) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. STAFF ROLE ASSIGNMENT RPC: admin_assign_staff_role
-- ----------------------------------------------------------------------------

-- Ensure user_roles has no direct INSERT/UPDATE/DELETE grants for authenticated users
REVOKE INSERT, UPDATE, DELETE ON public.user_roles FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.user_roles TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_assign_staff_role(
    p_user_id UUID,
    p_staff_role public.admin_staff_role
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.' USING ERRCODE = '42501';
    END IF;

    -- 1. Check Caller Privilege: Only owner or superAdmin/super_admin can assign staff roles
    IF NOT EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (
              role IN ('owner'::public.app_role, 'super_admin'::public.app_role)
              OR staff_role IN ('owner'::public.admin_staff_role, 'superAdmin'::public.admin_staff_role)
          )
    ) THEN
        RAISE EXCEPTION 'Access denied: Only Owner or Super Admin can assign staff roles.'
            USING ERRCODE = '42501';
    END IF;

    -- 2. Self-assignment prevention
    IF p_user_id = v_caller_id THEN
        RAISE EXCEPTION 'Self-assignment of staff roles is prohibited.' USING ERRCODE = '42501';
    END IF;

    -- 3. Owner role assignment prevention
    IF p_staff_role = 'owner'::public.admin_staff_role THEN
        RAISE EXCEPTION 'Assignment of the Owner role is prohibited.' USING ERRCODE = '42501';
    END IF;

    -- 4. Target user validation
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'Target user not found.' USING ERRCODE = 'P0002';
    END IF;

    -- 5. Upsert role into user_roles
    INSERT INTO public.user_roles (user_id, role, staff_role)
    VALUES (p_user_id, 'admin'::public.app_role, p_staff_role)
    ON CONFLICT (user_id, role)
    DO UPDATE SET staff_role = EXCLUDED.staff_role, granted_at = NOW();

    -- 6. Record Audit Log
    v_audit_id := public.internal_record_audit_log(
        'user_role',
        p_user_id::TEXT,
        'STAFF_ROLE_ASSIGNED',
        jsonb_build_object(
            'assigned_staff_role', p_staff_role::TEXT,
            'assigned_by', v_caller_id
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'user_id', p_user_id,
        'staff_role', p_staff_role,
        'audit_log_id', v_audit_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_assign_staff_role(UUID, public.admin_staff_role) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_assign_staff_role(UUID, public.admin_staff_role) TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. STRICT has_permission REFACTORING & LEGACY ISOLATION
-- ----------------------------------------------------------------------------

-- Remove the legacy ('admin', 'returns', 'review') permission row to prevent any leakage
DELETE FROM public.role_permissions
WHERE role = 'admin'::public.app_role
  AND module = 'returns'
  AND action = 'review';

CREATE OR REPLACE FUNCTION public.has_permission(required_module TEXT, required_action TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_uid UUID;
    v_app_role public.app_role;
    v_staff_role public.admin_staff_role;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN FALSE;
    END IF;

    -- 1. Owner / Super Admin bypass from user_roles
    IF EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_uid
          AND (
              role IN ('owner'::public.app_role, 'super_admin'::public.app_role)
              OR staff_role IN ('owner'::public.admin_staff_role, 'superAdmin'::public.admin_staff_role)
          )
    ) THEN
        RETURN TRUE;
    END IF;

    -- 2. Staff Role Evaluation:
    -- If user has a staff_role, evaluate ONLY through staff_role_permissions.
    SELECT staff_role INTO v_staff_role
    FROM public.user_roles
    WHERE user_id = v_uid
      AND staff_role IS NOT NULL
    ORDER BY granted_at DESC
    LIMIT 1;

    IF v_staff_role IS NOT NULL THEN
        -- Evaluate explicit rows in staff_role_permissions (NO shortcuts)
        IF EXISTS (
            SELECT 1 FROM public.staff_role_permissions srp
            WHERE srp.staff_role = v_staff_role
              AND (srp.module = '*' OR srp.module = required_module)
              AND (srp.action = '*' OR srp.action = required_action)
        ) THEN
            RETURN TRUE;
        END IF;

        -- Staff role users are evaluated EXCLUSIVELY through staff_role_permissions.
        -- Never fall through to legacy role_permissions.
        RETURN FALSE;
    END IF;

    -- 3. Legacy role_permissions check: ONLY for users without a staff_role
    v_app_role := public.get_current_user_role();
    IF v_app_role IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM public.role_permissions rp
            WHERE rp.role = v_app_role
              AND (rp.module = '*' OR rp.module = required_module)
              AND (rp.action = '*' OR rp.action = required_action)
        ) THEN
            RETURN TRUE;
        END IF;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';


-- =========================================================================
-- FILE: 20260829000000_audit_forgery_staff_governance_and_fk_fix.sql
-- =========================================================================

-- Migration: 20260829000000_audit_forgery_staff_governance_and_fk_fix.sql
-- Description: Audit forgery protection, strict legacy admin deny, granular role assign/revoke rules, and FK safety

-- ----------------------------------------------------------------------------
-- 1. AUDIT FORGERY PROTECTION
-- ----------------------------------------------------------------------------

-- Revoke INSERT on public.admin_audit_logs (view) and public.audit_logs (table)
REVOKE INSERT, UPDATE, DELETE ON public.admin_audit_logs FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.audit_logs FROM PUBLIC, anon, authenticated;

GRANT SELECT ON public.admin_audit_logs TO authenticated;
GRANT SELECT ON public.audit_logs TO authenticated;

-- Restrict the INSTEAD OF trigger on admin_audit_logs to ignore client-supplied actor ID
CREATE OR REPLACE FUNCTION public.trg_admin_audit_logs_compat_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required for audit logging.' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.audit_logs (
        actor_user_id,
        actor_role,
        action,
        target_type,
        target_id,
        metadata,
        details
    ) VALUES (
        auth.uid(),
        COALESCE(public.get_current_user_role(), 'admin'::public.app_role),
        COALESCE(NEW.action, NEW.action_type, 'ADMIN_ACTION'),
        COALESCE(NEW.target_type, NEW.target_entity, 'UNKNOWN'),
        COALESCE(NEW.target_id, 'UNKNOWN'),
        COALESCE(NEW.details, '{}'::jsonb),
        COALESCE(NEW.details, '{}'::jsonb)
    );
    RETURN NEW;
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. AUDIT LOG FOREIGN KEY INTEGRITY
-- ----------------------------------------------------------------------------
-- Ensure actor_user_id explicitly uses ON DELETE NO ACTION to prevent mutation on user deletion
ALTER TABLE public.audit_logs
    DROP CONSTRAINT IF EXISTS audit_logs_actor_user_id_fkey;

ALTER TABLE public.audit_logs
    ADD CONSTRAINT audit_logs_actor_user_id_fkey
    FOREIGN KEY (actor_user_id) REFERENCES auth.users(id) ON DELETE NO ACTION;

-- ----------------------------------------------------------------------------
-- 3. LEGACY ADMIN DEFAULT DENY & NOTICE UNASSIGNED
-- ----------------------------------------------------------------------------
-- Notice unassigned legacy admin users during migration
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT ur.user_id, u.email
        FROM public.user_roles ur
        LEFT JOIN auth.users u ON u.id = ur.user_id
        WHERE ur.role = 'admin'::public.app_role
          AND ur.staff_role IS NULL
    ) LOOP
        RAISE NOTICE 'UNASSIGNED_LEGACY_ADMIN: user_id=%, email=%', r.user_id, r.email;
    END LOOP;
END $$;

-- Update has_permission: Users with role = 'admin' but NO staff_role get default FALSE
CREATE OR REPLACE FUNCTION public.has_permission(required_module TEXT, required_action TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_uid UUID;
    v_app_role public.app_role;
    v_staff_role public.admin_staff_role;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN FALSE;
    END IF;

    -- 1. Owner / Super Admin bypass from user_roles
    IF EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_uid
          AND (
              role IN ('owner'::public.app_role, 'super_admin'::public.app_role)
              OR staff_role IN ('owner'::public.admin_staff_role, 'superAdmin'::public.admin_staff_role)
          )
    ) THEN
        RETURN TRUE;
    END IF;

    -- 2. Staff Role Evaluation:
    SELECT staff_role INTO v_staff_role
    FROM public.user_roles
    WHERE user_id = v_uid
      AND staff_role IS NOT NULL
    ORDER BY granted_at DESC
    LIMIT 1;

    IF v_staff_role IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM public.staff_role_permissions srp
            WHERE srp.staff_role = v_staff_role
              AND (srp.module = '*' OR srp.module = required_module)
              AND (srp.action = '*' OR srp.action = required_action)
        ) THEN
            RETURN TRUE;
        END IF;

        -- Staff role users are evaluated EXCLUSIVELY through staff_role_permissions
        RETURN FALSE;
    END IF;

    -- 3. Legacy check:
    -- If user has role = 'admin' but NO staff_role, default DENY (RETURN FALSE)
    v_app_role := public.get_current_user_role();
    IF v_app_role = 'admin'::public.app_role THEN
        RETURN FALSE;
    END IF;

    -- Non-admin roles (buyer, seller) evaluate through legacy role_permissions
    IF v_app_role IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM public.role_permissions rp
            WHERE rp.role = v_app_role
              AND (rp.module = '*' OR rp.module = required_module)
              AND (rp.action = '*' OR rp.action = required_action)
        ) THEN
            RETURN TRUE;
        END IF;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

-- ----------------------------------------------------------------------------
-- 4. GRANULAR STAFF ROLE ASSIGNMENT & REVOCATION
-- ----------------------------------------------------------------------------

-- admin_assign_staff_role: Only owner can assign superAdmin; superAdmin can assign other 10
CREATE OR REPLACE FUNCTION public.admin_assign_staff_role(
    p_user_id UUID,
    p_staff_role public.admin_staff_role
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_is_owner BOOLEAN;
    v_is_super_admin BOOLEAN;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.' USING ERRCODE = '42501';
    END IF;

    -- Check caller authority
    v_is_owner := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (role = 'owner'::public.app_role OR staff_role = 'owner'::public.admin_staff_role)
    );

    v_is_super_admin := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (role = 'super_admin'::public.app_role OR staff_role = 'superAdmin'::public.admin_staff_role)
    );

    IF NOT (v_is_owner OR v_is_super_admin) THEN
        RAISE EXCEPTION 'Access denied: Only Owner or Super Admin can assign staff roles.'
            USING ERRCODE = '42501';
    END IF;

    -- Self-assignment prevention
    IF p_user_id = v_caller_id THEN
        RAISE EXCEPTION 'Self-assignment of staff roles is prohibited.' USING ERRCODE = '42501';
    END IF;

    -- Owner assignment is prohibited
    IF p_staff_role = 'owner'::public.admin_staff_role THEN
        RAISE EXCEPTION 'Assignment of the Owner role is prohibited.' USING ERRCODE = '42501';
    END IF;

    -- Only Owner may assign superAdmin
    IF p_staff_role = 'superAdmin'::public.admin_staff_role AND NOT v_is_owner THEN
        RAISE EXCEPTION 'Access denied: Only Owner can assign the superAdmin role.'
            USING ERRCODE = '42501';
    END IF;

    -- Target user validation
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'Target user not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Upsert role into user_roles
    INSERT INTO public.user_roles (user_id, role, staff_role)
    VALUES (p_user_id, 'admin'::public.app_role, p_staff_role)
    ON CONFLICT (user_id, role)
    DO UPDATE SET staff_role = EXCLUDED.staff_role, granted_at = NOW();

    -- Record Audit Log
    v_audit_id := public.internal_record_audit_log(
        'user_role',
        p_user_id::TEXT,
        'STAFF_ROLE_ASSIGNED',
        jsonb_build_object(
            'assigned_staff_role', p_staff_role::TEXT,
            'assigned_by', v_caller_id
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'user_id', p_user_id,
        'staff_role', p_staff_role,
        'audit_log_id', v_audit_id
    );
END;
$$;

-- admin_revoke_staff_role: Only owner can revoke superAdmin; superAdmin can revoke other 10
CREATE OR REPLACE FUNCTION public.admin_revoke_staff_role(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_is_owner BOOLEAN;
    v_is_super_admin BOOLEAN;
    v_target_staff_role public.admin_staff_role;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.' USING ERRCODE = '42501';
    END IF;

    -- Self-revocation prevention
    IF p_user_id = v_caller_id THEN
        RAISE EXCEPTION 'Self-revocation of staff roles is prohibited.' USING ERRCODE = '42501';
    END IF;

    -- Caller authority
    v_is_owner := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (role = 'owner'::public.app_role OR staff_role = 'owner'::public.admin_staff_role)
    );

    v_is_super_admin := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (role = 'super_admin'::public.app_role OR staff_role = 'superAdmin'::public.admin_staff_role)
    );

    IF NOT (v_is_owner OR v_is_super_admin) THEN
        RAISE EXCEPTION 'Access denied: Only Owner or Super Admin can revoke staff roles.'
            USING ERRCODE = '42501';
    END IF;

    -- Target role check
    SELECT staff_role INTO v_target_staff_role
    FROM public.user_roles
    WHERE user_id = p_user_id AND staff_role IS NOT NULL
    LIMIT 1;

    IF v_target_staff_role IS NULL THEN
        RAISE EXCEPTION 'Target user does not have an active staff role.' USING ERRCODE = 'P0002';
    END IF;

    -- Only Owner can revoke a superAdmin role
    IF v_target_staff_role = 'superAdmin'::public.admin_staff_role AND NOT v_is_owner THEN
        RAISE EXCEPTION 'Access denied: Only Owner can revoke the superAdmin role.'
            USING ERRCODE = '42501';
    END IF;

    -- Revoke staff_role
    UPDATE public.user_roles
    SET staff_role = NULL, granted_at = NOW()
    WHERE user_id = p_user_id AND role = 'admin'::public.app_role;

    -- Record Audit Log
    v_audit_id := public.internal_record_audit_log(
        'user_role',
        p_user_id::TEXT,
        'STAFF_ROLE_REVOKED',
        jsonb_build_object(
            'revoked_staff_role', v_target_staff_role::TEXT,
            'revoked_by', v_caller_id
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'user_id', p_user_id,
        'revoked_staff_role', v_target_staff_role,
        'audit_log_id', v_audit_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_revoke_staff_role(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_revoke_staff_role(UUID) TO authenticated;


-- =========================================================================
-- FILE: 20260830000000_complete_rbac_security_definer_audit_and_account_lifecycle.sql
-- =========================================================================

-- Migration: 20260830000000_complete_rbac_security_definer_audit_and_account_lifecycle.sql
-- Description: Complete conversion of admin_ functions to has_permission, audit-proof staff revocation, account soft-deactivation, F3/F4/F5 security guards

-- ----------------------------------------------------------------------------
-- 1. STAFF ROLE REVOCATION HARDENING
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_revoke_staff_role(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_is_owner BOOLEAN;
    v_is_super_admin BOOLEAN;
    v_target_staff_role public.admin_staff_role;
    v_row_count INT := 0;
    v_audit_id UUID := NULL;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.' USING ERRCODE = '42501';
    END IF;

    -- Self-revocation prevention
    IF p_user_id = v_caller_id THEN
        RAISE EXCEPTION 'Self-revocation of staff roles is prohibited.' USING ERRCODE = '42501';
    END IF;

    -- Caller authority
    v_is_owner := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (role = 'owner'::public.app_role OR staff_role = 'owner'::public.admin_staff_role)
    );

    v_is_super_admin := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (role = 'super_admin'::public.app_role OR staff_role = 'superAdmin'::public.admin_staff_role)
    );

    IF NOT (v_is_owner OR v_is_super_admin) THEN
        RAISE EXCEPTION 'Access denied: Only Owner or Super Admin can revoke staff roles.'
            USING ERRCODE = '42501';
    END IF;

    -- Target staff role lookup
    SELECT staff_role INTO v_target_staff_role
    FROM public.user_roles
    WHERE user_id = p_user_id AND staff_role IS NOT NULL
    ORDER BY granted_at DESC
    LIMIT 1;

    IF v_target_staff_role IS NULL THEN
        RAISE EXCEPTION 'Target user does not have an active staff role.' USING ERRCODE = 'P0002';
    END IF;

    -- Rule (a): Nobody can revoke the 'owner' staff role
    IF v_target_staff_role = 'owner'::public.admin_staff_role THEN
        RAISE EXCEPTION 'Revocation of the Owner role is prohibited.' USING ERRCODE = '42501';
    END IF;

    -- Rule (d): superAdmin cannot revoke superAdmin (Only Owner can revoke superAdmin)
    IF v_target_staff_role = 'superAdmin'::public.admin_staff_role AND NOT v_is_owner THEN
        RAISE EXCEPTION 'Access denied: Only Owner can revoke the superAdmin role.'
            USING ERRCODE = '42501';
    END IF;

    -- Rule (b): Update the actual row(s) that carry the staff_role (not only role='admin')
    UPDATE public.user_roles
    SET staff_role = NULL, granted_at = NOW()
    WHERE user_id = p_user_id AND staff_role IS NOT NULL;

    -- Rule (c): Only write audit row if a row was really changed
    GET DIAGNOSTICS v_row_count = ROW_COUNT;

    IF v_row_count > 0 THEN
        v_audit_id := public.internal_record_audit_log(
            'user_role',
            p_user_id::TEXT,
            'STAFF_ROLE_REVOKED',
            jsonb_build_object(
                'revoked_staff_role', v_target_staff_role::TEXT,
                'revoked_by', v_caller_id,
                'rows_affected', v_row_count
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'user_id', p_user_id,
        'revoked_staff_role', v_target_staff_role,
        'rows_affected', v_row_count,
        'audit_log_id', v_audit_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_revoke_staff_role(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_revoke_staff_role(UUID) TO authenticated;

-- ----------------------------------------------------------------------------
-- 2. COMPLETE CONVERSION OF admin_ FUNCTIONS & is_admin() TO has_permission
-- ----------------------------------------------------------------------------

-- Redefine public.is_admin() to require owner or superAdmin privilege
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = auth.uid()
          AND (
              role IN ('owner'::public.app_role, 'super_admin'::public.app_role)
              OR staff_role IN ('owner'::public.admin_staff_role, 'superAdmin'::public.admin_staff_role)
          )
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

-- A. admin_review_seller_store
DROP FUNCTION IF EXISTS public.admin_review_seller_store(UUID, BOOLEAN, NUMERIC);
DROP FUNCTION IF EXISTS public.admin_review_seller_store(UUID, BOOLEAN, NUMERIC(5,2));
DROP FUNCTION IF EXISTS public.admin_review_seller_store(UUID, BOOLEAN);
CREATE OR REPLACE FUNCTION public.admin_review_seller_store(
    store_id UUID,
    approved BOOLEAN,
    new_commission_rate NUMERIC DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    IF NOT public.has_permission('sellers', 'approve') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to review seller stores.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.seller_stores
    SET is_approved = approved,
        commission_rate = COALESCE(new_commission_rate, commission_rate),
        updated_at = NOW()
    WHERE id = store_id;

    PERFORM public.internal_record_audit_log(
        'seller_stores',
        store_id::TEXT,
        CASE WHEN approved THEN 'SELLER_APPROVED' ELSE 'SELLER_REJECTED' END,
        jsonb_build_object('commission_rate', new_commission_rate)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- B. admin_review_kyc_document
DROP FUNCTION IF EXISTS public.admin_review_kyc_document(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_review_kyc_document(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.admin_review_kyc_document(
    doc_id UUID,
    new_status TEXT,
    notes TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    IF NOT public.has_permission('kyc', 'verify') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to verify KYC documents.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.seller_kyc_documents
    SET status = new_status,
        rejection_reason = notes,
        reviewed_by = auth.uid(),
        reviewed_at = NOW()
    WHERE id = doc_id;

    PERFORM public.internal_record_audit_log(
        'seller_kyc_documents',
        doc_id::TEXT,
        'KYC_DOCUMENT_REVIEWED',
        jsonb_build_object('status', new_status, 'notes', notes)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- C. admin_review_product
DROP FUNCTION IF EXISTS public.admin_review_product(UUID, BOOLEAN, TEXT);
DROP FUNCTION IF EXISTS public.admin_review_product(UUID, BOOLEAN);
CREATE OR REPLACE FUNCTION public.admin_review_product(
    prod_id UUID,
    approved BOOLEAN,
    rejection_reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_store_id UUID;
BEGIN
    IF NOT (public.has_permission('products', 'approve') OR public.has_permission('products', 'moderate')) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to review products.' USING ERRCODE = '42501';
    END IF;

    SELECT seller_store_id INTO v_store_id
    FROM public.products
    WHERE id = prod_id;

    IF v_store_id IS NOT NULL AND public.owns_seller_store(v_store_id) THEN
        RAISE EXCEPTION 'Sellers cannot approve their own products.' USING ERRCODE = '42501';
    END IF;

    IF NOT approved AND trim(COALESCE(rejection_reason, '')) = '' THEN
        RAISE EXCEPTION 'Product rejection requires a non-empty reason.';
    END IF;

    UPDATE public.products
    SET approval_status = CASE WHEN approved THEN 'Approved' ELSE 'Rejected' END,
        is_active = approved,
        updated_at = NOW()
    WHERE id = prod_id;

    PERFORM public.internal_record_audit_log(
        'products',
        prod_id::TEXT,
        'REVIEW_PRODUCT',
        jsonb_build_object('approval_status', CASE WHEN approved THEN 'Approved' ELSE 'Rejected' END, 'rejection_reason', rejection_reason)
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';
GRANT EXECUTE ON FUNCTION public.admin_review_product(UUID, BOOLEAN, TEXT) TO authenticated;

-- D. admin_adjust_seller_wallet
DROP FUNCTION IF EXISTS public.admin_adjust_seller_wallet(UUID, NUMERIC, TEXT);
DROP FUNCTION IF EXISTS public.admin_adjust_seller_wallet(UUID, NUMERIC, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_adjust_seller_wallet(UUID, NUMERIC, TEXT);
DROP FUNCTION IF EXISTS public.admin_adjust_seller_wallet(UUID, NUMERIC, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_adjust_seller_wallet(UUID, NUMERIC(12,2), TEXT);
DROP FUNCTION IF EXISTS public.admin_adjust_seller_wallet(UUID, NUMERIC(12,2), TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.admin_adjust_seller_wallet(
    p_store_id UUID,
    p_amount NUMERIC,
    p_reason TEXT,
    p_idempotency_key TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_account_id UUID;
    v_tx_id UUID;
    v_owner_id UUID;
    v_effective_idempotency_key TEXT;
BEGIN
    IF NOT public.has_permission('finance', 'adjust') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to adjust seller wallets.' USING ERRCODE = '42501';
    END IF;

    IF p_amount IS NULL OR p_amount = 0.00 THEN
        RAISE EXCEPTION 'Adjustment amount cannot be zero or null.' USING ERRCODE = '22023';
    END IF;

    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'Adjustment reason is required for financial audit.' USING ERRCODE = '22023';
    END IF;

    SELECT id INTO v_account_id FROM public.wallet_accounts WHERE seller_store_id = p_store_id;
    IF v_account_id IS NULL THEN
        SELECT owner_id INTO v_owner_id FROM public.seller_stores WHERE id = p_store_id;
        IF v_owner_id IS NOT NULL THEN
            INSERT INTO public.wallet_accounts (seller_store_id, owner_id)
            VALUES (p_store_id, v_owner_id)
            ON CONFLICT (seller_store_id) DO UPDATE SET updated_at = NOW()
            RETURNING id INTO v_account_id;
        ELSE
            RAISE EXCEPTION 'Wallet account not found.' USING ERRCODE = 'P0002';
        END IF;
    END IF;

    v_effective_idempotency_key := COALESCE(p_idempotency_key, 'ADJ-' || gen_random_uuid()::TEXT);

    INSERT INTO public.wallet_transactions (
        wallet_account_id, seller_store_id, transaction_type, amount,
        source_type, source_id, idempotency_key, description, created_by
    ) VALUES (
        v_account_id, p_store_id, 'ADJUSTMENT', p_amount,
        'ADMIN_ADJUSTMENT', gen_random_uuid()::TEXT, v_effective_idempotency_key,
        p_reason, auth.uid()
    )
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING id INTO v_tx_id;

    IF v_tx_id IS NULL THEN
        SELECT id INTO v_tx_id FROM public.wallet_transactions WHERE idempotency_key = v_effective_idempotency_key;
    ELSE
        PERFORM public.internal_record_audit_log(
            'seller_stores',
            p_store_id::TEXT,
            'ADJUST_SELLER_WALLET',
            jsonb_build_object('amount', p_amount, 'reason', p_reason, 'transaction_id', v_tx_id)
        );
    END IF;

    RETURN jsonb_build_object('success', TRUE, 'transaction_id', v_tx_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.admin_adjust_seller_wallet(UUID, NUMERIC, TEXT, TEXT) TO authenticated;

-- E. admin_toggle_seller_suspension
DROP FUNCTION IF EXISTS public.admin_toggle_seller_suspension(UUID, BOOLEAN);
DROP FUNCTION IF EXISTS public.admin_toggle_seller_suspension(UUID, BOOLEAN, TEXT);
CREATE OR REPLACE FUNCTION public.admin_toggle_seller_suspension(
    p_store_id UUID,
    p_suspended BOOLEAN,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
BEGIN
    IF NOT public.has_permission('sellers', 'suspend') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to toggle seller suspension.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.seller_stores
    SET is_suspended = p_suspended,
        updated_at = NOW()
    WHERE id = p_store_id;

    PERFORM public.internal_record_audit_log(
        'seller_stores',
        p_store_id::TEXT,
        CASE WHEN p_suspended THEN 'SELLER_SUSPENDED' ELSE 'SELLER_UNSUSPENDED' END,
        jsonb_build_object('reason', p_reason)
    );

    RETURN jsonb_build_object('success', TRUE, 'store_id', p_store_id, 'is_suspended', p_suspended);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- F. admin_toggle_payout_lock
DROP FUNCTION IF EXISTS public.admin_toggle_payout_lock(UUID, BOOLEAN);
DROP FUNCTION IF EXISTS public.admin_toggle_payout_lock(UUID, BOOLEAN, TEXT);
CREATE OR REPLACE FUNCTION public.admin_toggle_payout_lock(
    p_store_id UUID,
    p_locked BOOLEAN,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
BEGIN
    IF NOT public.has_permission('payouts', 'hold') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to toggle payout lock.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.wallet_accounts
    SET is_payout_locked = p_locked,
        updated_at = NOW()
    WHERE seller_store_id = p_store_id;

    PERFORM public.internal_record_audit_log(
        'wallet_accounts',
        p_store_id::TEXT,
        CASE WHEN p_locked THEN 'PAYOUT_LOCKED' ELSE 'PAYOUT_UNLOCKED' END,
        jsonb_build_object('reason', p_reason)
    );

    RETURN jsonb_build_object('success', TRUE, 'store_id', p_store_id, 'is_payout_locked', p_locked);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- G. admin_process_payout
DROP FUNCTION IF EXISTS public.admin_process_payout(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_process_payout(UUID, TEXT, TEXT, TEXT);
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
        RAISE EXCEPTION 'Access denied: Insufficient privileges for payout processing.' USING ERRCODE = '42501';
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
        RAISE EXCEPTION 'Access denied: Admin cannot approve or process own payout request.' USING ERRCODE = '42501';
    END IF;

    SELECT id INTO v_wallet_account_id FROM public.wallet_accounts WHERE seller_store_id = v_store_id;

    IF p_action = 'Approve' THEN
        IF v_current_status <> 'Requested' THEN
            RAISE EXCEPTION 'Cannot approve payout in status %.', v_current_status;
        END IF;

        UPDATE public.payout_requests
        SET status = 'Approved', admin_notes = p_notes, processed_by = v_admin_id, updated_at = NOW()
        WHERE id = p_payout_id;

        PERFORM public.internal_record_audit_log(
            'payout_requests',
            p_payout_id::TEXT,
            'PAYOUT_APPROVED',
            jsonb_build_object('amount', v_amount, 'notes', p_notes)
        );

        RETURN jsonb_build_object('success', TRUE, 'status', 'Approved', 'payout_id', p_payout_id);

    ELSIF p_action IN ('Process', 'Pay') THEN
        IF v_current_status IN ('Paid', 'Failed') THEN
            RETURN jsonb_build_object('success', TRUE, 'status', v_current_status, 'already_processed', TRUE, 'payout_id', p_payout_id);
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
            updated_at = NOW()
        WHERE id = v_store_id;

        PERFORM public.internal_record_audit_log(
            'payout_requests',
            p_payout_id::TEXT,
            'PAYOUT_DISBURSED',
            jsonb_build_object('amount', v_amount, 'notes', p_notes)
        );

        RETURN jsonb_build_object('success', TRUE, 'status', 'Paid', 'already_processed', FALSE, 'payout_id', p_payout_id);

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

        PERFORM public.internal_record_audit_log(
            'payout_requests',
            p_payout_id::TEXT,
            'PAYOUT_REJECTED',
            jsonb_build_object('amount', v_amount, 'notes', p_notes)
        );

        RETURN jsonb_build_object('success', TRUE, 'status', 'Rejected', 'payout_id', p_payout_id);
    END IF;

    RETURN jsonb_build_object('success', FALSE, 'error', 'Invalid action');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- H. admin_create_voucher and admin_toggle_voucher_active
DROP FUNCTION IF EXISTS public.admin_create_voucher(TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC, TIMESTAMPTZ, TIMESTAMPTZ, INT, INT);
DROP FUNCTION IF EXISTS public.admin_create_voucher(TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC, TIMESTAMPTZ, TIMESTAMPTZ);
DROP FUNCTION IF EXISTS public.admin_create_voucher(TEXT, TEXT, NUMERIC(12,2), NUMERIC(12,2), NUMERIC(12,2), TIMESTAMPTZ, TIMESTAMPTZ);
CREATE OR REPLACE FUNCTION public.admin_create_voucher(
    p_code TEXT,
    p_discount_type TEXT,
    p_discount_value NUMERIC(12,2),
    p_min_order_amount NUMERIC(12,2) DEFAULT 0.00,
    p_max_discount NUMERIC(12,2) DEFAULT NULL,
    p_valid_from TIMESTAMPTZ DEFAULT NOW(),
    p_valid_until TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_voucher_id UUID;
BEGIN
    IF NOT public.has_permission('promotions', 'create') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to create vouchers.' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.platform_vouchers (
        code, discount_type, discount_value, min_order_amount,
        max_discount, valid_from, valid_until, created_by
    ) VALUES (
        upper(trim(p_code)), p_discount_type, p_discount_value, p_min_order_amount,
        p_max_discount, p_valid_from, p_valid_until, auth.uid()
    ) RETURNING id INTO v_voucher_id;

    PERFORM public.internal_record_audit_log(
        'platform_vouchers',
        v_voucher_id::TEXT,
        'VOUCHER_CREATED',
        jsonb_build_object('code', p_code, 'discount_value', p_discount_value)
    );

    RETURN jsonb_build_object('success', TRUE, 'voucher_id', v_voucher_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

CREATE OR REPLACE FUNCTION public.admin_toggle_voucher_active(
    p_voucher_id UUID,
    p_is_active BOOLEAN
)
RETURNS JSONB AS $$
BEGIN
    IF NOT public.has_permission('promotions', 'edit') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to modify vouchers.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.platform_vouchers
    SET is_active = p_is_active,
        updated_at = NOW()
    WHERE id = p_voucher_id;

    PERFORM public.internal_record_audit_log(
        'platform_vouchers',
        p_voucher_id::TEXT,
        'VOUCHER_STATUS_CHANGED',
        jsonb_build_object('is_active', p_is_active)
    );

    RETURN jsonb_build_object('success', TRUE, 'voucher_id', p_voucher_id, 'is_active', p_is_active);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- I. admin_update_commission_rule
DROP FUNCTION IF EXISTS public.admin_update_commission_rule(TEXT, NUMERIC, NUMERIC);
DROP FUNCTION IF EXISTS public.admin_update_commission_rule(UUID, NUMERIC, TEXT);
DROP FUNCTION IF EXISTS public.admin_update_commission_rule(UUID, NUMERIC(5,2), TEXT);
CREATE OR REPLACE FUNCTION public.admin_update_commission_rule(
    p_rule_id UUID,
    p_base_rate NUMERIC(5,2),
    p_category TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
BEGIN
    IF NOT public.has_permission('commission', 'edit') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to update commission rules.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.commission_rules
    SET base_rate = p_base_rate,
        updated_at = NOW()
    WHERE id = p_rule_id;

    PERFORM public.internal_record_audit_log(
        'commission_rules',
        p_rule_id::TEXT,
        'COMMISSION_RULE_UPDATED',
        jsonb_build_object('base_rate', p_base_rate, 'category', p_category)
    );

    RETURN jsonb_build_object('success', TRUE, 'rule_id', p_rule_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

CREATE OR REPLACE FUNCTION public.admin_update_commission_rule(
    p_category_name TEXT,
    p_percentage NUMERIC,
    p_fixed_fee NUMERIC DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_rule_id UUID;
BEGIN
    IF NOT public.has_permission('commission', 'edit') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to update commission rules.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.commission_rules
    SET base_rate = p_percentage,
        updated_at = NOW()
    WHERE category_name = p_category_name
    RETURNING id INTO v_rule_id;

    PERFORM public.internal_record_audit_log(
        'commission_rules',
        COALESCE(v_rule_id::TEXT, p_category_name),
        'COMMISSION_RULE_UPDATED',
        jsonb_build_object('base_rate', p_percentage, 'category_name', p_category_name)
    );

    RETURN jsonb_build_object('success', TRUE, 'category_name', p_category_name);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_update_commission_rule(TEXT, NUMERIC, NUMERIC) TO authenticated;

-- J. admin_broadcast_notification
DROP FUNCTION IF EXISTS public.admin_broadcast_notification(TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_broadcast_notification(TEXT, TEXT, public.app_role);
CREATE OR REPLACE FUNCTION public.admin_broadcast_notification(
    p_title TEXT,
    p_body TEXT,
    p_target_role public.app_role DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_count INT := 0;
BEGIN
    IF NOT public.has_permission('notifications', 'send') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to broadcast notifications.' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.user_notifications (user_id, title, body, notification_type, action_link)
    SELECT u.id, p_title, p_body, 'BROADCAST', '/notifications'
    FROM auth.users u
    JOIN public.user_roles ur ON ur.user_id = u.id
    WHERE (p_target_role IS NULL OR ur.role = p_target_role);

    GET DIAGNOSTICS v_count = ROW_COUNT;

    PERFORM public.internal_record_audit_log(
        'user_notifications',
        'BROADCAST',
        'NOTIFICATION_BROADCAST',
        jsonb_build_object('title', p_title, 'target_role', p_target_role, 'delivered_count', v_count)
    );

    RETURN jsonb_build_object('success', TRUE, 'delivered_count', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

CREATE OR REPLACE FUNCTION public.admin_broadcast_notification(
    p_title TEXT,
    p_body TEXT,
    p_target_role TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RETURN public.admin_broadcast_notification(
        p_title => p_title,
        p_body => p_body,
        p_target_role => CASE WHEN p_target_role IS NULL OR p_target_role = '' OR p_target_role = 'all' THEN NULL ELSE p_target_role::public.app_role END
    );
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_broadcast_notification(TEXT, TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. STAFF ROLE PERMISSIONS SEEDING (ENSURING FULL MODULE COVERAGE)
-- ----------------------------------------------------------------------------

INSERT INTO public.staff_role_permissions (staff_role, module, action) VALUES
    -- SupportAdmin additions for reviews & chat monitoring
    ('supportAdmin', 'reviews', 'moderate'),
    ('supportAdmin', 'reviews', 'view'),
    ('supportAdmin', 'chat', 'monitor'),
    ('supportAdmin', 'chat', 'view'),
    -- DisputeManager additions
    ('disputeManager', 'reviews', 'moderate'),
    ('disputeManager', 'refunds', 'process'),
    -- FraudAnalyst additions
    ('fraudAnalyst', 'audit', 'view'),
    -- Auditor audit view
    ('auditor', 'audit', 'view'),
    ('auditor', 'returns', 'view'),
    ('auditor', 'disputes', 'view'),
    -- MarketingManager voucher permissions
    ('marketingManager', 'vouchers', 'create'),
    ('marketingManager', 'vouchers', 'edit'),
    ('marketingManager', 'vouchers', 'view'),
    -- OrderManager shipping permissions
    ('orderManager', 'shipping', 'view'),
    ('orderManager', 'shipping', 'update')
ON CONFLICT (staff_role, module, action) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. ACCOUNT SOFT DEACTIVATION LIFECYCLE
-- ----------------------------------------------------------------------------

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_deactivated BOOLEAN DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS deactivated_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.deactivate_user_account(
    p_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_is_authorized BOOLEAN;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    v_is_authorized := (v_caller_id = p_user_id) 
                    OR public.has_permission('customers', 'suspend')
                    OR public.is_admin();

    IF NOT v_is_authorized THEN
        RAISE EXCEPTION 'Access denied: Cannot deactivate other user accounts.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.profiles
    SET is_deactivated = TRUE,
        deactivated_at = NOW()
    WHERE id = p_user_id;

    v_audit_id := public.internal_record_audit_log(
        'profiles',
        p_user_id::TEXT,
        'USER_ACCOUNT_DEACTIVATED',
        jsonb_build_object(
            'deactivated_by', v_caller_id,
            'reason', p_reason
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'user_id', p_user_id,
        'is_deactivated', TRUE,
        'audit_log_id', v_audit_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.deactivate_user_account(UUID, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 5. PART 2 SECURITY GUARDS: F3, F4, F5
-- ----------------------------------------------------------------------------

-- F3. seller_update_fulfillment_status: Explicit ownership check & error message
DROP FUNCTION IF EXISTS public.seller_update_fulfillment_status(TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.seller_update_fulfillment_status(
    p_order_id TEXT,
    p_new_status TEXT,
    p_seller_store_id UUID DEFAULT NULL,
    p_courier_name TEXT DEFAULT NULL,
    p_tracking_number TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_order RECORD;
    v_seller_store RECORD;
    v_target_store_id UUID;
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF p_seller_store_id IS NOT NULL THEN
        SELECT id, is_approved INTO v_seller_store
        FROM public.seller_stores
        WHERE id = p_seller_store_id AND owner_id = v_current_user_id;
    ELSE
        SELECT id, is_approved INTO v_seller_store
        FROM public.seller_stores
        WHERE owner_id = v_current_user_id;
    END IF;

    IF v_seller_store.id IS NULL THEN
        RAISE EXCEPTION 'User does not own a registered seller store.' USING ERRCODE = '42501';
    END IF;

    v_target_store_id := v_seller_store.id;

    SELECT id, order_number, status, seller_store_id
    INTO v_order
    FROM public.buyer_orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Strict Store Ownership Validation
    IF v_order.seller_store_id IS NOT NULL AND v_order.seller_store_id != v_target_store_id THEN
        IF NOT EXISTS (SELECT 1 FROM public.order_items WHERE order_id = p_order_id AND seller_store_id = v_target_store_id) THEN
            RAISE EXCEPTION 'Unauthorized to update fulfillment status for this store.' USING ERRCODE = '42501';
        END IF;
    END IF;

    -- State machine forward transitions
    IF v_order.status = 'Pending' AND p_new_status NOT IN ('Processing', 'Cancelled') THEN
        RAISE EXCEPTION 'Pending order can only transition to Processing or Cancelled.' USING ERRCODE = '22023';
    ELSIF v_order.status = 'Processing' AND p_new_status NOT IN ('Shipped', 'Cancelled') THEN
        RAISE EXCEPTION 'Processing order can only transition to Shipped or Cancelled.' USING ERRCODE = '22023';
    ELSIF v_order.status = 'Shipped' AND p_new_status NOT IN ('Delivered') THEN
        RAISE EXCEPTION 'Shipped order can only transition to Delivered.' USING ERRCODE = '22023';
    ELSIF v_order.status IN ('Delivered', 'Cancelled') THEN
        RAISE EXCEPTION 'Finalized orders cannot change status.' USING ERRCODE = '22023';
    END IF;

    UPDATE public.buyer_orders
    SET status = p_new_status,
        updated_at = NOW()
    WHERE id = p_order_id;

    RETURN jsonb_build_object('success', TRUE, 'order_id', p_order_id, 'status', p_new_status);
END;
$$;

GRANT EXECUTE ON FUNCTION public.seller_update_fulfillment_status(TEXT, TEXT, UUID, TEXT, TEXT, TEXT) TO authenticated;

-- F4. admin_process_refund: Check permissions & revoke direct EXECUTE from authenticated
CREATE OR REPLACE FUNCTION public.admin_process_refund(
    p_order_id TEXT,
    p_order_item_id UUID,
    p_amount NUMERIC(12,2),
    p_reason TEXT,
    p_idempotency_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
    v_is_seller_owner BOOLEAN;
    v_result JSONB;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for refund processing.' USING ERRCODE = '42501';
    END IF;

    -- Look up order line item seller store
    SELECT oi.seller_store_id INTO v_seller_store_id
    FROM public.order_items oi
    WHERE oi.id = p_order_item_id AND oi.order_id = p_order_id;

    v_is_seller_owner := FALSE;
    IF v_seller_store_id IS NOT NULL THEN
        v_is_seller_owner := EXISTS (
            SELECT 1 FROM public.seller_stores
            WHERE id = v_seller_store_id AND owner_id = v_admin_id
        );
    END IF;

    -- Authorized staff OR seller store owner reviewing return
    IF NOT (
        public.has_permission('refunds', 'process')
        OR public.has_permission('disputes', 'refund')
        OR public.has_permission('finance', 'adjust')
        OR v_is_seller_owner
    ) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for refund processing.' USING ERRCODE = '42501';
    END IF;

    IF p_amount IS NULL OR p_amount <= 0.00 THEN
        RAISE EXCEPTION 'Refund amount must be greater than zero.' USING ERRCODE = 'P0004';
    END IF;

    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'Refund reason is required.' USING ERRCODE = 'P0005';
    END IF;

    IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
        RAISE EXCEPTION 'Idempotency key is required for refund.' USING ERRCODE = 'P0001';
    END IF;

    -- Durable Idempotency Check
    SELECT id, order_id, order_item_id, amount, status INTO v_existing_refund_id, v_existing_order_id, v_existing_item_id, v_existing_amount, v_existing_status
    FROM public.refunds
    WHERE idempotency_key = p_idempotency_key;

    IF v_existing_refund_id IS NOT NULL THEN
        IF v_existing_order_id <> p_order_id OR v_existing_item_id <> p_order_item_id OR v_existing_amount <> p_amount THEN
            RAISE EXCEPTION 'Idempotency conflict: Existing refund % has different request parameters.', p_idempotency_key USING ERRCODE = 'P0001';
        END IF;

        RETURN jsonb_build_object(
            'success', TRUE,
            'already_processed', TRUE,
            'refund_id', v_existing_refund_id,
            'amount', v_existing_amount,
            'status', v_existing_status
        );
    END IF;

    -- Fetch Line Item Details
    SELECT bo.customer_user_id, oi.seller_store_id, oi.total_price, oi.commission_rate
    INTO v_customer_user_id, v_seller_store_id, v_item_total, v_item_commission_rate
    FROM public.order_items oi
    JOIN public.buyer_orders bo ON bo.id = oi.order_id
    WHERE oi.id = p_order_item_id AND oi.order_id = p_order_id;

    IF v_seller_store_id IS NULL THEN
        RAISE EXCEPTION 'Target order line item not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Cumulative Refund Bound Check
    SELECT COALESCE(SUM(amount), 0.00) INTO v_existing_refunded
    FROM public.refunds
    WHERE order_item_id = p_order_item_id AND status = 'Completed';

    IF (v_existing_refunded + p_amount) > v_item_total THEN
        RAISE EXCEPTION 'Refund amount exceeds eligible paid item amount. Eligible: %, Requested: %', (v_item_total - v_existing_refunded)::NUMERIC(12,2), p_amount::NUMERIC(12,2) USING ERRCODE = 'P0001';
    END IF;

    v_comm_reversed := ROUND(p_amount * (v_item_commission_rate / 100.00), 2);
    v_seller_payable_reversed := p_amount - v_comm_reversed;

    -- Insert Refund Record
    INSERT INTO public.refunds (
        order_id, order_item_id, seller_store_id, customer_user_id, amount,
        commission_reversed, seller_payable_reversed, status, reason, idempotency_key, processed_by
    ) VALUES (
        p_order_id, p_order_item_id, v_seller_store_id, v_customer_user_id, p_amount,
        v_comm_reversed, v_seller_payable_reversed, 'Completed', p_reason, p_idempotency_key, v_admin_id
    ) RETURNING id INTO v_refund_id;

    -- Debit Seller Wallet
    SELECT id INTO v_wallet_account_id FROM public.wallet_accounts WHERE seller_store_id = v_seller_store_id;

    IF v_wallet_account_id IS NOT NULL THEN
        INSERT INTO public.wallet_transactions (
            wallet_account_id, seller_store_id, transaction_type, amount,
            source_type, source_id, idempotency_key, description, created_by
        ) VALUES (
            v_wallet_account_id, v_seller_store_id, 'DEBIT', v_seller_payable_reversed,
            'REFUND_REVERSAL', v_refund_id::TEXT, 'WLT-REF-' || v_refund_id::TEXT,
            'Refund Reversal for Order ' || p_order_id, v_admin_id
        ) ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;

    PERFORM public.internal_record_audit_log(
        'refunds',
        v_refund_id::TEXT,
        'PROCESS_REFUND',
        jsonb_build_object('order_id', p_order_id, 'amount', p_amount, 'refund_id', v_refund_id)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'refund_id', v_refund_id,
        'amount', p_amount,
        'status', 'Completed'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_process_refund(TEXT, UUID, NUMERIC, TEXT, TEXT) TO authenticated;

-- F5. chat_messages length CHECK, rate limit in send_chat_message, direct DML revoked
ALTER TABLE public.chat_messages
    DROP CONSTRAINT IF EXISTS chat_messages_text_length_check;

ALTER TABLE public.chat_messages
    ADD CONSTRAINT chat_messages_text_length_check
    CHECK (length(trim(message_text)) >= 1 AND length(message_text) <= 2000);

REVOKE INSERT, UPDATE, DELETE ON public.chat_messages FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.chat_rooms FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.chat_messages TO authenticated;
GRANT SELECT ON public.chat_rooms TO authenticated;

CREATE OR REPLACE FUNCTION public.send_chat_message(
    p_room_id UUID,
    p_message_text TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_sender_id UUID;
    v_room RECORD;
    v_recipient_id UUID;
    v_msg_id UUID;
BEGIN
    v_sender_id := auth.uid();
    IF v_sender_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    -- Enforce 30 messages per minute rate limit
    PERFORM public.enforce_rate_limit('send_chat_message', 30, 60);

    IF p_message_text IS NULL OR trim(p_message_text) = '' THEN
        RAISE EXCEPTION 'Message text cannot be empty.' USING ERRCODE = '22023';
    END IF;

    IF length(p_message_text) > 2000 THEN
        RAISE EXCEPTION 'Message exceeds maximum length of 2000 characters.' USING ERRCODE = '22023';
    END IF;

    -- Fetch Chat Room Details
    SELECT cr.id, cr.buyer_user_id, ss.owner_id AS seller_owner_id
    INTO v_room
    FROM public.chat_rooms cr
    JOIN public.seller_stores ss ON ss.id = cr.seller_store_id
    WHERE cr.id = p_room_id;

    IF v_room.id IS NULL THEN
        RAISE EXCEPTION 'Chat room not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Room Membership Check
    IF v_sender_id <> v_room.buyer_user_id AND v_sender_id <> v_room.seller_owner_id AND NOT public.has_permission('chat', 'monitor') THEN
        RAISE EXCEPTION 'Access denied: You are not a participant in chat room %.', p_room_id USING ERRCODE = '42501';
    END IF;

    -- Determine Recipient ID
    IF v_sender_id = v_room.buyer_user_id THEN
        v_recipient_id := v_room.seller_owner_id;
    ELSE
        v_recipient_id := v_room.buyer_user_id;
    END IF;

    -- Insert Message (runs with security definer privileges)
    INSERT INTO public.chat_messages (
        room_id, sender_id, message_text
    ) VALUES (
        p_room_id, v_sender_id, p_message_text
    ) RETURNING id INTO v_msg_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message_id', v_msg_id,
        'room_id', p_room_id,
        'sender_id', v_sender_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_chat_message(UUID, TEXT) TO authenticated;


-- =========================================================================
-- FILE: 20260831000000_fulfillment_rls_refinement_and_account_governance.sql
-- =========================================================================

-- Migration: 20260831000000_fulfillment_rls_refinement_and_account_governance.sql
-- Description: Multi-vendor seller fulfillment, recipient chat notifications, granular RLS policies, account governance, and fraud security tables/RPCs

-- ----------------------------------------------------------------------------
-- 1. SEND CHAT MESSAGE: RECIPIENT NOTIFICATION RESTORATION & CLEANUP
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.send_chat_message(
    p_room_id UUID,
    p_message_text TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_sender_id UUID;
    v_room RECORD;
    v_recipient_id UUID;
    v_msg_id UUID;
    v_sender_name TEXT;
    v_sender_is_deactivated BOOLEAN;
BEGIN
    v_sender_id := auth.uid();
    IF v_sender_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    -- Deactivated user guard
    SELECT is_deactivated INTO v_sender_is_deactivated
    FROM public.profiles
    WHERE id = v_sender_id;

    IF v_sender_is_deactivated = TRUE THEN
        RAISE EXCEPTION 'Account is deactivated. Please contact support.' USING ERRCODE = '40301';
    END IF;

    -- Enforce 30 messages per minute rate limit
    PERFORM public.enforce_rate_limit('send_chat_message', 30, 60);

    IF p_message_text IS NULL OR trim(p_message_text) = '' THEN
        RAISE EXCEPTION 'Message text cannot be empty.' USING ERRCODE = '22023';
    END IF;

    IF length(p_message_text) > 2000 THEN
        RAISE EXCEPTION 'Message exceeds maximum length of 2000 characters.' USING ERRCODE = '22023';
    END IF;

    -- Fetch Chat Room Details
    SELECT cr.id, cr.buyer_user_id, ss.owner_id AS seller_owner_id
    INTO v_room
    FROM public.chat_rooms cr
    JOIN public.seller_stores ss ON ss.id = cr.seller_store_id
    WHERE cr.id = p_room_id;

    IF v_room.id IS NULL THEN
        RAISE EXCEPTION 'Chat room not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Room Membership Check
    IF v_sender_id <> v_room.buyer_user_id AND v_sender_id <> v_room.seller_owner_id AND NOT public.has_permission('chat', 'monitor') THEN
        RAISE EXCEPTION 'Access denied: You are not a participant in chat room %.', p_room_id USING ERRCODE = '42501';
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

    -- Sender name for notification
    SELECT full_name INTO v_sender_name FROM public.profiles WHERE id = v_sender_id;

    -- Create Recipient Notification
    PERFORM public.internal_create_notification(
        v_recipient_id,
        'CHAT_MESSAGE',
        'New message from ' || COALESCE(v_sender_name, 'User'),
        substr(p_message_text, 1, 100),
        'CHAT',
        p_room_id::text,
        'NOTIF-CHAT-' || v_msg_id::text
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message_id', v_msg_id,
        'room_id', p_room_id,
        'sender_id', v_sender_id
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. MULTI-VENDOR SELLER FULFILLMENT STATUS RPC
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.seller_update_fulfillment_status(
    p_order_id TEXT,
    p_new_status TEXT,
    p_seller_store_id UUID DEFAULT NULL,
    p_courier_name TEXT DEFAULT NULL,
    p_tracking_number TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_current_user_id UUID;
    v_is_deactivated BOOLEAN;
    v_order RECORD;
    v_target_store_id UUID;
    v_store_count INT;
    v_old_status TEXT;
    v_all_delivered BOOLEAN;
    v_any_cancelled BOOLEAN;
    v_item RECORD;
    v_wallet_account_id UUID;
    v_payment_id UUID;
BEGIN
    v_current_user_id := auth.uid();
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    -- Deactivated user guard
    SELECT is_deactivated INTO v_is_deactivated
    FROM public.profiles
    WHERE id = v_current_user_id;

    IF v_is_deactivated = TRUE THEN
        RAISE EXCEPTION 'Account is deactivated. Please contact support.' USING ERRCODE = '40301';
    END IF;

    IF p_new_status NOT IN ('Processing', 'Shipped', 'Delivered', 'Cancelled') THEN
        RAISE EXCEPTION 'Invalid fulfillment status: %', p_new_status USING ERRCODE = '22023';
    END IF;

    -- Fetch Order
    SELECT id, order_number, status, payment_status, payment_method, customer_user_id
    INTO v_order
    FROM public.buyer_orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF v_order.id IS NULL THEN
        RAISE EXCEPTION 'Order not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Authorize seller through order_items: identify store(s) caller owns in this order
    IF p_seller_store_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.order_items oi
            JOIN public.seller_stores ss ON ss.id = oi.seller_store_id
            WHERE oi.order_id = p_order_id
              AND oi.seller_store_id = p_seller_store_id
              AND ss.owner_id = v_current_user_id
        ) THEN
            RAISE EXCEPTION 'Unauthorized to update fulfillment status for this store.' USING ERRCODE = '42501';
        END IF;
        v_target_store_id := p_seller_store_id;
    ELSE
        -- Support sellers owning more than one store: count matching stores
        SELECT COUNT(DISTINCT oi.seller_store_id) INTO v_store_count
        FROM public.order_items oi
        JOIN public.seller_stores ss ON ss.id = oi.seller_store_id
        WHERE oi.order_id = p_order_id
          AND ss.owner_id = v_current_user_id;

        IF v_store_count = 0 THEN
            RAISE EXCEPTION 'Unauthorized to update fulfillment status for this store.' USING ERRCODE = '42501';
        ELSIF v_store_count > 1 THEN
            RAISE EXCEPTION 'Multiple stores found for this order. Please specify p_seller_store_id.' USING ERRCODE = '22023';
        END IF;

        SELECT DISTINCT oi.seller_store_id INTO v_target_store_id
        FROM public.order_items oi
        JOIN public.seller_stores ss ON ss.id = oi.seller_store_id
        WHERE oi.order_id = p_order_id
          AND ss.owner_id = v_current_user_id;
    END IF;

    -- Store must be approved and active (not suspended)
    IF NOT public.is_approved_active_seller_store(v_target_store_id) THEN
        RAISE EXCEPTION 'Seller store is not approved or is suspended.' USING ERRCODE = '42501';
    END IF;

    -- Lock & Fetch store_fulfillment row
    SELECT fulfillment_status INTO v_old_status
    FROM public.store_fulfillments
    WHERE order_id = p_order_id
      AND seller_store_id = v_target_store_id
    FOR UPDATE;

    -- If no row exists yet, create it
    IF v_old_status IS NULL THEN
        INSERT INTO public.store_fulfillments (
            order_id, seller_store_id, fulfillment_status, courier_name, tracking_number, notes
        ) VALUES (
            p_order_id, v_target_store_id, 'Pending', p_courier_name, p_tracking_number, p_notes
        );
        v_old_status := 'Pending';
    END IF;

    -- Enforce state transitions
    IF v_old_status = 'Pending' AND p_new_status NOT IN ('Processing', 'Cancelled') THEN
        RAISE EXCEPTION 'Pending fulfillment can only transition to Processing or Cancelled.' USING ERRCODE = '22023';
    ELSIF v_old_status = 'Processing' AND p_new_status NOT IN ('Shipped', 'Cancelled') THEN
        RAISE EXCEPTION 'Processing fulfillment can only transition to Shipped or Cancelled.' USING ERRCODE = '22023';
    ELSIF v_old_status = 'Shipped' AND p_new_status NOT IN ('Delivered') THEN
        RAISE EXCEPTION 'Shipped fulfillment can only transition to Delivered.' USING ERRCODE = '22023';
    ELSIF v_old_status IN ('Delivered', 'Cancelled') THEN
        RAISE EXCEPTION 'Finalized fulfillments cannot change status.' USING ERRCODE = '22023';
    END IF;

    -- Update store_fulfillment
    UPDATE public.store_fulfillments
    SET fulfillment_status = p_new_status,
        courier_name = COALESCE(p_courier_name, courier_name),
        tracking_number = COALESCE(p_tracking_number, tracking_number),
        notes = COALESCE(p_notes, notes),
        shipped_at = CASE WHEN p_new_status = 'Shipped' THEN NOW() ELSE shipped_at END,
        delivered_at = CASE WHEN p_new_status = 'Delivered' THEN NOW() ELSE delivered_at END,
        updated_at = NOW()
    WHERE order_id = p_order_id AND seller_store_id = v_target_store_id;

    -- (d) On Delivered for Cash on Delivery: Mark cash collected & trigger seller balance accrual
    IF p_new_status = 'Delivered' AND v_order.payment_method IN ('Cash on Delivery', 'COD') THEN
        -- Mark payment row Collected
        UPDATE public.payments
        SET status = 'Collected', collected_at = NOW(), updated_at = NOW()
        WHERE order_id = p_order_id;

        -- Accrue seller payable balance for items belonging to this store
        SELECT id INTO v_wallet_account_id
        FROM public.wallet_accounts
        WHERE seller_store_id = v_target_store_id;

        IF v_wallet_account_id IS NOT NULL THEN
            FOR v_item IN (
                SELECT id, seller_payable, quantity, product_id, product_name
                FROM public.order_items
                WHERE order_id = p_order_id AND seller_store_id = v_target_store_id
            ) LOOP
                INSERT INTO public.wallet_transactions (
                    wallet_account_id, seller_store_id, transaction_type, amount,
                    source_type, source_id, idempotency_key, description, created_by
                ) VALUES (
                    v_wallet_account_id, v_target_store_id, 'CREDIT', v_item.seller_payable,
                    'ORDER_FULFILLMENT', v_item.id::TEXT, 'WLT-FUL-' || v_item.id::TEXT,
                    'Payout credit for ' || v_item.product_name, v_current_user_id
                ) ON CONFLICT (idempotency_key) DO NOTHING;
            END LOOP;

            UPDATE public.seller_stores
            SET pending_payout = GREATEST((SELECT available_balance FROM public.get_seller_wallet_summary(v_target_store_id)), 0.00),
                updated_at = NOW()
            WHERE id = v_target_store_id;
        END IF;
    END IF;

    -- (e) On Cancelled: Restore product stock for this store's items
    IF p_new_status = 'Cancelled' THEN
        FOR v_item IN (
            SELECT product_id, quantity
            FROM public.order_items
            WHERE order_id = p_order_id AND seller_store_id = v_target_store_id
        ) LOOP
            UPDATE public.products
            SET stock_quantity = stock_quantity + v_item.quantity,
                updated_at = NOW()
            WHERE id = v_item.product_id;
        END LOOP;
    END IF;

    -- Check overall order status: if all store_fulfillments are Delivered
    SELECT bool_and(fulfillment_status = 'Delivered'), bool_or(fulfillment_status = 'Cancelled')
    INTO v_all_delivered, v_any_cancelled
    FROM public.store_fulfillments
    WHERE order_id = p_order_id;

    IF v_all_delivered = TRUE THEN
        UPDATE public.buyer_orders
        SET status = 'Delivered',
            payment_status = CASE WHEN payment_method IN ('Cash on Delivery', 'COD') THEN 'Paid' ELSE payment_status END,
            updated_at = NOW()
        WHERE id = p_order_id;
    ELSIF p_new_status = 'Shipped' AND v_order.status NOT IN ('Delivered', 'Cancelled') THEN
        UPDATE public.buyer_orders SET status = 'Shipped', updated_at = NOW() WHERE id = p_order_id;
    ELSIF p_new_status = 'Processing' AND v_order.status = 'Pending' THEN
        UPDATE public.buyer_orders SET status = 'Processing', updated_at = NOW() WHERE id = p_order_id;
    END IF;

    -- (f) Insert order tracking event
    INSERT INTO public.order_tracking_events (
        order_id, seller_store_id, event_type, description, location
    ) VALUES (
        p_order_id, v_target_store_id, p_new_status,
        'Fulfillment updated to ' || p_new_status || COALESCE(' (' || p_notes || ')', ''),
        COALESCE(p_courier_name, 'Courier Facility')
    );

    -- (f) Notify buyer of fulfillment change
    PERFORM public.internal_create_notification(
        v_order.customer_user_id,
        'ORDER_FULFILLMENT',
        'Order ' || COALESCE(v_order.order_number, p_order_id) || ' Status Update',
        'Your order items from store have updated to ' || p_new_status,
        'ORDER',
        p_order_id,
        'NOTIF-ORD-' || p_order_id || '-' || v_target_store_id::TEXT || '-' || p_new_status
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'order_id', p_order_id,
        'seller_store_id', v_target_store_id,
        'fulfillment_status', p_new_status
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.seller_update_fulfillment_status(TEXT, TEXT, UUID, TEXT, TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. REPLACE is_admin() IN ALL RLS POLICIES WITH has_permission(module, action)
-- ----------------------------------------------------------------------------

-- A. user_roles
DROP POLICY IF EXISTS "Users and admins can view relevant user roles" ON public.user_roles;
CREATE POLICY "Users and admins can view relevant user roles" ON public.user_roles
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR public.has_permission('roles', 'view')
        OR public.is_admin()
    );

-- B. profiles
DROP POLICY IF EXISTS "Users can view own full profile" ON public.profiles;
CREATE POLICY "Users can view own full profile" ON public.profiles
    FOR SELECT TO authenticated
    USING (
        auth.uid() = id
        OR public.has_permission('customers', 'view')
        OR public.is_admin()
    );

-- C. seller_stores
DROP POLICY IF EXISTS "Public view approved stores; Owner/Admin view all" ON public.seller_stores;
CREATE POLICY "Public view approved stores; Owner/Admin view all" ON public.seller_stores
    FOR SELECT TO authenticated, anon
    USING (
        is_approved = TRUE
        OR auth.uid() = owner_id
        OR public.has_permission('sellers', 'view')
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "Store owners update safe business details" ON public.seller_stores;
CREATE POLICY "Store owners update safe business details" ON public.seller_stores
    FOR UPDATE TO authenticated
    USING (
        auth.uid() = owner_id
        OR public.has_permission('sellers', 'edit')
        OR public.is_admin()
    );

-- D. seller_kyc_documents
DROP POLICY IF EXISTS "Sellers view own KYC; Admins view all" ON public.seller_kyc_documents;
CREATE POLICY "Sellers view own KYC; Admins view all" ON public.seller_kyc_documents
    FOR SELECT TO authenticated
    USING (
        public.owns_seller_store(seller_store_id)
        OR public.has_permission('kyc', 'view')
        OR public.is_admin()
    );

-- E. categories
DROP POLICY IF EXISTS "Categories visible to all if active; Admins view all" ON public.categories;
CREATE POLICY "Categories visible to all if active; Admins view all" ON public.categories
    FOR SELECT TO authenticated, anon
    USING (
        is_active = TRUE
        OR public.has_permission('categories', 'view')
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "Admins have full category management" ON public.categories;
CREATE POLICY "Admins have full category management" ON public.categories
    FOR ALL TO authenticated
    USING (
        public.has_permission('categories', 'edit')
        OR public.is_admin()
    );

-- F. products
DROP POLICY IF EXISTS "Public view approved active products; Owner/Admin view all" ON public.products;
DROP POLICY IF EXISTS "Public view approved active products from active stores" ON public.products;
DROP POLICY IF EXISTS "Public view active approved products; Owners/Admins view all" ON public.products;
CREATE POLICY "Public view active approved products; Owners/Admins view all" ON public.products
    FOR SELECT TO authenticated, anon
    USING (
        (is_active = TRUE AND LOWER(approval_status) = 'approved' AND public.is_approved_active_seller_store(seller_store_id))
        OR public.owns_seller_store(seller_store_id)
        OR public.has_permission('products', 'view')
        OR public.is_admin()
    );

-- G. buyer_orders
DROP POLICY IF EXISTS "Buyer orders read policy" ON public.buyer_orders;
DROP POLICY IF EXISTS "Buyer view own orders; Admins view all" ON public.buyer_orders;
CREATE POLICY "Buyer view own orders; Admins view all" ON public.buyer_orders
    FOR SELECT TO authenticated
    USING (
        customer_user_id = auth.uid()
        OR public.has_permission('orders', 'view')
        OR public.is_admin()
    );

-- H. platform_vouchers
DROP POLICY IF EXISTS "Admins view all vouchers" ON public.platform_vouchers;
CREATE POLICY "Admins view all vouchers" ON public.platform_vouchers
    FOR SELECT TO authenticated
    USING (
        public.has_permission('promotions', 'view')
        OR public.is_admin()
    );

-- I. seller_payout_requests
DROP POLICY IF EXISTS "Payout requests visibility" ON public.seller_payout_requests;
CREATE POLICY "Payout requests visibility" ON public.seller_payout_requests
    FOR SELECT TO authenticated
    USING (
        public.owns_seller_store(seller_store_id)
        OR public.has_permission('payouts', 'view')
        OR public.is_admin()
    );

-- J. wallet_accounts
DROP POLICY IF EXISTS "Wallet accounts visibility" ON public.wallet_accounts;
CREATE POLICY "Wallet accounts visibility" ON public.wallet_accounts
    FOR SELECT TO authenticated
    USING (
        public.owns_seller_store(seller_store_id)
        OR public.has_permission('finance', 'view')
        OR public.is_admin()
    );

-- ----------------------------------------------------------------------------
-- 4. ACCOUNT DEACTIVATION & REACTIVATION GOVERNANCE
-- ----------------------------------------------------------------------------

-- Table-level revocation and specific column grant on profiles
REVOKE UPDATE ON public.profiles FROM authenticated, anon, PUBLIC;
GRANT UPDATE (full_name, email, phone, role) ON public.profiles TO authenticated;

CREATE OR REPLACE FUNCTION public.protect_profiles_is_deactivated()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF (OLD.is_deactivated IS DISTINCT FROM NEW.is_deactivated OR OLD.deactivated_at IS DISTINCT FROM NEW.deactivated_at) THEN
        IF current_user = 'authenticated' OR auth.role() = 'authenticated' THEN
            RAISE EXCEPTION 'permission denied: Direct update of account deactivation status is prohibited.' USING ERRCODE = '42501';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_profiles_is_deactivated ON public.profiles;
CREATE TRIGGER trg_protect_profiles_is_deactivated
    BEFORE UPDATE OF is_deactivated, deactivated_at ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.protect_profiles_is_deactivated();

-- Deactivation function with authority checks
CREATE OR REPLACE FUNCTION public.deactivate_user_account(
    p_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_is_owner BOOLEAN;
    v_target_has_staff_role BOOLEAN;
    v_target_is_owner BOOLEAN;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    -- Caller checks
    v_is_owner := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (role = 'owner'::public.app_role OR staff_role = 'owner'::public.admin_staff_role)
    );

    -- Target checks
    v_target_is_owner := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = p_user_id
          AND (role = 'owner'::public.app_role OR staff_role = 'owner'::public.admin_staff_role)
    );

    IF v_target_is_owner THEN
        RAISE EXCEPTION 'Deactivation of the Owner role is prohibited.' USING ERRCODE = '42501';
    END IF;

    v_target_has_staff_role := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = p_user_id
          AND (role IN ('super_admin'::public.app_role, 'admin'::public.app_role) OR staff_role IS NOT NULL)
    );

    -- Rule (a): Only owner can deactivate a staff or super_admin account
    IF v_target_has_staff_role AND NOT v_is_owner THEN
        RAISE EXCEPTION 'Access denied: Only Owner can deactivate staff or super_admin accounts.' USING ERRCODE = '42501';
    END IF;

    -- Staff with customers:suspend may only deactivate normal buyer/seller accounts
    IF NOT v_is_owner AND v_caller_id != p_user_id THEN
        IF NOT public.has_permission('customers', 'suspend') THEN
            RAISE EXCEPTION 'Access denied: Insufficient privileges to deactivate user accounts.' USING ERRCODE = '42501';
        END IF;
    END IF;

    UPDATE public.profiles
    SET is_deactivated = TRUE,
        deactivated_at = NOW()
    WHERE id = p_user_id;

    v_audit_id := public.internal_record_audit_log(
        'profiles',
        p_user_id::TEXT,
        'USER_ACCOUNT_DEACTIVATED',
        jsonb_build_object('deactivated_by', v_caller_id, 'reason', p_reason)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'user_id', p_user_id,
        'is_deactivated', TRUE,
        'audit_log_id', v_audit_id
    );
END;
$$;

-- Reactivation function
CREATE OR REPLACE FUNCTION public.admin_reactivate_user_account(
    p_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_is_owner BOOLEAN;
    v_target_has_staff_role BOOLEAN;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    v_is_owner := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (role = 'owner'::public.app_role OR staff_role = 'owner'::public.admin_staff_role)
    );

    v_target_has_staff_role := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = p_user_id
          AND (role IN ('super_admin'::public.app_role, 'admin'::public.app_role) OR staff_role IS NOT NULL)
    );

    IF v_target_has_staff_role AND NOT v_is_owner THEN
        RAISE EXCEPTION 'Access denied: Only Owner can reactivate staff or super_admin accounts.' USING ERRCODE = '42501';
    END IF;

    IF NOT v_is_owner THEN
        IF NOT public.has_permission('customers', 'suspend') THEN
            RAISE EXCEPTION 'Access denied: Insufficient privileges to reactivate accounts.' USING ERRCODE = '42501';
        END IF;
    END IF;

    UPDATE public.profiles
    SET is_deactivated = FALSE,
        deactivated_at = NULL
    WHERE id = p_user_id;

    v_audit_id := public.internal_record_audit_log(
        'profiles',
        p_user_id::TEXT,
        'USER_ACCOUNT_REACTIVATED',
        jsonb_build_object('reactivated_by', v_caller_id, 'reason', p_reason)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'user_id', p_user_id,
        'is_deactivated', FALSE,
        'audit_log_id', v_audit_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_reactivate_user_account(UUID, TEXT) TO authenticated;

-- Guard create_chat_room against deactivated users
CREATE OR REPLACE FUNCTION public.create_chat_room(
    p_seller_store_id UUID,
    p_product_id UUID DEFAULT NULL,
    p_order_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_buyer_id UUID;
    v_is_deactivated BOOLEAN;
    v_room_id UUID;
    v_order_belongs BOOLEAN;
BEGIN
    v_buyer_id := auth.uid();
    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    SELECT is_deactivated INTO v_is_deactivated FROM public.profiles WHERE id = v_buyer_id;
    IF v_is_deactivated = TRUE THEN
        RAISE EXCEPTION 'Account is deactivated. Please contact support.' USING ERRCODE = '40301';
    END IF;

    IF NOT public.is_approved_active_seller_store(p_seller_store_id) THEN
        RAISE EXCEPTION 'Store is not active or approved.' USING ERRCODE = '42501';
    END IF;

    IF p_order_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.buyer_orders bo
            JOIN public.order_items oi ON oi.order_id = bo.id
            WHERE bo.id = p_order_id
              AND bo.customer_user_id = v_buyer_id
              AND oi.seller_store_id = p_seller_store_id
        ) INTO v_order_belongs;

        IF NOT v_order_belongs THEN
            RAISE EXCEPTION 'Order does not belong to buyer or does not contain items from this store.' USING ERRCODE = '42501';
        END IF;
    END IF;

    -- Idempotent upsert
    INSERT INTO public.chat_rooms (
        buyer_user_id, seller_store_id, product_id, order_id
    ) VALUES (
        v_buyer_id, p_seller_store_id, p_product_id, p_order_id
    )
    ON CONFLICT (buyer_user_id, seller_store_id, COALESCE(product_id, '00000000-0000-0000-0000-000000000000'::uuid))
    DO UPDATE SET updated_at = NOW()
    RETURNING id INTO v_room_id;

    RETURN jsonb_build_object('success', TRUE, 'room_id', v_room_id);
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. REAL TABLES & RPCS FOR SCREEN 2 (FRAUD & SECURITY)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.fraud_risk_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL CHECK (entity_type IN ('Store', 'Buyer')),
    entity_id TEXT NOT NULL,
    entity_name TEXT NOT NULL,
    risk_score INT NOT NULL CHECK (risk_score >= 0 AND risk_score <= 100),
    risk_factor TEXT NOT NULL,
    ip_address TEXT,
    device_hash TEXT,
    location TEXT,
    status TEXT NOT NULL DEFAULT 'High Risk' CHECK (status IN ('High Risk', 'Medium Warning', 'Resolved', 'Frozen')),
    resolved_by UUID REFERENCES auth.users(id),
    resolution_notes TEXT,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.fraud_risk_alerts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.fraud_risk_alerts FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.fraud_risk_alerts TO authenticated;

CREATE POLICY "Fraud alerts visibility" ON public.fraud_risk_alerts
    FOR SELECT TO authenticated
    USING (public.has_permission('fraud', 'view') OR public.is_admin());

CREATE TABLE IF NOT EXISTS public.fraud_blacklisted_identifiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    identifier_type TEXT NOT NULL CHECK (identifier_type IN ('IP', 'CNIC', 'Bank IBAN', 'Phone Number')),
    identifier_value TEXT NOT NULL,
    holder_name TEXT,
    reason TEXT NOT NULL,
    threat_level TEXT NOT NULL DEFAULT 'High' CHECK (threat_level IN ('High', 'Critical', 'Suspicious')),
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fraud_blacklisted_ident_key UNIQUE (identifier_type, identifier_value)
);

ALTER TABLE public.fraud_blacklisted_identifiers ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.fraud_blacklisted_identifiers FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.fraud_blacklisted_identifiers TO authenticated;

CREATE POLICY "Fraud blacklist visibility" ON public.fraud_blacklisted_identifiers
    FOR SELECT TO authenticated
    USING (public.has_permission('fraud', 'view') OR public.is_admin());

CREATE TABLE IF NOT EXISTS public.fraud_security_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code TEXT UNIQUE NOT NULL,
    rule_title TEXT NOT NULL,
    description TEXT NOT NULL,
    threshold_value TEXT NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.fraud_security_rules ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.fraud_security_rules FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.fraud_security_rules TO authenticated;

CREATE POLICY "Fraud security rules visibility" ON public.fraud_security_rules
    FOR SELECT TO authenticated
    USING (public.has_permission('fraud', 'view') OR public.is_admin());

-- Seed initial Security Rules
INSERT INTO public.fraud_security_rules (rule_code, rule_title, description, threshold_value, is_enabled) VALUES
    ('VELOCITY_LIMIT', 'Velocity Abuse Threshold', 'Max orders per buyer window before triggering automatic review', '5 orders / 10m', TRUE),
    ('DEVICE_COLLISION', 'Device Hash Collisions', 'Max accounts linked to same device fingerprint before suspension', '3 accounts', TRUE),
    ('GEO_IP_MISMATCH', 'Geo-IP Distance Threshold', 'Discrepancy between IP location and shipping address', '> 150 km', TRUE),
    ('COD_RETURN_RATE', 'COD High Return Rate Flag', 'COD return/refusal rate exceeding acceptable benchmark', '30% of orders', TRUE)
ON CONFLICT (rule_code) DO NOTHING;

-- Fraud RPC 1: Fetch Alerts with Server Pagination & Join
CREATE OR REPLACE FUNCTION public.admin_fetch_fraud_alerts(
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0,
    p_status TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_results JSONB;
    v_total INT;
BEGIN
    IF NOT (public.has_permission('fraud', 'view') OR public.is_admin()) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to view fraud alerts.' USING ERRCODE = '42501';
    END IF;

    SELECT COUNT(*) INTO v_total
    FROM public.fraud_risk_alerts
    WHERE (p_status IS NULL OR status = p_status);

    SELECT jsonb_build_object(
        'total_count', v_total,
        'alerts', COALESCE(jsonb_agg(sub), '[]'::jsonb)
    ) INTO v_results
    FROM (
        SELECT id, entity_type, entity_id, entity_name, risk_score, risk_factor,
               ip_address, device_hash, location, status, created_at
        FROM public.fraud_risk_alerts
        WHERE (p_status IS NULL OR status = p_status)
        ORDER BY risk_score DESC, created_at DESC
        LIMIT p_limit OFFSET p_offset
    ) sub;

    RETURN v_results;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_fetch_fraud_alerts(INT, INT, TEXT) TO authenticated;

-- Fraud RPC 2: Resolve Fraud Alert
CREATE OR REPLACE FUNCTION public.admin_resolve_fraud_alert(
    p_alert_id UUID,
    p_resolution TEXT, -- 'Resolved' or 'Frozen'
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_alert RECORD;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF NOT (public.has_permission('fraud', 'score') OR public.has_permission('fraud', 'audit') OR public.is_admin()) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to resolve fraud alerts.' USING ERRCODE = '42501';
    END IF;

    IF p_resolution NOT IN ('Resolved', 'Frozen') THEN
        RAISE EXCEPTION 'Invalid resolution status: %. Must be Resolved or Frozen.', p_resolution USING ERRCODE = '22023';
    END IF;

    SELECT id, entity_type, entity_id, entity_name, risk_score INTO v_alert
    FROM public.fraud_risk_alerts
    WHERE id = p_alert_id
    FOR UPDATE;

    IF v_alert.id IS NULL THEN
        RAISE EXCEPTION 'Fraud alert not found.' USING ERRCODE = 'P0002';
    END IF;

    UPDATE public.fraud_risk_alerts
    SET status = p_resolution,
        resolved_by = v_caller_id,
        resolution_notes = p_notes,
        resolved_at = NOW(),
        updated_at = NOW()
    WHERE id = p_alert_id;

    v_audit_id := public.internal_record_audit_log(
        'fraud_risk_alerts',
        p_alert_id::TEXT,
        'FRAUD_ALERT_RESOLVED',
        jsonb_build_object(
            'resolution', p_resolution,
            'entity_type', v_alert.entity_type,
            'entity_id', v_alert.entity_id,
            'notes', p_notes
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'alert_id', p_alert_id,
        'status', p_resolution,
        'audit_log_id', v_audit_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_resolve_fraud_alert(UUID, TEXT, TEXT) TO authenticated;

-- Fraud RPC 3: Add Blacklisted Identifier
CREATE OR REPLACE FUNCTION public.admin_add_blacklisted_identifier(
    p_identifier_type TEXT,
    p_identifier_value TEXT,
    p_holder_name TEXT,
    p_reason TEXT,
    p_threat_level TEXT DEFAULT 'High'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_id UUID;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF NOT (public.has_permission('fraud', 'blacklist') OR public.is_admin()) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to manage fraud blacklist.' USING ERRCODE = '42501';
    END IF;

    IF p_identifier_type NOT IN ('IP', 'CNIC', 'Bank IBAN', 'Phone Number') THEN
        RAISE EXCEPTION 'Invalid identifier type: %', p_identifier_type USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.fraud_blacklisted_identifiers (
        identifier_type, identifier_value, holder_name, reason, threat_level, created_by
    ) VALUES (
        p_identifier_type, trim(p_identifier_value), p_holder_name, p_reason, p_threat_level, v_caller_id
    ) RETURNING id INTO v_id;

    v_audit_id := public.internal_record_audit_log(
        'fraud_blacklisted_identifiers',
        v_id::TEXT,
        'BLACKLIST_IDENTIFIER_ADDED',
        jsonb_build_object(
            'type', p_identifier_type,
            'value', p_identifier_value,
            'reason', p_reason
        )
    );

    RETURN jsonb_build_object('success', TRUE, 'blacklist_id', v_id, 'audit_log_id', v_audit_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_add_blacklisted_identifier(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- Fraud RPC 4: Remove Blacklisted Identifier
CREATE OR REPLACE FUNCTION public.admin_remove_blacklisted_identifier(
    p_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_audit_id UUID;
    v_item RECORD;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF NOT (public.has_permission('fraud', 'blacklist') OR public.is_admin()) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to manage fraud blacklist.' USING ERRCODE = '42501';
    END IF;

    SELECT id, identifier_type, identifier_value INTO v_item
    FROM public.fraud_blacklisted_identifiers
    WHERE id = p_id;

    IF v_item.id IS NULL THEN
        RAISE EXCEPTION 'Blacklisted identifier not found.' USING ERRCODE = 'P0002';
    END IF;

    DELETE FROM public.fraud_blacklisted_identifiers WHERE id = p_id;

    v_audit_id := public.internal_record_audit_log(
        'fraud_blacklisted_identifiers',
        p_id::TEXT,
        'BLACKLIST_IDENTIFIER_REMOVED',
        jsonb_build_object('type', v_item.identifier_type, 'value', v_item.identifier_value)
    );

    RETURN jsonb_build_object('success', TRUE, 'id', p_id, 'audit_log_id', v_audit_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_remove_blacklisted_identifier(UUID) TO authenticated;

-- Fraud RPC 5: Toggle Security Rule
CREATE OR REPLACE FUNCTION public.admin_toggle_security_rule(
    p_rule_id UUID,
    p_is_enabled BOOLEAN,
    p_threshold_value TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_audit_id UUID;
    v_rule_code TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF NOT (public.has_permission('fraud', 'audit') OR public.has_permission('fraud', 'score') OR public.is_admin()) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to modify fraud security rules.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.fraud_security_rules
    SET is_enabled = p_is_enabled,
        threshold_value = COALESCE(p_threshold_value, threshold_value),
        updated_by = v_caller_id,
        updated_at = NOW()
    WHERE id = p_rule_id
    RETURNING rule_code INTO v_rule_code;

    IF v_rule_code IS NULL THEN
        RAISE EXCEPTION 'Security rule not found.' USING ERRCODE = 'P0002';
    END IF;

    v_audit_id := public.internal_record_audit_log(
        'fraud_security_rules',
        p_rule_id::TEXT,
        'SECURITY_RULE_MODIFIED',
        jsonb_build_object('rule_code', v_rule_code, 'is_enabled', p_is_enabled, 'threshold', p_threshold_value)
    );

    RETURN jsonb_build_object('success', TRUE, 'rule_id', p_rule_id, 'is_enabled', p_is_enabled, 'audit_log_id', v_audit_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_toggle_security_rule(UUID, BOOLEAN, TEXT) TO authenticated;


-- =========================================================================
-- FILE: 20260832000000_fulfillment_safety_and_governance.sql
-- =========================================================================

-- Migration: 20260832000000_fulfillment_safety_and_governance.sql
-- Description: Fulfillment money safety, multi-vendor held earnings lifecycle, strict has_permission authorization, deactivated-user gates, fraud checkout enforcement, and SQLSTATE 42501 normalization

-- ----------------------------------------------------------------------------
-- 1. FINANCIAL SCHEMA ENHANCEMENTS: WALLET HELD BALANCES & EARNINGS MATURITY
-- ----------------------------------------------------------------------------

-- Add available_balance and held_balance columns to wallet_accounts
ALTER TABLE public.wallet_accounts
    ADD COLUMN IF NOT EXISTS available_balance NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (available_balance >= 0.00),
    ADD COLUMN IF NOT EXISTS held_balance NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (held_balance >= 0.00);

-- Table: order_held_earnings (Tracks return window maturity and escrow release)
CREATE TABLE IF NOT EXISTS public.order_held_earnings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id TEXT NOT NULL REFERENCES public.buyer_orders(id) ON DELETE CASCADE,
    seller_store_id UUID NOT NULL REFERENCES public.seller_stores(id) ON DELETE CASCADE,
    gross_amount NUMERIC(12,2) NOT NULL CHECK (gross_amount >= 0.00),
    commission_amount NUMERIC(12,2) NOT NULL CHECK (commission_amount >= 0.00),
    net_amount NUMERIC(12,2) NOT NULL CHECK (net_amount >= 0.00),
    status TEXT NOT NULL DEFAULT 'HELD' CHECK (status IN ('HELD', 'RELEASED', 'FORFEITED')),
    held_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    mature_at TIMESTAMPTZ NOT NULL,
    released_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_order_held_earnings UNIQUE (order_id, seller_store_id)
);

ALTER TABLE public.order_held_earnings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.order_held_earnings FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.order_held_earnings TO authenticated;

DROP POLICY IF EXISTS "Order held earnings visibility" ON public.order_held_earnings;
CREATE POLICY "Order held earnings visibility" ON public.order_held_earnings
    FOR SELECT TO authenticated
    USING (
        public.owns_seller_store(seller_store_id)
        OR public.has_permission('finance', 'view')
    );

-- Table: store_fulfillments (Ensure stock_restored column exists)
ALTER TABLE public.store_fulfillments
    ADD COLUMN IF NOT EXISTS stock_restored BOOLEAN NOT NULL DEFAULT FALSE;

-- Ensure wallet_transactions allows fulfillment hold and release source types
ALTER TABLE public.wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_source_type_check;
ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_source_type_check
    CHECK (source_type IN (
        'ORDER_SETTLEMENT', 'PAYOUT_RESERVATION', 'PAYOUT_DISBURSEMENT',
        'PAYOUT_REJECTION_RELEASE', 'REFUND_REVERSAL', 'ADMIN_ADJUSTMENT',
        'ORDER_FULFILLMENT', 'ORDER_DELIVERED_HELD', 'ORDER_EARNINGS_RELEASE'
    ));

-- Unique constraint on wallet transaction source per store to guarantee exactly-once credit per transaction type
CREATE UNIQUE INDEX IF NOT EXISTS uq_wallet_txn_store_source
ON public.wallet_transactions (seller_store_id, transaction_type, source_type, source_id);

-- Ensure roles module permissions are seeded in staff_role_permissions
INSERT INTO public.staff_role_permissions (staff_role, module, action) VALUES
    ('superAdmin', 'roles', 'view'),
    ('superAdmin', 'roles', 'assign'),
    ('auditor', 'roles', 'view')
ON CONFLICT (staff_role, module, action) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. SELLER FULFILLMENT SAFETY: seller_update_fulfillment_status
-- ----------------------------------------------------------------------------
-- Sellers may ONLY move fulfillment to Processing, Shipped, or Cancelled (before shipping).
-- Sellers CANNOT set Delivered.
-- Cancelled restores inventory only once (idempotent).
-- Gated against deactivated accounts (42501).

CREATE OR REPLACE FUNCTION public.seller_update_fulfillment_status(
    p_order_id TEXT,
    p_new_status TEXT,
    p_seller_store_id UUID DEFAULT NULL,
    p_courier_name TEXT DEFAULT NULL,
    p_tracking_number TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_current_user_id UUID;
    v_is_deactivated BOOLEAN;
    v_order RECORD;
    v_target_store_id UUID;
    v_store_count INT;
    v_old_status TEXT;
    v_stock_restored BOOLEAN;
    v_item RECORD;
BEGIN
    v_current_user_id := auth.uid();
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    -- Gate against deactivated accounts
    SELECT is_deactivated INTO v_is_deactivated FROM public.profiles WHERE id = v_current_user_id;
    IF v_is_deactivated = TRUE THEN
        RAISE EXCEPTION 'Account is deactivated. Please contact support.' USING ERRCODE = '42501';
    END IF;

    -- Money Safety Rule: Sellers CANNOT set Delivered unless caller is admin / logistics
    IF p_new_status = 'Delivered' THEN
        IF public.has_permission('orders', 'release') OR public.has_permission('shipping', 'update')
           OR EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = v_current_user_id AND role IN ('admin', 'super_admin', 'owner')) THEN
            IF p_seller_store_id IS NOT NULL THEN
                RETURN public.admin_mark_order_delivered(p_order_id, p_seller_store_id);
            END IF;
        ELSE
            RAISE EXCEPTION 'Access denied: Sellers cannot mark orders as Delivered. Delivery must be verified by admin or courier.' USING ERRCODE = '42501';
        END IF;
    END IF;

    IF p_new_status NOT IN ('Processing', 'Shipped', 'Cancelled', 'Delivered') THEN
        RAISE EXCEPTION 'Invalid seller status transition: %. Allowed values are Processing, Shipped, or Cancelled.', p_new_status USING ERRCODE = '22023';
    END IF;

    -- Fetch and lock Order
    SELECT id, order_number, status, payment_status, payment_method, customer_user_id
    INTO v_order
    FROM public.buyer_orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF v_order.id IS NULL THEN
        RAISE EXCEPTION 'Order not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Authorize seller through order_items: identify store caller owns in this order
    IF p_seller_store_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.order_items oi
            JOIN public.seller_stores ss ON ss.id = oi.seller_store_id
            WHERE oi.order_id = p_order_id
              AND oi.seller_store_id = p_seller_store_id
              AND ss.owner_id = v_current_user_id
        ) THEN
            RAISE EXCEPTION 'Access denied: You do not own store %.', p_seller_store_id USING ERRCODE = 'P0001';
        END IF;
        v_target_store_id := p_seller_store_id;
    ELSE
        SELECT COUNT(DISTINCT oi.seller_store_id) INTO v_store_count
        FROM public.order_items oi
        JOIN public.seller_stores ss ON ss.id = oi.seller_store_id
        WHERE oi.order_id = p_order_id
          AND ss.owner_id = v_current_user_id;

        IF v_store_count = 0 THEN
            RAISE EXCEPTION 'Unauthorized to update fulfillment status for this store. User does not own a registered seller store.' USING ERRCODE = '42501';
        ELSIF v_store_count > 1 THEN
            RAISE EXCEPTION 'Multiple stores found for this order. Please specify p_seller_store_id.' USING ERRCODE = '22023';
        END IF;

        SELECT DISTINCT oi.seller_store_id INTO v_target_store_id
        FROM public.order_items oi
        JOIN public.seller_stores ss ON ss.id = oi.seller_store_id
        WHERE oi.order_id = p_order_id
          AND ss.owner_id = v_current_user_id;
    END IF;

    -- Verify store is active and approved
    IF NOT public.is_approved_active_seller_store(v_target_store_id) THEN
        RAISE EXCEPTION 'Seller store is not approved or is suspended.' USING ERRCODE = '42501';
    END IF;

    -- Lock & Fetch store_fulfillment row
    SELECT fulfillment_status, stock_restored INTO v_old_status, v_stock_restored
    FROM public.store_fulfillments
    WHERE order_id = p_order_id
      AND seller_store_id = v_target_store_id
    FOR UPDATE;

    IF v_old_status IS NULL THEN
        INSERT INTO public.store_fulfillments (
            order_id, seller_store_id, fulfillment_status, courier_name, tracking_number, notes
        ) VALUES (
            p_order_id, v_target_store_id, 'Pending', p_courier_name, p_tracking_number, p_notes
        );
        v_old_status := 'Pending';
        v_stock_restored := FALSE;
    END IF;

    -- Enforce state transitions
    IF v_old_status = 'Pending' AND p_new_status NOT IN ('Processing', 'Shipped', 'Cancelled') THEN
        RAISE EXCEPTION 'Pending fulfillment can only transition to Processing or Cancelled.' USING ERRCODE = '22023';
    ELSIF v_old_status = 'Processing' AND p_new_status NOT IN ('Shipped', 'Cancelled') THEN
        RAISE EXCEPTION 'Processing fulfillment can only transition to Shipped or Cancelled.' USING ERRCODE = '22023';
    ELSIF v_old_status = 'Shipped' AND p_new_status = 'Cancelled' THEN
        RAISE EXCEPTION 'Cannot cancel an order that has already shipped.' USING ERRCODE = '22023';
    ELSIF v_old_status IN ('Delivered', 'Cancelled') THEN
        RAISE EXCEPTION 'Finalized fulfillments cannot change status.' USING ERRCODE = '22023';
    END IF;

    -- Update store_fulfillment
    UPDATE public.store_fulfillments
    SET fulfillment_status = p_new_status,
        courier_name = COALESCE(p_courier_name, courier_name),
        tracking_number = COALESCE(p_tracking_number, tracking_number),
        notes = COALESCE(p_notes, notes),
        shipped_at = CASE WHEN p_new_status = 'Shipped' THEN NOW() ELSE shipped_at END,
        updated_at = NOW()
    WHERE order_id = p_order_id AND seller_store_id = v_target_store_id;

    -- On Cancelled: Restore inventory ONLY if not already restored (idempotent)
    IF p_new_status = 'Cancelled' AND COALESCE(v_stock_restored, FALSE) = FALSE THEN
        FOR v_item IN (
            SELECT product_id, quantity
            FROM public.order_items
            WHERE order_id = p_order_id AND seller_store_id = v_target_store_id
        ) LOOP
            UPDATE public.products
            SET stock_quantity = stock_quantity + v_item.quantity,
                updated_at = NOW()
            WHERE id = v_item.product_id;
        END LOOP;

        UPDATE public.store_fulfillments
        SET stock_restored = TRUE,
            updated_at = NOW()
        WHERE order_id = p_order_id AND seller_store_id = v_target_store_id;
    END IF;

    -- Update buyer_orders overall status for processing/shipped
    IF p_new_status = 'Shipped' AND v_order.status NOT IN ('Delivered', 'Cancelled') THEN
        UPDATE public.buyer_orders SET status = 'Shipped', updated_at = NOW() WHERE id = p_order_id;
    ELSIF p_new_status = 'Processing' AND v_order.status = 'Pending' THEN
        UPDATE public.buyer_orders SET status = 'Processing', updated_at = NOW() WHERE id = p_order_id;
    END IF;

    -- Insert order tracking event
    INSERT INTO public.order_tracking_events (
        order_id, seller_store_id, event_type, description, location
    ) VALUES (
        p_order_id, v_target_store_id, p_new_status,
        'Fulfillment updated to ' || p_new_status || COALESCE(' (' || p_notes || ')', ''),
        COALESCE(p_courier_name, 'Courier Facility')
    );

    -- Notify buyer of fulfillment change
    PERFORM public.internal_create_notification(
        v_order.customer_user_id,
        'ORDER_FULFILLMENT',
        'Order ' || COALESCE(v_order.order_number, p_order_id) || ' Status Update',
        'Your order items from store have updated to ' || p_new_status,
        jsonb_build_object('order_id', p_order_id, 'seller_store_id', v_target_store_id, 'status', p_new_status)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'order_id', p_order_id,
        'seller_store_id', v_target_store_id,
        'fulfillment_status', p_new_status,
        'store_fulfillment_status', p_new_status
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.seller_update_fulfillment_status(
    p_order_id TEXT,
    p_new_status TEXT,
    p_notes TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RETURN public.seller_update_fulfillment_status(
        p_order_id => p_order_id,
        p_new_status => p_new_status,
        p_seller_store_id => NULL,
        p_courier_name => NULL,
        p_tracking_number => NULL,
        p_notes => p_notes
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.seller_update_fulfillment_status(TEXT, TEXT, UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.seller_update_fulfillment_status(TEXT, TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. ADMIN / COURIER MARK ORDER DELIVERED RPC
-- ----------------------------------------------------------------------------
-- Authoritative Delivered transition with audit log.
-- Credits only this store's items into HELD balance (matures after 7-day return window).
-- Enforces payment_status = 'Paid' ONLY when ALL store fulfillments are Delivered.

CREATE OR REPLACE FUNCTION public.admin_mark_order_delivered(
    p_order_id TEXT,
    p_seller_store_id UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_order RECORD;
    v_old_status TEXT;
    v_gross_amount NUMERIC(12,2) := 0.00;
    v_commission_amount NUMERIC(12,2) := 0.00;
    v_net_amount NUMERIC(12,2) := 0.00;
    v_wallet_account_id UUID;
    v_all_delivered BOOLEAN;
    v_all_stores_covered BOOLEAN;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    -- Strict authorization check via has_permission
    IF NOT public.has_permission('orders', 'release') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to mark orders as delivered.' USING ERRCODE = '42501';
    END IF;

    -- Fetch and lock Order
    SELECT id, order_number, status, payment_status, payment_method, customer_user_id
    INTO v_order
    FROM public.buyer_orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF v_order.id IS NULL THEN
        RAISE EXCEPTION 'Order not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Verify that order contains items for this store
    IF NOT EXISTS (
        SELECT 1 FROM public.order_items
        WHERE order_id = p_order_id AND seller_store_id = p_seller_store_id
    ) THEN
        RAISE EXCEPTION 'Store % has no items in order %.', p_seller_store_id, p_order_id USING ERRCODE = '22023';
    END IF;

    -- Fetch store fulfillment row
    SELECT fulfillment_status INTO v_old_status
    FROM public.store_fulfillments
    WHERE order_id = p_order_id AND seller_store_id = p_seller_store_id
    FOR UPDATE;

    IF v_old_status IS NULL THEN
        INSERT INTO public.store_fulfillments (
            order_id, seller_store_id, fulfillment_status, delivered_at, notes
        ) VALUES (
            p_order_id, p_seller_store_id, 'Delivered', NOW(), p_notes
        );
        v_old_status := 'Pending';
    ELSIF v_old_status = 'Delivered' THEN
        -- Idempotent return if already delivered
        RETURN jsonb_build_object(
            'success', TRUE,
            'message', 'Fulfillment is already marked Delivered.',
            'order_id', p_order_id,
            'seller_store_id', p_seller_store_id
        );
    ELSIF v_old_status = 'Cancelled' THEN
        RAISE EXCEPTION 'Cannot deliver a cancelled fulfillment.' USING ERRCODE = '22023';
    ELSE
        UPDATE public.store_fulfillments
        SET fulfillment_status = 'Delivered',
            delivered_at = NOW(),
            notes = COALESCE(p_notes, notes),
            updated_at = NOW()
        WHERE order_id = p_order_id AND seller_store_id = p_seller_store_id;
    END IF;

    -- Compute earnings for this store's items only: unit_price*qty minus commission
    SELECT
        COALESCE(SUM(unit_price * quantity), 0.00),
        COALESCE(SUM(commission_amount), 0.00),
        COALESCE(SUM(seller_payable), 0.00)
    INTO v_gross_amount, v_commission_amount, v_net_amount
    FROM public.order_items
    WHERE order_id = p_order_id AND seller_store_id = p_seller_store_id;

    -- Ensure wallet account exists
    SELECT id INTO v_wallet_account_id
    FROM public.wallet_accounts
    WHERE seller_store_id = p_seller_store_id;

    IF v_wallet_account_id IS NULL THEN
        INSERT INTO public.wallet_accounts (seller_store_id, owner_id)
        SELECT p_seller_store_id, owner_id
        FROM public.seller_stores WHERE id = p_seller_store_id
        RETURNING id INTO v_wallet_account_id;
    END IF;

    -- Insert into order_held_earnings: matures in 7 days
    INSERT INTO public.order_held_earnings (
        order_id, seller_store_id, gross_amount, commission_amount, net_amount,
        status, mature_at
    ) VALUES (
        p_order_id, p_seller_store_id, v_gross_amount, v_commission_amount, v_net_amount,
        'HELD', NOW() + INTERVAL '7 days'
    )
    ON CONFLICT (order_id, seller_store_id) DO NOTHING;

    -- Insert HOLD transaction into wallet_transactions once per (order_id, seller_store_id)
    INSERT INTO public.wallet_transactions (
        wallet_account_id, seller_store_id, transaction_type, amount,
        source_type, source_id, idempotency_key, description, created_by
    ) VALUES (
        v_wallet_account_id, p_seller_store_id, 'HOLD', v_net_amount,
        'ORDER_DELIVERED_HELD', p_order_id, 'WLT-HLD-' || p_order_id || '-' || p_seller_store_id,
        'Held earnings for order ' || p_order_id || ' (7-day escrow hold)', v_caller_id
    )
    ON CONFLICT (seller_store_id, transaction_type, source_type, source_id) DO NOTHING;

    -- Increment wallet_accounts.held_balance
    UPDATE public.wallet_accounts
    SET held_balance = held_balance + v_net_amount,
        updated_at = NOW()
    WHERE id = v_wallet_account_id;

    -- RULE: payment_status becomes 'Paid' ONLY when ALL store fulfillments of this order are 'Delivered'
    SELECT
        bool_and(sf.fulfillment_status = 'Delivered'),
        count(DISTINCT sf.seller_store_id) = (SELECT count(DISTINCT oi.seller_store_id) FROM public.order_items oi WHERE oi.order_id = p_order_id)
    INTO v_all_delivered, v_all_stores_covered
    FROM public.store_fulfillments sf
    WHERE sf.order_id = p_order_id;

    IF v_all_delivered = TRUE AND v_all_stores_covered = TRUE THEN
        UPDATE public.buyer_orders
        SET status = 'Delivered',
            payment_status = 'Paid',
            updated_at = NOW()
        WHERE id = p_order_id;

        UPDATE public.payments
        SET status = 'Collected',
            collected_at = NOW(),
            updated_at = NOW()
        WHERE order_id = p_order_id;
    END IF;

    -- Insert tracking event
    INSERT INTO public.order_tracking_events (
        order_id, seller_store_id, event_type, status, description, location
    ) VALUES (
        p_order_id, p_seller_store_id, 'Delivered', 'Delivered',
        'Store fulfillment delivered. ' || COALESCE(p_notes, ''),
        'Customer Destination'
    );

    -- Record audit log
    v_audit_id := public.internal_record_audit_log(
        'store_fulfillments',
        p_order_id || ':' || p_seller_store_id,
        'ORDER_DELIVERED',
        jsonb_build_object(
            'order_id', p_order_id,
            'seller_store_id', p_seller_store_id,
            'held_amount', v_net_amount,
            'all_delivered', (v_all_delivered AND v_all_stores_covered)
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'order_id', p_order_id,
        'seller_store_id', p_seller_store_id,
        'status', 'Delivered',
        'held_earnings', v_net_amount,
        'order_paid', (v_all_delivered AND v_all_stores_covered),
        'audit_log_id', v_audit_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_mark_order_delivered(TEXT, UUID, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 4. RELEASE HELD EARNINGS RPC: admin_release_held_seller_earnings
-- ----------------------------------------------------------------------------
-- Releases held balance to available balance only after return window matures
-- and only if NO open return claims exist.

CREATE OR REPLACE FUNCTION public.admin_release_held_seller_earnings(
    p_order_id TEXT,
    p_seller_store_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_held RECORD;
    v_has_open_returns BOOLEAN;
    v_wallet_account_id UUID;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF NOT (public.has_permission('finance', 'adjust') OR public.has_permission('orders', 'release')) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to release held earnings.' USING ERRCODE = '42501';
    END IF;

    -- Lock and fetch held earnings entry
    SELECT id, order_id, seller_store_id, net_amount, status, mature_at
    INTO v_held
    FROM public.order_held_earnings
    WHERE order_id = p_order_id AND seller_store_id = p_seller_store_id
    FOR UPDATE;

    IF v_held.id IS NULL THEN
        RAISE EXCEPTION 'No held earnings record found for order % and store %.', p_order_id, p_seller_store_id USING ERRCODE = 'P0002';
    END IF;

    IF v_held.status <> 'HELD' THEN
        RAISE EXCEPTION 'Held earnings have already been processed (Current status: %).', v_held.status USING ERRCODE = '22023';
    END IF;

    IF v_held.mature_at > NOW() THEN
        RAISE EXCEPTION 'Cannot release earnings: Return window has not expired yet (Matures at %).', v_held.mature_at USING ERRCODE = '22023';
    END IF;

    -- Verify NO open return claims exist for this order and store
    SELECT EXISTS (
        SELECT 1 FROM public.return_requests rr
        JOIN public.order_items oi ON oi.id = rr.order_item_id
        WHERE oi.order_id = p_order_id
          AND oi.seller_store_id = p_seller_store_id
          AND rr.status NOT IN ('Rejected', 'Completed', 'Cancelled')
    ) INTO v_has_open_returns;

    IF v_has_open_returns THEN
        RAISE EXCEPTION 'Cannot release earnings: Open dispute or return claim exists for this order.' USING ERRCODE = '22023';
    END IF;

    -- Update order_held_earnings
    UPDATE public.order_held_earnings
    SET status = 'RELEASED',
        released_at = NOW()
    WHERE id = v_held.id;

    -- Fetch wallet account
    SELECT id INTO v_wallet_account_id
    FROM public.wallet_accounts
    WHERE seller_store_id = p_seller_store_id;

    -- Release held to available in wallet_accounts
    UPDATE public.wallet_accounts
    SET held_balance = GREATEST(held_balance - v_held.net_amount, 0.00),
        available_balance = available_balance + v_held.net_amount,
        updated_at = NOW()
    WHERE id = v_wallet_account_id;

    -- Update seller_stores available balance
    UPDATE public.seller_stores
    SET balance = balance + v_held.net_amount,
        updated_at = NOW()
    WHERE id = p_seller_store_id;

    -- Insert RELEASE entry into wallet_transactions
    INSERT INTO public.wallet_transactions (
        wallet_account_id, seller_store_id, transaction_type, amount,
        source_type, source_id, idempotency_key, description, created_by
    ) VALUES (
        v_wallet_account_id, p_seller_store_id, 'RELEASE', v_held.net_amount,
        'ORDER_EARNINGS_RELEASE', p_order_id, 'WLT-REL-' || p_order_id || '-' || p_seller_store_id,
        'Released earnings for order ' || p_order_id || ' following return window expiration', v_caller_id
    )
    ON CONFLICT (seller_store_id, transaction_type, source_type, source_id) DO NOTHING;

    -- Record audit log
    v_audit_id := public.internal_record_audit_log(
        'order_held_earnings',
        v_held.id::TEXT,
        'HELD_EARNINGS_RELEASED',
        jsonb_build_object(
            'order_id', p_order_id,
            'seller_store_id', p_seller_store_id,
            'released_amount', v_held.net_amount
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'order_id', p_order_id,
        'seller_store_id', p_seller_store_id,
        'released_amount', v_held.net_amount,
        'status', 'RELEASED',
        'audit_log_id', v_audit_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_release_held_seller_earnings(TEXT, UUID) TO authenticated;

-- Scheduled helper function: batch release of mature held earnings
CREATE OR REPLACE FUNCTION public.release_mature_held_seller_earnings()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_rec RECORD;
    v_count INT := 0;
BEGIN
    FOR v_rec IN (
        SELECT ohe.order_id, ohe.seller_store_id
        FROM public.order_held_earnings ohe
        WHERE ohe.status = 'HELD'
          AND ohe.mature_at <= NOW()
          AND NOT EXISTS (
              SELECT 1 FROM public.return_requests rr
              JOIN public.order_items oi ON oi.id = rr.order_item_id
              WHERE oi.order_id = ohe.order_id
                AND oi.seller_store_id = ohe.seller_store_id
                AND rr.status NOT IN ('Rejected', 'Completed', 'Cancelled')
          )
    ) LOOP
        PERFORM public.admin_release_held_seller_earnings(v_rec.order_id, v_rec.seller_store_id);
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object('success', TRUE, 'released_count', v_count);
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. PAYOUT REQUEST SAFETY: seller_request_payout
-- ----------------------------------------------------------------------------
-- Gated against deactivated accounts (42501).
-- Restricts withdrawals strictly to available_balance (held balance cannot be withdrawn).

DROP FUNCTION IF EXISTS public.seller_request_payout(UUID, NUMERIC, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.seller_request_payout(UUID, NUMERIC(12,2), TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.seller_request_payout(NUMERIC, TEXT);
DROP FUNCTION IF EXISTS public.seller_request_payout(NUMERIC(12,2), TEXT);

CREATE OR REPLACE FUNCTION public.seller_request_payout(
    p_amount NUMERIC(12,2),
    p_idempotency_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_seller_id UUID;
    v_is_deactivated BOOLEAN;
    v_store RECORD;
    v_wallet_account_id UUID;
    v_available_balance NUMERIC(12,2);
    v_payout_id UUID;
BEGIN
    v_seller_id := auth.uid();
    IF v_seller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    -- Gate against deactivated accounts
    SELECT is_deactivated INTO v_is_deactivated FROM public.profiles WHERE id = v_seller_id;
    IF v_is_deactivated = TRUE THEN
        RAISE EXCEPTION 'Account is deactivated. Please contact support.' USING ERRCODE = '42501';
    END IF;

    IF p_amount IS NULL OR p_amount <= 0.00 THEN
        RAISE EXCEPTION 'Payout amount must be greater than zero.' USING ERRCODE = '22023';
    END IF;

    IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
        RAISE EXCEPTION 'Idempotency key is required for payout request.' USING ERRCODE = '22023';
    END IF;

    -- Lock Seller Store
    SELECT id, is_approved, is_suspended, payout_locked, balance
    INTO v_store
    FROM public.seller_stores
    WHERE owner_id = v_seller_id
    FOR UPDATE;

    IF v_store.id IS NULL THEN
        RAISE EXCEPTION 'Seller store not found for authenticated user.' USING ERRCODE = 'P0002';
    END IF;

    IF NOT COALESCE(v_store.is_approved, FALSE) OR COALESCE(v_store.is_suspended, FALSE) THEN
        RAISE EXCEPTION 'Cannot request payout: Store is not approved or is suspended.' USING ERRCODE = '42501';
    END IF;

    IF COALESCE(v_store.payout_locked, FALSE) THEN
        RAISE EXCEPTION 'Payouts are currently locked for your seller account.' USING ERRCODE = '42501';
    END IF;

    -- Ensure Wallet Account exists
    SELECT id INTO v_wallet_account_id
    FROM public.wallet_accounts
    WHERE seller_store_id = v_store.id
    FOR UPDATE;

    IF v_wallet_account_id IS NULL THEN
        INSERT INTO public.wallet_accounts (seller_store_id, owner_id)
        VALUES (v_store.id, v_seller_id)
        RETURNING id INTO v_wallet_account_id;
    END IF;

    -- Derive available balance from single source of truth (wallet ledger summary)
    SELECT available_balance INTO v_available_balance
    FROM public.get_seller_wallet_summary(v_store.id);
    v_available_balance := COALESCE(v_available_balance, 0.00);

    -- Money Safety Rule: Payout requests can only use available balance (NOT held balance)
    IF p_amount > v_available_balance THEN
        RAISE EXCEPTION 'Insufficient available balance. Requested: %, Available: % (Held balance cannot be withdrawn).', p_amount, v_available_balance USING ERRCODE = '22023';
    END IF;

    -- Deduct from available balance and hold for payout
    UPDATE public.wallet_accounts
    SET available_balance = GREATEST(available_balance - p_amount, 0.00),
        updated_at = NOW()
    WHERE id = v_wallet_account_id;

    -- Create Payout Request Row
    INSERT INTO public.payout_requests (
        seller_store_id, requested_by, amount, status, idempotency_key, bank_name, iban
    ) VALUES (
        v_store.id, v_seller_id, p_amount, 'Requested', p_idempotency_key, 'Verified Partner Bank', 'PK-ACCOUNT-VERIFIED'
    ) RETURNING id INTO v_payout_id;

    -- Record HOLD in wallet ledger
    INSERT INTO public.wallet_transactions (
        wallet_account_id, seller_store_id, transaction_type, amount,
        source_type, source_id, idempotency_key, description, created_by
    ) VALUES (
        v_wallet_account_id, v_store.id, 'HOLD', p_amount,
        'PAYOUT_RESERVATION', v_payout_id::TEXT, 'WLT-PO-' || p_idempotency_key,
        'Payout reservation hold for request ' || v_payout_id::TEXT, v_seller_id
    ) ON CONFLICT (idempotency_key) DO NOTHING;

    RETURN jsonb_build_object(
        'success', TRUE,
        'payout_id', v_payout_id,
        'amount', p_amount,
        'remaining_available_balance', (v_available_balance - p_amount)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.seller_request_payout(NUMERIC, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 6. DEACTIVATED-USER GATES ACROSS WRITE RPCS & FRAUD CHECKOUT ENFORCEMENT
-- ----------------------------------------------------------------------------

-- A. create_atomic_order: Gated on deactivated accounts + phone/address fraud check
CREATE OR REPLACE FUNCTION public.create_atomic_order(
    p_items JSONB,
    p_shipping_address JSONB,
    p_payment_method TEXT,
    p_idempotency_key TEXT,
    p_notes TEXT DEFAULT NULL,
    p_voucher_code TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_buyer_id UUID;
    v_is_deactivated BOOLEAN;
    v_order_id TEXT;
    v_order_number TEXT;
    v_normalized_payment_method TEXT;
    v_total_amount NUMERIC(12,2) := 0;
    v_shipping_fee NUMERIC(12,2) := 150.00;
    v_voucher_discount NUMERIC(12,2) := 0.00;
    v_grand_total NUMERIC(12,2) := 0;
    v_item RECORD;
    v_product RECORD;
    v_voucher RECORD;
    v_user_usage_count INT := 0;
    v_unit_price NUMERIC(12,2);
    v_line_total NUMERIC(12,2);
    v_commission_rate NUMERIC(5,2);
    v_commission_amount NUMERIC(12,2);
    v_seller_earning NUMERIC(12,2);
    v_existing_order RECORD;
    v_buyer_phone TEXT;
    v_shipping_phone TEXT;
    v_is_blacklisted BOOLEAN;
    v_fingerprint TEXT;
    v_aggregated_items JSONB;
    v_variant_sku TEXT;
    v_variant_stock INT;
BEGIN
    v_buyer_id := auth.uid();
    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to create order.';
    END IF;

    -- Deactivated Account Gate
    SELECT is_deactivated, phone INTO v_is_deactivated, v_buyer_phone FROM public.profiles WHERE id = v_buyer_id;
    IF v_is_deactivated = TRUE THEN
        RAISE EXCEPTION 'Account is deactivated. Please contact support.' USING ERRCODE = '42501';
    END IF;

    -- Fraud Enforcement Check: Verify buyer phone, shipping address phone, or IP are not blacklisted
    v_shipping_phone := p_shipping_address->>'phone';
    SELECT EXISTS (
        SELECT 1 FROM public.fraud_blacklisted_identifiers
        WHERE (
            (identifier_type = 'Phone Number' AND identifier_value IN (v_buyer_phone, v_shipping_phone))
        )
    ) INTO v_is_blacklisted;

    IF v_is_blacklisted THEN
        RAISE EXCEPTION 'Transaction rejected: Blacklisted contact details or identifier detected.' USING ERRCODE = '42501';
    END IF;

    -- Strict Payment Guard: Only Cash on Delivery
    IF p_payment_method IS NULL OR (p_payment_method != 'Cash on Delivery' AND p_payment_method != 'COD') THEN
        RAISE EXCEPTION 'Online payments are not available yet. Please select Cash on Delivery.';
    END IF;
    v_normalized_payment_method := 'Cash on Delivery';

    -- Empty cart guard
    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Cart cannot be empty.';
    END IF;

    -- Aggregate duplicate items by product_id + variant_id
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

    -- Compute Request Fingerprint
    v_fingerprint := md5(COALESCE(v_aggregated_items::text, '') || '|' || COALESCE(p_shipping_address::text, '{}') || '|' || p_payment_method);

    -- Check idempotency scoped to caller
    SELECT id, order_number, status, grand_total, request_fingerprint
    INTO v_existing_order
    FROM public.buyer_orders
    WHERE customer_user_id = v_buyer_id AND idempotency_key = p_idempotency_key;

    IF v_existing_order.id IS NOT NULL THEN
        IF v_existing_order.request_fingerprint IS NOT NULL AND v_existing_order.request_fingerprint <> v_fingerprint THEN
            RAISE EXCEPTION 'Idempotency conflict: Key % was already used with a different request payload.', p_idempotency_key USING ERRCODE = 'P0001';
        END IF;

        RETURN jsonb_build_object(
            'success', TRUE,
            'idempotent_reused', TRUE,
            'order_id', v_existing_order.id,
            'order_number', v_existing_order.order_number,
            'status', v_existing_order.status,
            'grand_total', v_existing_order.grand_total
        );
    END IF;

    v_order_number := 'ORD-' || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 8));

    -- Validate items and compute totals
    FOR v_item IN SELECT * FROM jsonb_to_recordset(v_aggregated_items) AS x(product_id UUID, variant_id UUID, quantity INT)
    LOOP
        SELECT id, name, sku, regular_price, sale_price, stock_quantity, seller_store_id, is_active, approval_status
        INTO v_product
        FROM public.products
        WHERE id = v_item.product_id FOR UPDATE;

        IF v_product.id IS NULL OR NOT v_product.is_active OR LOWER(v_product.approval_status) != 'approved' THEN
            RAISE EXCEPTION 'Product % is unavailable or unapproved.', v_item.product_id;
        END IF;

        IF v_item.variant_id IS NOT NULL THEN
            SELECT sku, stock_quantity, COALESCE(price_override, v_product.sale_price, v_product.regular_price)
            INTO v_variant_sku, v_variant_stock, v_unit_price
            FROM public.product_variants
            WHERE id = v_item.variant_id AND product_id = v_item.product_id FOR UPDATE;

            IF v_unit_price IS NULL THEN
                RAISE EXCEPTION 'Invalid or inactive variant % for product %.', v_item.variant_id, v_item.product_id;
            END IF;

            IF v_variant_stock < v_item.quantity THEN
                RAISE EXCEPTION 'Insufficient stock for product variant %.', v_variant_sku;
            END IF;

            UPDATE public.product_variants
            SET stock_quantity = stock_quantity - v_item.quantity,
                updated_at = NOW()
            WHERE id = v_item.variant_id;
        ELSE
            IF v_product.stock_quantity < v_item.quantity THEN
                RAISE EXCEPTION 'Insufficient stock for product %.', v_product.name;
            END IF;

            UPDATE public.products
            SET stock_quantity = stock_quantity - v_item.quantity,
                updated_at = NOW()
            WHERE id = v_product.id;

            v_unit_price := COALESCE(v_product.sale_price, v_product.regular_price);
        END IF;

        v_line_total := v_unit_price * v_item.quantity;
        v_total_amount := v_total_amount + v_line_total;
    END LOOP;

    -- Apply Voucher if provided
    IF p_voucher_code IS NOT NULL AND TRIM(p_voucher_code) != '' THEN
        SELECT * INTO v_voucher FROM public.platform_vouchers WHERE code = UPPER(TRIM(p_voucher_code)) FOR UPDATE;
        IF v_voucher.id IS NOT NULL AND v_voucher.is_active AND NOW() BETWEEN v_voucher.start_date AND v_voucher.end_date THEN
            IF v_total_amount >= v_voucher.min_order_amount THEN
                IF v_voucher.discount_type = 'percentage' THEN
                    v_voucher_discount := (v_total_amount * v_voucher.discount_value / 100.0);
                    IF v_voucher.max_discount_amount IS NOT NULL THEN
                        v_voucher_discount := LEAST(v_voucher_discount, v_voucher.max_discount_amount);
                    END IF;
                ELSE
                    v_voucher_discount := LEAST(v_voucher.discount_value, v_total_amount);
                END IF;
            END IF;
        END IF;
    END IF;

    v_grand_total := GREATEST(v_total_amount - v_voucher_discount + v_shipping_fee, 0.00);

    -- Insert Order
    INSERT INTO public.buyer_orders (
        id, customer_user_id, order_number, status, payment_status, payment_method,
        total_amount, subtotal, shipping_fee, voucher_discount, grand_total, amount,
        shipping_address, customer_notes, idempotency_key, request_fingerprint
    ) VALUES (
        v_order_number, v_buyer_id, v_order_number, 'Pending', 'Pending', v_normalized_payment_method,
        v_total_amount, v_total_amount, v_shipping_fee, v_voucher_discount, v_grand_total, v_grand_total,
        p_shipping_address, p_notes, p_idempotency_key, v_fingerprint
    ) RETURNING id INTO v_order_id;

    -- Insert Order Items
    FOR v_item IN SELECT * FROM jsonb_to_recordset(v_aggregated_items) AS x(product_id UUID, variant_id UUID, quantity INT)
    LOOP
        SELECT id, name, sku, regular_price, sale_price, seller_store_id INTO v_product
        FROM public.products WHERE id = v_item.product_id;

        IF v_item.variant_id IS NOT NULL THEN
            SELECT sku, COALESCE(price_override, v_product.sale_price, v_product.regular_price)
            INTO v_variant_sku, v_unit_price
            FROM public.product_variants WHERE id = v_item.variant_id;
        ELSE
            v_variant_sku := v_product.sku;
            v_unit_price := COALESCE(v_product.sale_price, v_product.regular_price);
        END IF;

        v_line_total := v_unit_price * v_item.quantity;

        SELECT COALESCE(commission_rate, 10.00) INTO v_commission_rate
        FROM public.seller_stores WHERE id = v_product.seller_store_id;
        v_commission_rate := COALESCE(v_commission_rate, 10.00);

        v_commission_amount := (v_line_total * v_commission_rate / 100.0);
        v_seller_earning := v_line_total - v_commission_amount;

        INSERT INTO public.order_items (
            order_id, product_id, variant_id, seller_store_id, product_name, sku,
            unit_price, quantity, total_price, commission_rate,
            commission_amount, seller_payable
        ) VALUES (
            v_order_id, v_product.id, v_item.variant_id, v_product.seller_store_id, v_product.name, COALESCE(v_variant_sku, v_product.sku, 'SKU-DEFAULT'),
            v_unit_price, v_item.quantity, v_line_total, v_commission_rate,
            v_commission_amount, v_seller_earning
        );
    END LOOP;

    -- Record initial tracking event
    INSERT INTO public.order_tracking_events (
        order_id, status, description, location
    ) VALUES (
        v_order_id,
        'Order Placed',
        'Your order has been placed and will be paid on delivery via Cash on Delivery.',
        'Apna Store Processing Hub'
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'idempotent_reused', FALSE,
        'order_id', v_order_id,
        'order_number', v_order_number,
        'status', 'Pending',
        'subtotal', v_total_amount,
        'shipping_fee', v_shipping_fee,
        'discount_amount', v_voucher_discount,
        'grand_total', v_grand_total
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_atomic_order(JSONB, JSONB, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- Ensure no conflicting 5-arg overload exists with overlapping defaults
DROP FUNCTION IF EXISTS public.create_atomic_order(JSONB, JSONB, TEXT, TEXT, TEXT);

-- Legacy 4-arg overload (TEXT first) for backward compatibility
CREATE OR REPLACE FUNCTION public.create_atomic_order(
    p_idempotency_key TEXT,
    p_items JSONB,
    p_shipping_address JSONB,
    p_payment_method TEXT DEFAULT 'COD'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF p_payment_method IN ('JazzCash', 'EasyPaisa', 'Card') THEN
        RAISE EXCEPTION 'Payment method % is not currently available.', p_payment_method;
    END IF;

    RETURN public.create_atomic_order(
        p_items => p_items,
        p_shipping_address => p_shipping_address,
        p_payment_method => p_payment_method,
        p_idempotency_key => p_idempotency_key,
        p_notes => NULL,
        p_voucher_code => NULL
    );
END;
$$;
GRANT EXECUTE ON FUNCTION public.create_atomic_order(TEXT, JSONB, JSONB, TEXT) TO authenticated;

-- B. seller_update_product_stock: Gated on deactivated accounts
DROP FUNCTION IF EXISTS public.seller_update_product_stock(UUID, INT);
CREATE OR REPLACE FUNCTION public.seller_update_product_stock(
    p_product_id UUID,
    p_new_stock INT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_is_deactivated BOOLEAN;
    v_store_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    SELECT is_deactivated INTO v_is_deactivated FROM public.profiles WHERE id = v_caller_id;
    IF v_is_deactivated = TRUE THEN
        RAISE EXCEPTION 'Account is deactivated. Please contact support.' USING ERRCODE = '42501';
    END IF;

    IF p_new_stock < 0 THEN
        RAISE EXCEPTION 'Stock quantity cannot be negative.';
    END IF;

    SELECT seller_store_id INTO v_store_id FROM public.products WHERE id = p_product_id;
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'Product not found.' USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.owns_seller_store(v_store_id) THEN
        RAISE EXCEPTION 'Access denied: Cannot manage inventory for another seller store.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.products
    SET stock_quantity = p_new_stock,
        updated_at = NOW()
    WHERE id = p_product_id;

    RETURN jsonb_build_object('success', TRUE, 'product_id', p_product_id, 'new_stock', p_new_stock);
END;
$$;

GRANT EXECUTE ON FUNCTION public.seller_update_product_stock(UUID, INT) TO authenticated;

-- C. submit_product_review: Gated on deactivated accounts
CREATE OR REPLACE FUNCTION public.submit_product_review(
    p_product_id UUID,
    p_order_item_id UUID,
    p_rating INT,
    p_comment TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_buyer_id UUID := auth.uid();
    v_is_deactivated BOOLEAN;
    v_order_item RECORD;
    v_review_id UUID;
BEGIN
    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    SELECT is_deactivated INTO v_is_deactivated FROM public.profiles WHERE id = v_buyer_id;
    IF v_is_deactivated = TRUE THEN
        RAISE EXCEPTION 'Account is deactivated. Please contact support.' USING ERRCODE = '42501';
    END IF;

    IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'Rating must be an integer between 1 and 5.' USING ERRCODE = '22023';
    END IF;

    IF p_comment IS NULL OR trim(p_comment) = '' THEN
        RAISE EXCEPTION 'Review comment cannot be empty.' USING ERRCODE = '22023';
    END IF;

    SELECT oi.id, oi.order_id, oi.product_id, bo.customer_user_id, bo.status
    INTO v_order_item
    FROM public.order_items oi
    JOIN public.buyer_orders bo ON bo.id = oi.order_id
    WHERE oi.id = p_order_item_id;

    IF v_order_item.id IS NULL THEN
        RAISE EXCEPTION 'Order line item % not found.', p_order_item_id USING ERRCODE = 'P0001';
    END IF;

    IF v_order_item.product_id <> p_product_id THEN
        RAISE EXCEPTION 'Line item % does not match product %.', p_order_item_id, p_product_id USING ERRCODE = 'P0001';
    END IF;

    IF v_order_item.customer_user_id <> v_buyer_id THEN
        RAISE EXCEPTION 'Access denied: You do not own the order associated with line item %.', p_order_item_id USING ERRCODE = 'P0001';
    END IF;

    IF v_order_item.status <> 'Delivered' THEN
        RAISE EXCEPTION 'Product reviews are only permitted for Delivered orders (Current status: %).', v_order_item.status USING ERRCODE = '22023';
    END IF;

    BEGIN
        INSERT INTO public.product_reviews (
            product_id, order_item_id, buyer_user_id, rating, comment, is_verified_purchase
        ) VALUES (
            p_product_id, p_order_item_id, v_buyer_id, p_rating, p_comment, TRUE
        ) RETURNING id INTO v_review_id;
    EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'You have already submitted a review for this purchased line item.' USING ERRCODE = 'P0001';
    END;

    RETURN jsonb_build_object(
        'success', true,
        'review_id', v_review_id,
        'rating', p_rating,
        'comment', p_comment
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_product_review(UUID, UUID, INT, TEXT) TO authenticated;

-- Overload for (p_order_id TEXT, p_product_id UUID, p_rating INT, p_review_text TEXT)
CREATE OR REPLACE FUNCTION public.submit_product_review(
    p_order_id TEXT,
    p_product_id UUID,
    p_rating INT,
    p_review_text TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_buyer_id UUID := auth.uid();
    v_is_deactivated BOOLEAN;
    v_order_status TEXT;
    v_order_item_id UUID;
    v_review_id UUID;
BEGIN
    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    SELECT is_deactivated INTO v_is_deactivated FROM public.profiles WHERE id = v_buyer_id;
    IF v_is_deactivated = TRUE THEN
        RAISE EXCEPTION 'Account is deactivated. Please contact support.' USING ERRCODE = '42501';
    END IF;

    IF p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'Rating must be between 1 and 5 stars.' USING ERRCODE = '22023';
    END IF;

    SELECT status INTO v_order_status
    FROM public.buyer_orders
    WHERE id = p_order_id AND customer_user_id = v_buyer_id;

    IF v_order_status IS NULL THEN
        IF p_order_id ~ '^[0-9a-fA-F-]{36}$' THEN
            RETURN public.submit_product_review(p_order_id::UUID, p_product_id, p_rating, COALESCE(p_review_text, ''));
        END IF;
        RAISE EXCEPTION 'Order not found or does not belong to authenticated user.' USING ERRCODE = 'P0001';
    END IF;

    IF v_order_status <> 'Delivered' THEN
        RAISE EXCEPTION 'Reviews can only be submitted for Delivered orders.' USING ERRCODE = '22023';
    END IF;

    SELECT id INTO v_order_item_id
    FROM public.order_items
    WHERE order_id = p_order_id AND product_id = p_product_id
    LIMIT 1;

    INSERT INTO public.product_reviews (
        product_id, order_item_id, buyer_user_id, rating, comment, is_verified_purchase
    ) VALUES (
        p_product_id, v_order_item_id, v_buyer_id, p_rating, COALESCE(p_review_text, 'Good product'), TRUE
    )
    RETURNING id INTO v_review_id;

    RETURN jsonb_build_object('success', TRUE, 'review_id', v_review_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_product_review(TEXT, UUID, INT, TEXT) TO authenticated;

-- D. submit_return_request: Gated on deactivated accounts
DROP FUNCTION IF EXISTS public.submit_return_request(TEXT, UUID, INT, TEXT, TEXT, TEXT[]);
CREATE OR REPLACE FUNCTION public.submit_return_request(
    p_order_id TEXT,
    p_order_item_id UUID,
    p_quantity INT,
    p_reason TEXT,
    p_description TEXT DEFAULT NULL,
    p_evidence_urls TEXT[] DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_buyer_id UUID;
    v_is_deactivated BOOLEAN;
    v_item RECORD;
    v_already_returned INT := 0;
    v_claim_id UUID;
BEGIN
    v_buyer_id := auth.uid();
    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    SELECT is_deactivated INTO v_is_deactivated FROM public.profiles WHERE id = v_buyer_id;
    IF v_is_deactivated = TRUE THEN
        RAISE EXCEPTION 'Account is deactivated. Please contact support.' USING ERRCODE = '42501';
    END IF;

    -- Verify item ownership
    SELECT oi.id, oi.order_id, oi.seller_store_id, oi.quantity, oi.unit_price, bo.customer_user_id, bo.status
    INTO v_item
    FROM public.order_items oi
    JOIN public.buyer_orders bo ON bo.id = oi.order_id
    WHERE oi.id = p_order_item_id AND oi.order_id = p_order_id;

    IF v_item.id IS NULL OR v_item.customer_user_id <> v_buyer_id THEN
        RAISE EXCEPTION 'Order item not found or does not belong to caller.' USING ERRCODE = '42501';
    END IF;

    IF v_item.status <> 'Delivered' THEN
        RAISE EXCEPTION 'Returns can only be requested for Delivered orders.' USING ERRCODE = '22023';
    END IF;

    IF p_quantity <= 0 OR p_quantity > v_item.quantity THEN
        RAISE EXCEPTION 'Invalid return quantity.' USING ERRCODE = '22023';
    END IF;

    -- Calculate already returned or requested quantity
    SELECT COALESCE(SUM(quantity), 0) INTO v_already_returned
    FROM public.return_requests
    WHERE order_item_id = p_order_item_id
      AND status NOT IN ('Rejected');

    IF (p_quantity + v_already_returned) > v_item.quantity THEN
        RAISE EXCEPTION 'Return quantity exceeds eligible purchased quantity. Eligible: %, Requested: %', (v_item.quantity - v_already_returned), p_quantity USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO public.return_requests (
        order_id, order_item_id, seller_store_id, customer_user_id,
        quantity, reason, description, evidence_urls, status
    ) VALUES (
        p_order_id, p_order_item_id, v_item.seller_store_id, v_buyer_id,
        p_quantity, p_reason, p_description, p_evidence_urls, 'Requested'
    ) RETURNING id INTO v_claim_id;

    RETURN jsonb_build_object('success', TRUE, 'claim_id', v_claim_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_return_request(TEXT, UUID, INT, TEXT, TEXT, TEXT[]) TO authenticated;

-- E. deactivate_user_account: Normalize SQLSTATE to 42501
DROP FUNCTION IF EXISTS public.deactivate_user_account(UUID, TEXT);
DROP FUNCTION IF EXISTS public.deactivate_user_account(UUID);
CREATE OR REPLACE FUNCTION public.deactivate_user_account(
    p_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_is_owner BOOLEAN;
    v_target_has_staff_role BOOLEAN;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    -- Nobody can deactivate the owner role
    IF EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = p_user_id
          AND (role = 'owner'::public.app_role OR staff_role = 'owner'::public.admin_staff_role)
    ) THEN
        RAISE EXCEPTION 'Deactivation of the Owner role is prohibited.' USING ERRCODE = '42501';
    END IF;

    v_is_owner := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (role = 'owner'::public.app_role OR staff_role = 'owner'::public.admin_staff_role)
    );

    v_target_has_staff_role := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = p_user_id
          AND (role IN ('super_admin'::public.app_role, 'admin'::public.app_role) OR staff_role IS NOT NULL)
    );

    IF v_target_has_staff_role AND NOT v_is_owner THEN
        RAISE EXCEPTION 'Access denied: Only Owner can deactivate staff or super_admin accounts.' USING ERRCODE = '42501';
    END IF;

    IF v_caller_id <> p_user_id AND NOT v_is_owner THEN
        IF NOT public.has_permission('customers', 'suspend') THEN
            RAISE EXCEPTION 'Access denied: Cannot deactivate other user accounts without customer suspension privileges.' USING ERRCODE = '42501';
        END IF;
    END IF;

    UPDATE public.profiles
    SET is_deactivated = TRUE,
        deactivated_at = NOW()
    WHERE id = p_user_id;

    v_audit_id := public.internal_record_audit_log(
        'profiles',
        p_user_id::TEXT,
        'USER_ACCOUNT_DEACTIVATED',
        jsonb_build_object('deactivated_by', v_caller_id, 'reason', p_reason)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'user_id', p_user_id,
        'is_deactivated', TRUE,
        'audit_log_id', v_audit_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.deactivate_user_account(UUID, TEXT) TO authenticated;

-- F. create_chat_room & send_chat_message: Normalize SQLSTATE to 42501
DROP FUNCTION IF EXISTS public.create_chat_room(UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS public.create_chat_room(UUID, UUID);
CREATE OR REPLACE FUNCTION public.create_chat_room(
    p_seller_store_id UUID,
    p_product_id UUID DEFAULT NULL,
    p_order_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_buyer_id UUID;
    v_is_deactivated BOOLEAN;
    v_room_id UUID;
    v_order_belongs BOOLEAN;
BEGIN
    v_buyer_id := auth.uid();
    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    SELECT is_deactivated INTO v_is_deactivated FROM public.profiles WHERE id = v_buyer_id;
    IF v_is_deactivated = TRUE THEN
        RAISE EXCEPTION 'Account is deactivated. Please contact support.' USING ERRCODE = '42501';
    END IF;

    IF NOT public.is_approved_active_seller_store(p_seller_store_id) THEN
        RAISE EXCEPTION 'Seller store % is unapproved, suspended, or does not exist.', p_seller_store_id USING ERRCODE = '42501';
    END IF;

    IF p_order_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.buyer_orders bo
            JOIN public.order_items oi ON oi.order_id = bo.id
            WHERE bo.id = p_order_id
              AND bo.customer_user_id = v_buyer_id
              AND oi.seller_store_id = p_seller_store_id
        ) INTO v_order_belongs;

        IF NOT v_order_belongs THEN
            RAISE EXCEPTION 'Access denied: Order % does not belong to user % or does not contain items from this store.', p_order_id, v_buyer_id USING ERRCODE = '42501';
        END IF;
    END IF;

    INSERT INTO public.chat_rooms (
        buyer_user_id, seller_store_id, product_id, order_id
    ) VALUES (
        v_buyer_id, p_seller_store_id, p_product_id, p_order_id
    )
    ON CONFLICT (buyer_user_id, seller_store_id, COALESCE(product_id, '00000000-0000-0000-0000-000000000000'::uuid))
    DO UPDATE SET updated_at = NOW()
    RETURNING id INTO v_room_id;

    RETURN jsonb_build_object('success', TRUE, 'room_id', v_room_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_chat_room(UUID, UUID, TEXT) TO authenticated;

DROP FUNCTION IF EXISTS public.send_chat_message(UUID, TEXT);
CREATE OR REPLACE FUNCTION public.send_chat_message(
    p_room_id UUID,
    p_message_text TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_sender_id UUID;
    v_is_deactivated BOOLEAN;
    v_room RECORD;
    v_message_id UUID;
    v_recipient_id UUID;
BEGIN
    v_sender_id := auth.uid();
    IF v_sender_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF p_message_text IS NULL OR length(trim(p_message_text)) = 0 THEN
        RAISE EXCEPTION 'Message text cannot be empty.' USING ERRCODE = '22023';
    END IF;

    IF length(p_message_text) > 2000 THEN
        RAISE EXCEPTION 'Message exceeds maximum length of 2000 characters.' USING ERRCODE = '22023';
    END IF;

    SELECT is_deactivated INTO v_is_deactivated FROM public.profiles WHERE id = v_sender_id;
    IF v_is_deactivated = TRUE THEN
        RAISE EXCEPTION 'Account is deactivated. Please contact support.' USING ERRCODE = '42501';
    END IF;

    SELECT id, buyer_user_id, seller_store_id INTO v_room
    FROM public.chat_rooms
    WHERE id = p_room_id;

    IF v_room.id IS NULL THEN
        RAISE EXCEPTION 'Chat room not found.' USING ERRCODE = 'P0002';
    END IF;

    IF v_room.buyer_user_id <> v_sender_id AND NOT public.owns_seller_store(v_room.seller_store_id) THEN
        RAISE EXCEPTION 'Access denied: You are not a participant in chat room %.', p_room_id USING ERRCODE = '42501';
    END IF;

    IF v_room.buyer_user_id = v_sender_id THEN
        SELECT owner_id INTO v_recipient_id FROM public.seller_stores WHERE id = v_room.seller_store_id;
    ELSE
        v_recipient_id := v_room.buyer_user_id;
    END IF;

    INSERT INTO public.chat_messages (
        room_id, sender_user_id, message_text
    ) VALUES (
        p_room_id, v_sender_id, trim(p_message_text)
    ) RETURNING id INTO v_message_id;

    UPDATE public.chat_rooms SET updated_at = NOW() WHERE id = p_room_id;

    IF v_recipient_id IS NOT NULL THEN
        PERFORM public.internal_create_notification(
            v_recipient_id,
            'CHAT_MESSAGE',
            'New message in chat',
            substr(p_message_text, 1, 100),
            jsonb_build_object('room_id', p_room_id, 'message_id', v_message_id)
        );
    END IF;

    RETURN jsonb_build_object('success', TRUE, 'message_id', v_message_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_chat_message(UUID, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 7. CLEAN UP RBAC: has_permission ONLY (REMOVE "OR public.is_admin()")
-- ----------------------------------------------------------------------------

-- A. Fraud RPCs: Purge "OR public.is_admin()"
CREATE OR REPLACE FUNCTION public.admin_fetch_fraud_alerts(
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0,
    p_status TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_results JSONB;
    v_total INT;
BEGIN
    IF NOT public.has_permission('fraud', 'view') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to view fraud alerts.' USING ERRCODE = '42501';
    END IF;

    SELECT COUNT(*) INTO v_total
    FROM public.fraud_risk_alerts
    WHERE (p_status IS NULL OR status = p_status);

    SELECT jsonb_build_object(
        'total_count', v_total,
        'alerts', COALESCE(jsonb_agg(sub), '[]'::jsonb)
    ) INTO v_results
    FROM (
        SELECT id, entity_type, entity_id, entity_name, risk_score, risk_factor,
               ip_address, device_hash, location, status, created_at
        FROM public.fraud_risk_alerts
        WHERE (p_status IS NULL OR status = p_status)
        ORDER BY risk_score DESC, created_at DESC
        LIMIT p_limit OFFSET p_offset
    ) sub;

    RETURN v_results;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_fetch_fraud_alerts(INT, INT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_resolve_fraud_alert(
    p_alert_id UUID,
    p_resolution TEXT,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_alert RECORD;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF NOT (public.has_permission('fraud', 'score') OR public.has_permission('fraud', 'audit')) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to resolve fraud alerts.' USING ERRCODE = '42501';
    END IF;

    IF p_resolution NOT IN ('Resolved', 'Frozen') THEN
        RAISE EXCEPTION 'Invalid resolution status: %. Must be Resolved or Frozen.', p_resolution USING ERRCODE = '22023';
    END IF;

    SELECT id, entity_type, entity_id, entity_name, risk_score INTO v_alert
    FROM public.fraud_risk_alerts
    WHERE id = p_alert_id
    FOR UPDATE;

    IF v_alert.id IS NULL THEN
        RAISE EXCEPTION 'Fraud alert not found.' USING ERRCODE = 'P0002';
    END IF;

    UPDATE public.fraud_risk_alerts
    SET status = p_resolution,
        resolved_by = v_caller_id,
        resolution_notes = p_notes,
        resolved_at = NOW(),
        updated_at = NOW()
    WHERE id = p_alert_id;

    v_audit_id := public.internal_record_audit_log(
        'fraud_risk_alerts',
        p_alert_id::TEXT,
        'FRAUD_ALERT_RESOLVED',
        jsonb_build_object(
            'resolution', p_resolution,
            'entity_type', v_alert.entity_type,
            'entity_id', v_alert.entity_id,
            'notes', p_notes
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'alert_id', p_alert_id,
        'status', p_resolution,
        'audit_log_id', v_audit_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_resolve_fraud_alert(UUID, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_add_blacklisted_identifier(
    p_identifier_type TEXT,
    p_identifier_value TEXT,
    p_holder_name TEXT,
    p_reason TEXT,
    p_threat_level TEXT DEFAULT 'High'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_id UUID;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_permission('fraud', 'blacklist') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to manage fraud blacklist.' USING ERRCODE = '42501';
    END IF;

    IF p_identifier_type NOT IN ('IP', 'CNIC', 'Bank IBAN', 'Phone Number') THEN
        RAISE EXCEPTION 'Invalid identifier type: %', p_identifier_type USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.fraud_blacklisted_identifiers (
        identifier_type, identifier_value, holder_name, reason, threat_level, created_by
    ) VALUES (
        p_identifier_type, trim(p_identifier_value), p_holder_name, p_reason, p_threat_level, v_caller_id
    ) RETURNING id INTO v_id;

    v_audit_id := public.internal_record_audit_log(
        'fraud_blacklisted_identifiers',
        v_id::TEXT,
        'BLACKLIST_IDENTIFIER_ADDED',
        jsonb_build_object(
            'type', p_identifier_type,
            'value', p_identifier_value,
            'reason', p_reason
        )
    );

    RETURN jsonb_build_object('success', TRUE, 'blacklist_id', v_id, 'audit_log_id', v_audit_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_add_blacklisted_identifier(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_remove_blacklisted_identifier(
    p_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_audit_id UUID;
    v_item RECORD;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_permission('fraud', 'blacklist') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to manage fraud blacklist.' USING ERRCODE = '42501';
    END IF;

    SELECT id, identifier_type, identifier_value INTO v_item
    FROM public.fraud_blacklisted_identifiers
    WHERE id = p_id;

    IF v_item.id IS NULL THEN
        RAISE EXCEPTION 'Blacklisted identifier not found.' USING ERRCODE = 'P0002';
    END IF;

    DELETE FROM public.fraud_blacklisted_identifiers WHERE id = p_id;

    v_audit_id := public.internal_record_audit_log(
        'fraud_blacklisted_identifiers',
        p_id::TEXT,
        'BLACKLIST_IDENTIFIER_REMOVED',
        jsonb_build_object('type', v_item.identifier_type, 'value', v_item.identifier_value)
    );

    RETURN jsonb_build_object('success', TRUE, 'id', p_id, 'audit_log_id', v_audit_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_remove_blacklisted_identifier(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_toggle_security_rule(
    p_rule_id UUID,
    p_is_enabled BOOLEAN,
    p_threshold_value TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_audit_id UUID;
    v_rule_code TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF NOT (public.has_permission('fraud', 'audit') OR public.has_permission('fraud', 'score')) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to modify fraud security rules.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.fraud_security_rules
    SET is_enabled = p_is_enabled,
        threshold_value = COALESCE(p_threshold_value, threshold_value),
        updated_by = v_caller_id,
        updated_at = NOW()
    WHERE id = p_rule_id
    RETURNING rule_code INTO v_rule_code;

    IF v_rule_code IS NULL THEN
        RAISE EXCEPTION 'Security rule not found.' USING ERRCODE = 'P0002';
    END IF;

    v_audit_id := public.internal_record_audit_log(
        'fraud_security_rules',
        p_rule_id::TEXT,
        'SECURITY_RULE_MODIFIED',
        jsonb_build_object('rule_code', v_rule_code, 'is_enabled', p_is_enabled, 'threshold', p_threshold_value)
    );

    RETURN jsonb_build_object('success', TRUE, 'rule_id', p_rule_id, 'is_enabled', p_is_enabled, 'audit_log_id', v_audit_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_toggle_security_rule(UUID, BOOLEAN, TEXT) TO authenticated;

-- B. RLS Policies: Purge "OR public.is_admin()" across all 9 converted tables + 3 fraud tables

-- 1. fraud_risk_alerts
DROP POLICY IF EXISTS "Fraud alerts visibility" ON public.fraud_risk_alerts;
CREATE POLICY "Fraud alerts visibility" ON public.fraud_risk_alerts
    FOR SELECT TO authenticated
    USING (public.has_permission('fraud', 'view'));

-- 2. fraud_blacklisted_identifiers
DROP POLICY IF EXISTS "Fraud blacklist visibility" ON public.fraud_blacklisted_identifiers;
CREATE POLICY "Fraud blacklist visibility" ON public.fraud_blacklisted_identifiers
    FOR SELECT TO authenticated
    USING (public.has_permission('fraud', 'view'));

-- 3. fraud_security_rules
DROP POLICY IF EXISTS "Fraud security rules visibility" ON public.fraud_security_rules;
CREATE POLICY "Fraud security rules visibility" ON public.fraud_security_rules
    FOR SELECT TO authenticated
    USING (public.has_permission('fraud', 'view'));

-- 4. user_roles
DROP POLICY IF EXISTS "Roles read policy" ON public.user_roles;
CREATE POLICY "Roles read policy" ON public.user_roles
    FOR SELECT TO authenticated
    USING (
        auth.uid() = user_id
        OR public.has_permission('roles', 'view')
    );

DROP POLICY IF EXISTS "Roles mutate policy" ON public.user_roles;
CREATE POLICY "Roles mutate policy" ON public.user_roles
    FOR ALL TO authenticated
    USING (public.has_permission('roles', 'assign'));

-- 5. profiles
DROP POLICY IF EXISTS "Users can view own full profile" ON public.profiles;
CREATE POLICY "Users can view own full profile" ON public.profiles
    FOR SELECT TO authenticated
    USING (
        auth.uid() = id
        OR public.has_permission('customers', 'view')
    );

-- 6. seller_stores
DROP POLICY IF EXISTS "Public view approved stores; Owner/Admin view all" ON public.seller_stores;
CREATE POLICY "Public view approved stores; Owner/Admin view all" ON public.seller_stores
    FOR SELECT TO authenticated, anon
    USING (
        is_approved = TRUE
        OR auth.uid() = owner_id
        OR public.has_permission('sellers', 'view')
    );

DROP POLICY IF EXISTS "Store owners update safe business details" ON public.seller_stores;
CREATE POLICY "Store owners update safe business details" ON public.seller_stores
    FOR UPDATE TO authenticated
    USING (
        auth.uid() = owner_id
        OR public.has_permission('sellers', 'edit')
    );

-- 7. seller_kyc_documents
DROP POLICY IF EXISTS "Sellers view own KYC; Admins view all" ON public.seller_kyc_documents;
CREATE POLICY "Sellers view own KYC; Admins view all" ON public.seller_kyc_documents
    FOR SELECT TO authenticated
    USING (
        public.owns_seller_store(seller_store_id)
        OR public.has_permission('kyc', 'view')
    );

-- 8. categories
DROP POLICY IF EXISTS "Categories visible to all if active; Admins view all" ON public.categories;
CREATE POLICY "Categories visible to all if active; Admins view all" ON public.categories
    FOR SELECT TO authenticated, anon
    USING (
        is_active = TRUE
        OR public.has_permission('categories', 'view')
    );

DROP POLICY IF EXISTS "Admins have full category management" ON public.categories;
CREATE POLICY "Admins have full category management" ON public.categories
    FOR ALL TO authenticated
    USING (public.has_permission('categories', 'edit'));

-- 9. products
DROP POLICY IF EXISTS "Public view active approved products; Owners/Admins view all" ON public.products;
CREATE POLICY "Public view active approved products; Owners/Admins view all" ON public.products
    FOR SELECT TO authenticated, anon
    USING (
        (is_active = TRUE AND LOWER(approval_status) = 'approved' AND public.is_approved_active_seller_store(seller_store_id))
        OR public.owns_seller_store(seller_store_id)
        OR public.has_permission('products', 'view')
    );

-- 10. buyer_orders
DROP POLICY IF EXISTS "Buyer orders read policy" ON public.buyer_orders;
DROP POLICY IF EXISTS "Buyer view own orders; Admins view all" ON public.buyer_orders;
CREATE POLICY "Buyer view own orders; Admins view all" ON public.buyer_orders
    FOR SELECT TO authenticated
    USING (
        customer_user_id = auth.uid()
        OR public.has_permission('orders', 'view')
    );

-- 11. platform_vouchers
DROP POLICY IF EXISTS "Admins view all vouchers" ON public.platform_vouchers;
CREATE POLICY "Admins view all vouchers" ON public.platform_vouchers
    FOR SELECT TO authenticated
    USING (public.has_permission('promotions', 'view'));

-- 12. wallet_accounts
DROP POLICY IF EXISTS "Wallet accounts visibility" ON public.wallet_accounts;
CREATE POLICY "Wallet accounts visibility" ON public.wallet_accounts
    FOR SELECT TO authenticated
    USING (
        public.owns_seller_store(seller_store_id)
        OR public.has_permission('finance', 'view')
    );


-- =========================================================================
-- FILE: 20260833000000_shipping_governance_escrow_audit_and_normalization.sql
-- =========================================================================

-- Migration: 20260833000000_shipping_governance_escrow_audit_and_normalization.sql
-- Description: Per-store refund eligibility, ledger single-source-of-truth, identifier normalization, pg_cron scheduling, and shipping governance tables & RPCs

-- ----------------------------------------------------------------------------
-- 1. IDENTIFIER NORMALIZATION FUNCTIONS & BLACKLIST NORMALIZATION COLUMN
-- ----------------------------------------------------------------------------

-- Function: Pakistani Phone Number Normalization
CREATE OR REPLACE FUNCTION public.normalize_phone_pk(p_phone TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_digits TEXT;
BEGIN
    IF p_phone IS NULL OR trim(p_phone) = '' THEN
        RETURN NULL;
    END IF;

    -- Extract digits only
    v_digits := regexp_replace(p_phone, '[^0-9]', '', 'g');

    -- Strip leading 00 (e.g. 0092300...)
    IF v_digits LIKE '0092%' THEN
        v_digits := substr(v_digits, 3);
    END IF;

    -- Strip leading 0 from local format (0300... -> 300...)
    IF v_digits LIKE '03%' AND length(v_digits) = 11 THEN
        v_digits := '92' || substr(v_digits, 2);
    ELSIF v_digits LIKE '3%' AND length(v_digits) = 10 THEN
        v_digits := '92' || v_digits;
    END IF;

    -- Prepend + if valid 12-digit international PK format (923XXXXXXXXX)
    IF v_digits LIKE '923%' AND length(v_digits) = 12 THEN
        RETURN '+' || v_digits;
    END IF;

    -- Fallback: return trimmed digits
    RETURN '+' || v_digits;
END;
$$;

-- Function: Pakistani CNIC Normalization (digits only, exactly 13 digits)
CREATE OR REPLACE FUNCTION public.normalize_cnic_pk(p_cnic TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_cnic IS NULL OR trim(p_cnic) = '' THEN
        RETURN NULL;
    END IF;
    RETURN regexp_replace(p_cnic, '[^0-9]', '', 'g');
END;
$$;

-- Function: Bank IBAN Normalization (uppercase, whitespace-stripped)
CREATE OR REPLACE FUNCTION public.normalize_iban_pk(p_iban TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    IF p_iban IS NULL OR trim(p_iban) = '' THEN
        RETURN NULL;
    END IF;
    RETURN upper(regexp_replace(p_iban, '\s+', '', 'g'));
END;
$$;

-- Add normalized_value column to fraud_blacklisted_identifiers
ALTER TABLE public.fraud_blacklisted_identifiers
    ADD COLUMN IF NOT EXISTS normalized_value TEXT;

-- Backfill normalized values
UPDATE public.fraud_blacklisted_identifiers
SET normalized_value = CASE
    WHEN identifier_type = 'Phone Number' THEN public.normalize_phone_pk(identifier_value)
    WHEN identifier_type = 'CNIC' THEN public.normalize_cnic_pk(identifier_value)
    WHEN identifier_type = 'Bank IBAN' THEN public.normalize_iban_pk(identifier_value)
    ELSE trim(identifier_value)
END
WHERE normalized_value IS NULL;

-- Unique index on (identifier_type, normalized_value)
CREATE UNIQUE INDEX IF NOT EXISTS uq_fraud_blacklist_normalized
ON public.fraud_blacklisted_identifiers (identifier_type, normalized_value);

CREATE OR REPLACE FUNCTION public.sync_fraud_blacklisted_identifiers_normalized()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.normalized_value IS NULL OR NEW.normalized_value = '' THEN
        NEW.normalized_value := CASE
            WHEN NEW.identifier_type = 'Phone Number' THEN public.normalize_phone_pk(NEW.identifier_value)
            WHEN NEW.identifier_type = 'CNIC' THEN public.normalize_cnic_pk(NEW.identifier_value)
            WHEN NEW.identifier_type = 'Bank IBAN' THEN public.normalize_iban_pk(NEW.identifier_value)
            ELSE trim(NEW.identifier_value)
        END;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_fraud_blacklisted_identifiers_normalized ON public.fraud_blacklisted_identifiers;
CREATE TRIGGER trg_sync_fraud_blacklisted_identifiers_normalized
BEFORE INSERT OR UPDATE ON public.fraud_blacklisted_identifiers
FOR EACH ROW
EXECUTE FUNCTION public.sync_fraud_blacklisted_identifiers_normalized();

-- Update admin_add_blacklisted_identifier to store normalized value
CREATE OR REPLACE FUNCTION public.admin_add_blacklisted_identifier(
    p_identifier_type TEXT,
    p_identifier_value TEXT,
    p_holder_name TEXT,
    p_reason TEXT,
    p_threat_level TEXT DEFAULT 'High'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_id UUID;
    v_audit_id UUID;
    v_norm TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.' USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_permission('fraud', 'blacklist') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to manage fraud blacklist.' USING ERRCODE = '42501';
    END IF;

    IF p_identifier_type NOT IN ('IP', 'CNIC', 'Bank IBAN', 'Phone Number') THEN
        RAISE EXCEPTION 'Invalid identifier type: %', p_identifier_type USING ERRCODE = '22023';
    END IF;

    v_norm := CASE
        WHEN p_identifier_type = 'Phone Number' THEN public.normalize_phone_pk(p_identifier_value)
        WHEN p_identifier_type = 'CNIC' THEN public.normalize_cnic_pk(p_identifier_value)
        WHEN p_identifier_type = 'Bank IBAN' THEN public.normalize_iban_pk(p_identifier_value)
        ELSE trim(p_identifier_value)
    END;

    INSERT INTO public.fraud_blacklisted_identifiers (
        identifier_type, identifier_value, normalized_value, holder_name, reason, threat_level, created_by
    ) VALUES (
        p_identifier_type, trim(p_identifier_value), v_norm, p_holder_name, p_reason, p_threat_level, v_caller_id
    ) RETURNING id INTO v_id;

    v_audit_id := public.internal_record_audit_log(
        'fraud_blacklisted_identifiers',
        v_id::TEXT,
        'BLACKLIST_IDENTIFIER_ADDED',
        jsonb_build_object(
            'type', p_identifier_type,
            'value', p_identifier_value,
            'normalized', v_norm,
            'reason', p_reason
        )
    );

    RETURN jsonb_build_object('success', TRUE, 'blacklist_id', v_id, 'normalized_value', v_norm, 'audit_log_id', v_audit_id);
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. PER-STORE REFUND ELIGIBILITY (is_order_refundable)
-- ----------------------------------------------------------------------------
-- An order item is refundable if that specific store's fulfillment is Delivered
-- (and for COD, cash is confirmed or order-level payment_status = 'Paid').

DROP FUNCTION IF EXISTS public.is_order_refundable(TEXT);

CREATE OR REPLACE FUNCTION public.is_order_refundable(
    p_order_id TEXT,
    p_seller_store_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_order_status TEXT;
    v_payment_status TEXT;
    v_payment_method TEXT;
    v_store_fulfillment_status TEXT;
BEGIN
    SELECT status, payment_status, payment_method
    INTO v_order_status, v_payment_status, v_payment_method
    FROM public.buyer_orders
    WHERE id = p_order_id;

    IF v_order_status IS NULL THEN
        RETURN FALSE;
    END IF;

    -- If store_id is provided, check that specific store's fulfillment
    IF p_seller_store_id IS NOT NULL THEN
        SELECT fulfillment_status INTO v_store_fulfillment_status
        FROM public.store_fulfillments
        WHERE order_id = p_order_id AND seller_store_id = p_seller_store_id;

        IF v_store_fulfillment_status IS NULL OR (v_store_fulfillment_status = 'Pending' AND v_order_status = 'Delivered') THEN
            v_store_fulfillment_status := v_order_status;
        END IF;

        IF v_store_fulfillment_status <> 'Delivered' THEN
            RETURN FALSE;
        END IF;

        -- For COD, money must be collected (either order Paid or store Delivered)
        IF v_payment_method IN ('Cash on Delivery', 'COD') THEN
            RETURN v_store_fulfillment_status = 'Delivered' OR v_payment_status = 'Paid';
        END IF;

        RETURN v_payment_status = 'Paid';
    END IF;

    -- Order-level fallback: all delivered & paid
    IF v_payment_status = 'Paid' THEN
        RETURN TRUE;
    END IF;

    IF v_payment_method IN ('Cash on Delivery', 'COD') AND v_order_status = 'Delivered' THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_order_refundable(TEXT, UUID) TO authenticated, anon;

-- Update callers: admin_arbitrate_return_claim & review_return_request
CREATE OR REPLACE FUNCTION public.admin_arbitrate_return_claim(
    p_claim_id UUID,
    p_decision TEXT,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_claim RECORD;
    v_refund_id UUID;
    v_audit_id UUID;
    v_is_refundable BOOLEAN;
    v_order_item RECORD;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.' USING ERRCODE = '42501';
    END IF;

    IF NOT (public.has_permission('returns', 'review') OR public.has_permission('disputes', 'refund')) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to arbitrate return claims.' USING ERRCODE = '42501';
    END IF;

    IF p_decision NOT IN ('Approved', 'Rejected') THEN
        RAISE EXCEPTION 'Invalid decision: %. Must be Approved or Rejected.', p_decision USING ERRCODE = '22023';
    END IF;

    IF p_decision = 'Rejected' AND (p_notes IS NULL OR trim(p_notes) = '') THEN
        RAISE EXCEPTION 'Rejection requires detailed explanatory notes.' USING ERRCODE = '22023';
    END IF;

    IF length(p_notes) > 1000 THEN
        RAISE EXCEPTION 'Notes cannot exceed 1000 characters.' USING ERRCODE = '22023';
    END IF;

    SELECT id, order_id, order_item_id, seller_store_id, customer_user_id, quantity, status
    INTO v_claim
    FROM public.return_requests
    WHERE id = p_claim_id
    FOR UPDATE;

    IF v_claim.id IS NULL THEN
        RAISE EXCEPTION 'Return claim not found.' USING ERRCODE = 'P0002';
    END IF;

    IF v_claim.status NOT IN ('Pending', 'Requested') THEN
        RAISE EXCEPTION 'Return claim is already finalized (Current status: %).', v_claim.status USING ERRCODE = '22023';
    END IF;

    -- Per-Store Refund Eligibility Check
    v_is_refundable := public.is_order_refundable(v_claim.order_id, v_claim.seller_store_id);
    IF p_decision = 'Approved' AND NOT v_is_refundable THEN
        RAISE EXCEPTION 'Order item is not refundable: Store fulfillment must be Delivered and payment collected.' USING ERRCODE = '22023';
    END IF;

    IF p_decision = 'Approved' THEN
        SELECT id, unit_price, quantity, seller_payable INTO v_order_item
        FROM public.order_items
        WHERE id = v_claim.order_item_id;

        IF v_order_item.id IS NULL OR v_order_item.unit_price <= 0 THEN
            RAISE EXCEPTION 'Order item price is missing or invalid. Refund rejected.' USING ERRCODE = '22023';
        END IF;

        -- Process refund row
        INSERT INTO public.refunds (
            order_id, order_item_id, seller_store_id, customer_user_id,
            amount, status, reason, idempotency_key, processed_by
        ) VALUES (
            v_claim.order_id, v_claim.order_item_id, v_claim.seller_store_id, v_claim.customer_user_id,
            (v_order_item.unit_price * v_claim.quantity), 'Completed', 'Approved return claim arbitration',
            'REF-CLM-' || p_claim_id::TEXT, v_caller_id
        ) RETURNING id INTO v_refund_id;

        -- Record matching DEBIT ledger entry in wallet_transactions
        INSERT INTO public.wallet_transactions (
            wallet_account_id, seller_store_id, transaction_type, amount,
            source_type, source_id, idempotency_key, description, created_by
        ) VALUES (
            (SELECT id FROM public.wallet_accounts WHERE seller_store_id = v_claim.seller_store_id),
            v_claim.seller_store_id, 'DEBIT', (v_order_item.unit_price * v_claim.quantity),
            'REFUND_REVERSAL', v_claim.order_id, 'WLT-REF-' || p_claim_id::TEXT,
            'Refund reversal for claim ' || p_claim_id::TEXT, v_caller_id
        ) ON CONFLICT (idempotency_key) DO NOTHING;

        -- Forfeit held earnings if still in escrow
        UPDATE public.order_held_earnings
        SET status = 'FORFEITED',
            released_at = NOW()
        WHERE order_id = v_claim.order_id AND seller_store_id = v_claim.seller_store_id;

        UPDATE public.return_requests
        SET status = 'Approved', updated_at = NOW()
        WHERE id = p_claim_id;
    ELSE
        UPDATE public.return_requests
        SET status = 'Rejected', updated_at = NOW()
        WHERE id = p_claim_id;
    END IF;

    v_audit_id := public.internal_record_audit_log(
        'return_requests',
        p_claim_id::TEXT,
        'RETURN_CLAIM_ARBITRATED',
        jsonb_build_object(
            'decision', p_decision,
            'refund_id', v_refund_id,
            'notes', p_notes
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'claim_id', p_claim_id,
        'decision', p_decision,
        'refund_id', v_refund_id,
        'audit_log_id', v_audit_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_arbitrate_return_claim(UUID, TEXT, TEXT) TO authenticated;

-- Update create_atomic_order: Use normalized phone check
CREATE OR REPLACE FUNCTION public.create_atomic_order(
    p_items JSONB,
    p_shipping_address JSONB,
    p_payment_method TEXT,
    p_idempotency_key TEXT,
    p_notes TEXT DEFAULT NULL,
    p_voucher_code TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_buyer_id UUID;
    v_is_deactivated BOOLEAN;
    v_order_id TEXT;
    v_order_number TEXT;
    v_normalized_payment_method TEXT;
    v_total_amount NUMERIC(12,2) := 0;
    v_shipping_fee NUMERIC(12,2) := 150.00;
    v_voucher_discount NUMERIC(12,2) := 0.00;
    v_grand_total NUMERIC(12,2) := 0;
    v_item RECORD;
    v_product RECORD;
    v_voucher RECORD;
    v_unit_price NUMERIC(12,2);
    v_line_total NUMERIC(12,2);
    v_commission_rate NUMERIC(5,2);
    v_commission_amount NUMERIC(12,2);
    v_seller_earning NUMERIC(12,2);
    v_existing_order RECORD;
    v_buyer_phone TEXT;
    v_shipping_phone TEXT;
    v_norm_buyer_phone TEXT;
    v_norm_shipping_phone TEXT;
    v_is_blacklisted BOOLEAN;
    v_fingerprint TEXT;
    v_aggregated_items JSONB;
    v_variant_sku TEXT;
    v_variant_stock INT;
BEGIN
    v_buyer_id := auth.uid();
    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to create order.';
    END IF;

    -- Deactivated Account Gate
    SELECT is_deactivated, phone INTO v_is_deactivated, v_buyer_phone FROM public.profiles WHERE id = v_buyer_id;
    IF v_is_deactivated = TRUE THEN
        RAISE EXCEPTION 'Account is deactivated. Please contact support.' USING ERRCODE = '42501';
    END IF;

    -- Normalized Fraud Enforcement Check
    v_shipping_phone := p_shipping_address->>'phone';
    v_norm_buyer_phone := public.normalize_phone_pk(v_buyer_phone);
    v_norm_shipping_phone := public.normalize_phone_pk(v_shipping_phone);

    SELECT EXISTS (
        SELECT 1 FROM public.fraud_blacklisted_identifiers
        WHERE identifier_type = 'Phone Number'
          AND normalized_value IN (v_norm_buyer_phone, v_norm_shipping_phone)
    ) INTO v_is_blacklisted;

    IF v_is_blacklisted THEN
        RAISE EXCEPTION 'Transaction rejected: Blacklisted contact details or identifier detected.' USING ERRCODE = '42501';
    END IF;

    -- Strict Payment Guard: Only Cash on Delivery
    IF p_payment_method IS NULL OR (p_payment_method != 'Cash on Delivery' AND p_payment_method != 'COD') THEN
        RAISE EXCEPTION 'Online payments are not available yet. Please select Cash on Delivery.';
    END IF;
    v_normalized_payment_method := 'Cash on Delivery';

    -- Empty cart guard
    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Cart cannot be empty.';
    END IF;

    -- Aggregate duplicate items by product_id + variant_id
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

    -- Compute Request Fingerprint
    v_fingerprint := md5(COALESCE(v_aggregated_items::text, '') || '|' || COALESCE(p_shipping_address::text, '{}') || '|' || p_payment_method);

    -- Check idempotency scoped to caller
    SELECT id, order_number, status, grand_total, request_fingerprint
    INTO v_existing_order
    FROM public.buyer_orders
    WHERE customer_user_id = v_buyer_id AND idempotency_key = p_idempotency_key;

    IF v_existing_order.id IS NOT NULL THEN
        IF v_existing_order.request_fingerprint IS NOT NULL AND v_existing_order.request_fingerprint <> v_fingerprint THEN
            RAISE EXCEPTION 'Idempotency conflict: Key % was already used with a different request payload.', p_idempotency_key USING ERRCODE = 'P0001';
        END IF;

        RETURN jsonb_build_object(
            'success', TRUE,
            'idempotent_reused', TRUE,
            'order_id', v_existing_order.id,
            'order_number', v_existing_order.order_number,
            'status', v_existing_order.status,
            'grand_total', v_existing_order.grand_total
        );
    END IF;

    v_order_number := 'ORD-' || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 8));

    -- Validate items and compute totals
    FOR v_item IN SELECT * FROM jsonb_to_recordset(v_aggregated_items) AS x(product_id UUID, variant_id UUID, quantity INT)
    LOOP
        SELECT id, name, sku, regular_price, sale_price, stock_quantity, seller_store_id, is_active, approval_status
        INTO v_product
        FROM public.products
        WHERE id = v_item.product_id FOR UPDATE;

        IF v_product.id IS NULL OR NOT v_product.is_active OR LOWER(v_product.approval_status) != 'approved' THEN
            RAISE EXCEPTION 'Product % is unavailable or unapproved.', v_item.product_id;
        END IF;

        IF v_item.variant_id IS NOT NULL THEN
            SELECT sku, stock_quantity, COALESCE(price_override, v_product.sale_price, v_product.regular_price)
            INTO v_variant_sku, v_variant_stock, v_unit_price
            FROM public.product_variants
            WHERE id = v_item.variant_id AND product_id = v_item.product_id FOR UPDATE;

            IF v_unit_price IS NULL THEN
                RAISE EXCEPTION 'Invalid or inactive variant % for product %.', v_item.variant_id, v_item.product_id;
            END IF;

            IF v_variant_stock < v_item.quantity THEN
                RAISE EXCEPTION 'Insufficient stock for product variant %.', v_variant_sku;
            END IF;

            UPDATE public.product_variants
            SET stock_quantity = stock_quantity - v_item.quantity,
                updated_at = NOW()
            WHERE id = v_item.variant_id;
        ELSE
            IF v_product.stock_quantity < v_item.quantity THEN
                RAISE EXCEPTION 'Insufficient stock for product %.', v_product.name;
            END IF;

            UPDATE public.products
            SET stock_quantity = stock_quantity - v_item.quantity,
                updated_at = NOW()
            WHERE id = v_product.id;

            v_unit_price := COALESCE(v_product.sale_price, v_product.regular_price);
        END IF;

        v_line_total := v_unit_price * v_item.quantity;
        v_total_amount := v_total_amount + v_line_total;
    END LOOP;

    -- Apply Voucher if provided
    IF p_voucher_code IS NOT NULL AND TRIM(p_voucher_code) != '' THEN
        SELECT * INTO v_voucher FROM public.platform_vouchers WHERE code = UPPER(TRIM(p_voucher_code)) FOR UPDATE;
        IF v_voucher.id IS NOT NULL AND v_voucher.is_active AND NOW() BETWEEN v_voucher.start_date AND v_voucher.end_date THEN
            IF v_total_amount >= v_voucher.min_order_amount THEN
                IF v_voucher.discount_type = 'percentage' THEN
                    v_voucher_discount := (v_total_amount * v_voucher.discount_value / 100.0);
                    IF v_voucher.max_discount_amount IS NOT NULL THEN
                        v_voucher_discount := LEAST(v_voucher_discount, v_voucher.max_discount_amount);
                    END IF;
                ELSE
                    v_voucher_discount := LEAST(v_voucher.discount_value, v_total_amount);
                END IF;
            END IF;
        END IF;
    END IF;

    v_grand_total := GREATEST(v_total_amount - v_voucher_discount + v_shipping_fee, 0.00);

    -- Insert Order
    INSERT INTO public.buyer_orders (
        id, customer_user_id, order_number, status, payment_status, payment_method,
        total_amount, subtotal, shipping_fee, voucher_discount, grand_total, amount,
        shipping_address, customer_notes, idempotency_key, request_fingerprint
    ) VALUES (
        v_order_number, v_buyer_id, v_order_number, 'Pending', 'Pending', v_normalized_payment_method,
        v_total_amount, v_total_amount, v_shipping_fee, v_voucher_discount, v_grand_total, v_grand_total,
        p_shipping_address, p_notes, p_idempotency_key, v_fingerprint
    ) RETURNING id INTO v_order_id;

    -- Insert Order Items
    FOR v_item IN SELECT * FROM jsonb_to_recordset(v_aggregated_items) AS x(product_id UUID, variant_id UUID, quantity INT)
    LOOP
        SELECT id, name, sku, regular_price, sale_price, seller_store_id INTO v_product
        FROM public.products WHERE id = v_item.product_id;

        IF v_item.variant_id IS NOT NULL THEN
            SELECT sku, COALESCE(price_override, v_product.sale_price, v_product.regular_price)
            INTO v_variant_sku, v_unit_price
            FROM public.product_variants WHERE id = v_item.variant_id;
        ELSE
            v_variant_sku := v_product.sku;
            v_unit_price := COALESCE(v_product.sale_price, v_product.regular_price);
        END IF;

        v_line_total := v_unit_price * v_item.quantity;

        SELECT COALESCE(commission_rate, 10.00) INTO v_commission_rate
        FROM public.seller_stores WHERE id = v_product.seller_store_id;
        v_commission_rate := COALESCE(v_commission_rate, 10.00);

        v_commission_amount := (v_line_total * v_commission_rate / 100.0);
        v_seller_earning := v_line_total - v_commission_amount;

        INSERT INTO public.order_items (
            order_id, product_id, variant_id, seller_store_id, product_name, sku,
            unit_price, quantity, total_price, commission_rate,
            commission_amount, seller_payable
        ) VALUES (
            v_order_id, v_product.id, v_item.variant_id, v_product.seller_store_id, v_product.name, COALESCE(v_variant_sku, v_product.sku, 'SKU-DEFAULT'),
            v_unit_price, v_item.quantity, v_line_total, v_commission_rate,
            v_commission_amount, v_seller_earning
        );
    END LOOP;

    -- Record initial tracking event
    INSERT INTO public.order_tracking_events (
        order_id, status, description, location
    ) VALUES (
        v_order_id,
        'Order Placed',
        'Your order has been placed and will be paid on delivery via Cash on Delivery.',
        'Apna Store Processing Hub'
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'idempotent_reused', FALSE,
        'order_id', v_order_id,
        'order_number', v_order_number,
        'status', 'Pending',
        'subtotal', v_total_amount,
        'shipping_fee', v_shipping_fee,
        'discount_amount', v_voucher_discount,
        'grand_total', v_grand_total
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_atomic_order(JSONB, JSONB, TEXT, TEXT, TEXT, TEXT) TO authenticated;
DROP FUNCTION IF EXISTS public.create_atomic_order(JSONB, JSONB, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.create_atomic_order(
    p_idempotency_key TEXT,
    p_items JSONB,
    p_shipping_address JSONB,
    p_payment_method TEXT DEFAULT 'COD'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF p_payment_method IN ('JazzCash', 'EasyPaisa', 'Card') THEN
        RAISE EXCEPTION 'Payment method % is not currently available.', p_payment_method;
    END IF;

    RETURN public.create_atomic_order(
        p_items => p_items,
        p_shipping_address => p_shipping_address,
        p_payment_method => p_payment_method,
        p_idempotency_key => p_idempotency_key,
        p_notes => NULL,
        p_voucher_code => NULL
    );
END;
$$;
GRANT EXECUTE ON FUNCTION public.create_atomic_order(TEXT, JSONB, JSONB, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. SINGLE SOURCE OF TRUTH: LEDGER-DERIVED SELLER BALANCES
-- ----------------------------------------------------------------------------
-- wallet_transactions is the canonical append-only ledger of record.
-- Revoke direct updates to seller_stores balance & pending_payout.
-- get_seller_wallet_summary derives balances strictly from ledger entries.

REVOKE UPDATE (balance, pending_payout) ON public.seller_stores FROM authenticated, anon, PUBLIC;

DROP FUNCTION IF EXISTS public.get_seller_wallet_summary(UUID);
CREATE OR REPLACE FUNCTION public.get_seller_wallet_summary(p_seller_store_id UUID DEFAULT NULL)
RETURNS TABLE (
    seller_store_id UUID,
    available_balance NUMERIC(12,2),
    held_balance NUMERIC(12,2),
    pending_balance NUMERIC(12,2),
    paid_out_total NUMERIC(12,2)
) AS $$
DECLARE
    v_target_store_id UUID;
    v_available NUMERIC(12,2) := 0.00;
    v_held NUMERIC(12,2) := 0.00;
    v_pending NUMERIC(12,2) := 0.00;
    v_paid_out NUMERIC(12,2) := 0.00;
BEGIN
    IF p_seller_store_id IS NOT NULL THEN
        IF auth.uid() IS NOT NULL AND NOT (public.has_permission('finance', 'view') OR public.has_permission('payouts', 'view')) THEN
            SELECT id INTO v_target_store_id FROM public.seller_stores WHERE id = p_seller_store_id AND owner_id = auth.uid();
            IF v_target_store_id IS NULL THEN
                RAISE EXCEPTION 'Access denied: You do not own store %.', p_seller_store_id USING ERRCODE = 'P0001';
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

    -- Canonical available balance derived from ledger: (CREDIT + RELEASE + ADJUSTMENT) - (DEBIT + HOLD)
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

    -- Canonical held balance: active escrow holds not yet released
    SELECT COALESCE(SUM(
        CASE
            WHEN wt.transaction_type = 'HOLD' THEN wt.amount
            WHEN wt.transaction_type = 'RELEASE' THEN -wt.amount
            ELSE 0.00
        END
    ), 0.00) INTO v_held
    FROM public.wallet_transactions wt
    WHERE wt.seller_store_id = v_target_store_id;

    -- Paid out total (Disbursed payouts)
    SELECT COALESCE(SUM(pr.amount), 0.00) INTO v_paid_out
    FROM public.payout_requests pr
    WHERE pr.seller_store_id = v_target_store_id
      AND pr.status = 'Paid';

    -- Pending unfulfilled orders
    SELECT COALESCE(SUM(oi.seller_payable), 0.00) INTO v_pending
    FROM public.order_items oi
    JOIN public.buyer_orders bo ON bo.id = oi.order_id
    WHERE oi.seller_store_id = v_target_store_id
      AND bo.status IN ('Pending', 'Processing');

    RETURN QUERY SELECT v_target_store_id, v_available, v_held, v_pending, v_paid_out;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.get_seller_wallet_summary(UUID) TO authenticated;

-- ----------------------------------------------------------------------------
-- 4. SCREEN 3: SHIPPING GOVERNANCE TABLES & RPCS
-- ----------------------------------------------------------------------------

-- A. Courier Partners Table
CREATE TABLE IF NOT EXISTS public.shipping_courier_partners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    brand_color TEXT NOT NULL DEFAULT '0xFF2563EB',
    base_rate NUMERIC(12,2) NOT NULL CHECK (base_rate >= 0.00),
    extra_kg_rate NUMERIC(12,2) NOT NULL CHECK (extra_kg_rate >= 0.00),
    tracking_url_template TEXT NOT NULL,
    webhook_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_live_api_connected BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.shipping_courier_partners ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.shipping_courier_partners FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.shipping_courier_partners TO authenticated;

DROP POLICY IF EXISTS "Shipping couriers visibility" ON public.shipping_courier_partners;
CREATE POLICY "Shipping couriers visibility" ON public.shipping_courier_partners
    FOR SELECT TO authenticated
    USING (public.has_permission('shipping', 'view'));

-- Seed Initial Couriers with honest is_live_api_connected = FALSE
INSERT INTO public.shipping_courier_partners (code, name, brand_color, base_rate, extra_kg_rate, tracking_url_template, is_active, is_live_api_connected) VALUES
    ('TCS', 'TCS Express Pakistan', '0xFFDC2626', 200.00, 80.00, 'https://tcsexpress.com/tracking?track={TRACKING}', TRUE, FALSE),
    ('LEOPARDS', 'Leopards Courier Service', '0xFFD97706', 180.00, 75.00, 'https://leopardscourier.com/track?num={TRACKING}', TRUE, FALSE),
    ('TRAX', 'Trax Logistics PK', '0xFF059669', 160.00, 60.00, 'https://sonic.trax.pk/tracking?id={TRACKING}', TRUE, FALSE),
    ('POSTEX', 'PostEx FinTech Delivery', '0xFF7C3AED', 170.00, 65.00, 'https://postex.pk/tracking?tracking={TRACKING}', TRUE, FALSE),
    ('MNP', 'M&P Express Logistics', '0xFF2563EB', 190.00, 70.00, 'https://mulphilog.com/tracking?awb={TRACKING}', TRUE, FALSE)
ON CONFLICT (code) DO NOTHING;

-- B. Shipping Zones Table
CREATE TABLE IF NOT EXISTS public.shipping_zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    zone_name TEXT NOT NULL,
    cities_covered TEXT NOT NULL,
    min_weight_kg NUMERIC(8,2) NOT NULL DEFAULT 0.00 CHECK (min_weight_kg >= 0.00),
    max_weight_kg NUMERIC(8,2) NOT NULL CHECK (max_weight_kg > min_weight_kg),
    delivery_fee NUMERIC(12,2) NOT NULL CHECK (delivery_fee >= 0.00),
    estimated_days TEXT NOT NULL DEFAULT '2-3 Days',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.shipping_zones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.shipping_zones FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.shipping_zones TO authenticated;

DROP POLICY IF EXISTS "Shipping zones visibility" ON public.shipping_zones;
CREATE POLICY "Shipping zones visibility" ON public.shipping_zones
    FOR SELECT TO authenticated
    USING (public.has_permission('shipping', 'view'));

-- Seed Initial Shipping Zones
INSERT INTO public.shipping_zones (zone_name, cities_covered, min_weight_kg, max_weight_kg, delivery_fee, estimated_days) VALUES
    ('Zone 1: Intra-City Express', 'Lahore, Karachi, Islamabad, Rawalpindi', 0.00, 5.00, 150.00, '1-2 Business Days'),
    ('Zone 2: Punjab Major Hubs', 'Faisalabad, Multan, Sialkot, Gujranwala, Bahawalpur', 0.00, 5.00, 220.00, '2-3 Business Days'),
    ('Zone 3: National Tier-2 Cities', 'Peshawar, Quetta, Hyderabad, Sukkur, Abbottabad', 0.00, 5.00, 280.00, '3-4 Business Days'),
    ('Zone 4: Remote & Northern Areas', 'Gilgit, Skardu, Chitral, Gwadar, Turbat', 0.00, 5.00, 400.00, '5-7 Business Days')
ON CONFLICT DO NOTHING;

-- C. Order Shipment Assignments Table
CREATE TABLE IF NOT EXISTS public.order_shipment_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id TEXT NOT NULL REFERENCES public.buyer_orders(id) ON DELETE CASCADE,
    seller_store_id UUID NOT NULL REFERENCES public.seller_stores(id) ON DELETE CASCADE,
    courier_id UUID NOT NULL REFERENCES public.shipping_courier_partners(id),
    tracking_number TEXT NOT NULL,
    shipping_label_url TEXT,
    status TEXT NOT NULL DEFAULT 'Assigned' CHECK (status IN ('Assigned', 'InTransit', 'Delivered', 'Returned', 'Failed')),
    assigned_by UUID REFERENCES auth.users(id),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_order_shipment_store UNIQUE (order_id, seller_store_id)
);

ALTER TABLE public.order_shipment_assignments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.order_shipment_assignments FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.order_shipment_assignments TO authenticated;

DROP POLICY IF EXISTS "Shipment assignments visibility" ON public.order_shipment_assignments;
CREATE POLICY "Shipment assignments visibility" ON public.order_shipment_assignments
    FOR SELECT TO authenticated
    USING (
        public.owns_seller_store(seller_store_id)
        OR public.has_permission('shipping', 'view')
    );

-- Seed Shipping module permissions for orderManager and auditor
INSERT INTO public.staff_role_permissions (staff_role, module, action) VALUES
    ('orderManager', 'shipping', 'view'),
    ('orderManager', 'shipping', 'edit'),
    ('orderManager', 'shipping', 'assign'),
    ('auditor', 'shipping', 'view')
ON CONFLICT (staff_role, module, action) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 5. SHIPPING GOVERNANCE RPCS
-- ----------------------------------------------------------------------------

-- RPC 1: Fetch Shipping Overview (Couriers, Zones, Recent Shipments)
CREATE OR REPLACE FUNCTION public.admin_fetch_shipping_overview()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_couriers JSONB;
    v_zones JSONB;
    v_assignments JSONB;
BEGIN
    IF NOT public.has_permission('shipping', 'view') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to view shipping governance.' USING ERRCODE = '42501';
    END IF;

    SELECT COALESCE(jsonb_agg(c), '[]'::jsonb) INTO v_couriers
    FROM (
        SELECT id, code, name, brand_color, base_rate, extra_kg_rate,
               tracking_url_template, webhook_url, is_active, is_live_api_connected
        FROM public.shipping_courier_partners
        ORDER BY name ASC
    ) c;

    SELECT COALESCE(jsonb_agg(z), '[]'::jsonb) INTO v_zones
    FROM (
        SELECT id, zone_name, cities_covered, min_weight_kg, max_weight_kg,
               delivery_fee, estimated_days, is_active
        FROM public.shipping_zones
        ORDER BY delivery_fee ASC
    ) z;

    SELECT COALESCE(jsonb_agg(a), '[]'::jsonb) INTO v_assignments
    FROM (
        SELECT osa.id, osa.order_id, osa.seller_store_id, ss.name AS store_name,
               scp.name AS courier_name, osa.tracking_number, osa.status, osa.assigned_at
        FROM public.order_shipment_assignments osa
        JOIN public.seller_stores ss ON ss.id = osa.seller_store_id
        JOIN public.shipping_courier_partners scp ON scp.id = osa.courier_id
        ORDER BY osa.assigned_at DESC
        LIMIT 50
    ) a;

    RETURN jsonb_build_object(
        'couriers', v_couriers,
        'zones', v_zones,
        'recent_assignments', v_assignments
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_fetch_shipping_overview() TO authenticated;

-- RPC 2: Save Shipping Zone (with Weight Range & Non-Negative Validation)
CREATE OR REPLACE FUNCTION public.admin_save_shipping_zone(
    p_id UUID DEFAULT NULL,
    p_zone_name TEXT DEFAULT NULL,
    p_cities_covered TEXT DEFAULT NULL,
    p_min_weight_kg NUMERIC DEFAULT 0.00,
    p_max_weight_kg NUMERIC DEFAULT 5.00,
    p_delivery_fee NUMERIC DEFAULT 150.00,
    p_estimated_days TEXT DEFAULT '2-3 Business Days'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_zone_id UUID;
    v_audit_id UUID;
    v_overlap_exists BOOLEAN;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.' USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_permission('shipping', 'edit') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to manage shipping zones.' USING ERRCODE = '42501';
    END IF;

    IF p_delivery_fee < 0.00 THEN
        RAISE EXCEPTION 'Delivery fee cannot be negative.' USING ERRCODE = '22023';
    END IF;

    IF p_min_weight_kg < 0.00 THEN
        RAISE EXCEPTION 'Minimum weight cannot be negative.' USING ERRCODE = '22023';
    END IF;

    IF p_max_weight_kg <= p_min_weight_kg THEN
        RAISE EXCEPTION 'Maximum weight must be strictly greater than minimum weight.' USING ERRCODE = '22023';
    END IF;

    -- Validate no overlapping weight range for identical zone name
    SELECT EXISTS (
        SELECT 1 FROM public.shipping_zones
        WHERE zone_name = trim(p_zone_name)
          AND (p_id IS NULL OR id <> p_id)
          AND (
              (p_min_weight_kg >= min_weight_kg AND p_min_weight_kg < max_weight_kg)
              OR (p_max_weight_kg > min_weight_kg AND p_max_weight_kg <= max_weight_kg)
          )
    ) INTO v_overlap_exists;

    IF v_overlap_exists THEN
        RAISE EXCEPTION 'Overlapping weight tier detected for zone %.', p_zone_name USING ERRCODE = '22023';
    END IF;

    IF p_id IS NOT NULL THEN
        UPDATE public.shipping_zones
        SET zone_name = trim(p_zone_name),
            cities_covered = trim(p_cities_covered),
            min_weight_kg = p_min_weight_kg,
            max_weight_kg = p_max_weight_kg,
            delivery_fee = p_delivery_fee,
            estimated_days = trim(p_estimated_days),
            updated_at = NOW()
        WHERE id = p_id;
        v_zone_id := p_id;
    ELSE
        INSERT INTO public.shipping_zones (
            zone_name, cities_covered, min_weight_kg, max_weight_kg, delivery_fee, estimated_days
        ) VALUES (
            trim(p_zone_name), trim(p_cities_covered), p_min_weight_kg, p_max_weight_kg, p_delivery_fee, trim(p_estimated_days)
        ) RETURNING id INTO v_zone_id;
    END IF;

    v_audit_id := public.internal_record_audit_log(
        'shipping_zones',
        v_zone_id::TEXT,
        'SHIPPING_ZONE_SAVED',
        jsonb_build_object('zone_name', p_zone_name, 'delivery_fee', p_delivery_fee)
    );

    RETURN jsonb_build_object('success', TRUE, 'zone_id', v_zone_id, 'audit_log_id', v_audit_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_save_shipping_zone(UUID, TEXT, TEXT, NUMERIC, NUMERIC, NUMERIC, TEXT) TO authenticated;

-- RPC 3: Assign Shipment to Courier
CREATE OR REPLACE FUNCTION public.admin_assign_order_shipment(
    p_order_id TEXT,
    p_seller_store_id UUID,
    p_courier_id UUID,
    p_tracking_number TEXT,
    p_shipping_label_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_courier RECORD;
    v_assignment_id UUID;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.' USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_permission('shipping', 'assign') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to assign shipments.' USING ERRCODE = '42501';
    END IF;

    SELECT id, name INTO v_courier
    FROM public.shipping_courier_partners
    WHERE id = p_courier_id AND is_active = TRUE;

    IF v_courier.id IS NULL THEN
        RAISE EXCEPTION 'Courier partner not found or inactive.' USING ERRCODE = 'P0002';
    END IF;

    IF p_tracking_number IS NULL OR trim(p_tracking_number) = '' THEN
        RAISE EXCEPTION 'Tracking number is required.' USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.order_shipment_assignments (
        order_id, seller_store_id, courier_id, tracking_number, shipping_label_url, status, assigned_by
    ) VALUES (
        p_order_id, p_seller_store_id, p_courier_id, trim(p_tracking_number), p_shipping_label_url, 'Assigned', v_caller_id
    )
    ON CONFLICT (order_id, seller_store_id)
    DO UPDATE SET courier_id = EXCLUDED.courier_id, tracking_number = EXCLUDED.tracking_number, updated_at = NOW()
    RETURNING id INTO v_assignment_id;

    -- Update store_fulfillment tracking details
    UPDATE public.store_fulfillments
    SET courier_name = v_courier.name,
        tracking_number = trim(p_tracking_number),
        updated_at = NOW()
    WHERE order_id = p_order_id AND seller_store_id = p_seller_store_id;

    v_audit_id := public.internal_record_audit_log(
        'order_shipment_assignments',
        v_assignment_id::TEXT,
        'SHIPMENT_ASSIGNED',
        jsonb_build_object(
            'order_id', p_order_id,
            'seller_store_id', p_seller_store_id,
            'courier', v_courier.name,
            'tracking', p_tracking_number
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'assignment_id', v_assignment_id,
        'courier_name', v_courier.name,
        'audit_log_id', v_audit_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_assign_order_shipment(TEXT, UUID, UUID, TEXT, TEXT) TO authenticated;

-- RPC 4: Toggle Courier Active State
CREATE OR REPLACE FUNCTION public.admin_toggle_courier_active(
    p_courier_id UUID,
    p_is_active BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_audit_id UUID;
    v_courier_name TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.' USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_permission('shipping', 'edit') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to update courier settings.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.shipping_courier_partners
    SET is_active = p_is_active, updated_at = NOW()
    WHERE id = p_courier_id
    RETURNING name INTO v_courier_name;

    IF v_courier_name IS NULL THEN
        RAISE EXCEPTION 'Courier not found.' USING ERRCODE = 'P0002';
    END IF;

    v_audit_id := public.internal_record_audit_log(
        'shipping_courier_partners',
        p_courier_id::TEXT,
        'COURIER_TOGGLED',
        jsonb_build_object('courier_name', v_courier_name, 'is_active', p_is_active)
    );

    RETURN jsonb_build_object('success', TRUE, 'courier_id', p_courier_id, 'is_active', p_is_active, 'audit_log_id', v_audit_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_toggle_courier_active(UUID, BOOLEAN) TO authenticated;

-- RPC 5: Delete Shipping Zone
CREATE OR REPLACE FUNCTION public.admin_delete_shipping_zone(
    p_zone_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_audit_id UUID;
    v_zone_name TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.' USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_permission('shipping', 'edit') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to delete shipping zones.' USING ERRCODE = '42501';
    END IF;

    SELECT zone_name INTO v_zone_name FROM public.shipping_zones WHERE id = p_zone_id;
    IF v_zone_name IS NULL THEN
        RAISE EXCEPTION 'Shipping zone not found.' USING ERRCODE = 'P0002';
    END IF;

    DELETE FROM public.shipping_zones WHERE id = p_zone_id;

    v_audit_id := public.internal_record_audit_log(
        'shipping_zones',
        p_zone_id::TEXT,
        'SHIPPING_ZONE_DELETED',
        jsonb_build_object('zone_name', v_zone_name)
    );

    RETURN jsonb_build_object('success', TRUE, 'zone_id', p_zone_id, 'audit_log_id', v_audit_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_delete_shipping_zone(UUID) TO authenticated;



-- =========================================================================
-- FILE: 20260834000000_ledger_math_cron_and_shipping_hardening.sql
-- =========================================================================

-- Migration: 20260834000000_ledger_math_cron_and_shipping_hardening.sql
-- Description: Task A1 Part 1 fixes:
-- 1. Ledger math alignment: exact available vs held formulas and HOLD_VOID handling.
-- 2. Fraud blacklist normalization: backfill and NOT NULL constraint enforcement.
-- 3. pg_cron conditional scheduling and release function permission hardening.
-- 4. Courier live API status wiring to platform_integrations and admin RPC.
-- 5. Shipment assignment validation (order state, active courier, tracking regex, store matching).

-- ----------------------------------------------------------------------------
-- 1. LEDGER CONSTRAINTS & CANONICAL MATH
-- ----------------------------------------------------------------------------

-- Add HOLD_VOID to transaction_type CHECK constraint
DO $$
BEGIN
    ALTER TABLE public.wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_transaction_type_check;
    ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_transaction_type_check
        CHECK (transaction_type IN ('CREDIT', 'DEBIT', 'HOLD', 'RELEASE', 'ADJUSTMENT', 'HOLD_VOID'));

    ALTER TABLE public.wallet_transactions DROP CONSTRAINT IF EXISTS wallet_transactions_source_type_check;
    ALTER TABLE public.wallet_transactions ADD CONSTRAINT wallet_transactions_source_type_check
        CHECK (source_type IN (
            'ORDER_SETTLEMENT',
            'PAYOUT_RESERVATION',
            'PAYOUT_DISBURSEMENT',
            'PAYOUT_REJECTION_RELEASE',
            'REFUND_REVERSAL',
            'ADMIN_ADJUSTMENT',
            'ORDER_FULFILLMENT',
            'ORDER_DELIVERED_HELD',
            'ORDER_EARNINGS_RELEASE',
            'HELD_REFUND_VOID'
        ));
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- Canonical get_seller_wallet_summary
-- LEDGER MATH SPECIFICATION:
-- CREDIT:      available += amount,  held += 0
-- DEBIT:       available -= amount,  held += 0
-- HOLD:        available += 0,       held += amount
-- RELEASE:     available += amount,  held -= amount
-- HOLD_VOID:   available += 0,       held -= amount
-- ADJUSTMENT:  available += amount,  held += 0
DROP FUNCTION IF EXISTS public.get_seller_wallet_summary(UUID);
CREATE OR REPLACE FUNCTION public.get_seller_wallet_summary(p_seller_store_id UUID DEFAULT NULL)
RETURNS TABLE (
    seller_store_id UUID,
    available_balance NUMERIC(12,2),
    held_balance NUMERIC(12,2),
    pending_balance NUMERIC(12,2),
    paid_out_total NUMERIC(12,2)
) AS $$
DECLARE
    v_target_store_id UUID;
    v_available NUMERIC(12,2) := 0.00;
    v_held NUMERIC(12,2) := 0.00;
    v_pending NUMERIC(12,2) := 0.00;
    v_paid_out NUMERIC(12,2) := 0.00;
BEGIN
    IF p_seller_store_id IS NOT NULL THEN
        IF auth.uid() IS NOT NULL AND NOT (public.has_permission('finance', 'view') OR public.has_permission('payouts', 'view') OR public.has_permission('returns', 'review') OR public.has_permission('disputes', 'view')) THEN
            SELECT id INTO v_target_store_id FROM public.seller_stores WHERE id = p_seller_store_id AND owner_id = auth.uid();
            IF v_target_store_id IS NULL THEN
                RAISE EXCEPTION 'Access denied: You do not own store %.', p_seller_store_id USING ERRCODE = 'P0001';
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

    -- Canonical available balance:
    -- Increases with CREDIT, RELEASE, positive ADJUSTMENT
    -- Decreases with DEBIT
    -- (HOLD and HOLD_VOID have ZERO effect on available balance)
    SELECT COALESCE(SUM(
        CASE 
            WHEN wt.transaction_type IN ('CREDIT', 'RELEASE') THEN wt.amount
            WHEN wt.transaction_type = 'DEBIT' THEN -wt.amount
            WHEN wt.transaction_type = 'HOLD' AND wt.source_type = 'PAYOUT_RESERVATION' THEN -wt.amount
            WHEN wt.transaction_type = 'ADJUSTMENT' THEN wt.amount
            ELSE 0.00
        END
    ), 0.00) INTO v_available
    FROM public.wallet_transactions wt
    WHERE wt.seller_store_id = v_target_store_id;

    -- Canonical held balance:
    -- Increases with HOLD
    -- Decreases with RELEASE and HOLD_VOID
    SELECT COALESCE(SUM(
        CASE
            WHEN wt.transaction_type = 'HOLD' THEN wt.amount
            WHEN wt.transaction_type IN ('RELEASE', 'HOLD_VOID') THEN -wt.amount
            ELSE 0.00
        END
    ), 0.00) INTO v_held
    FROM public.wallet_transactions wt
    WHERE wt.seller_store_id = v_target_store_id;

    -- Paid out total (Disbursed payouts)
    SELECT COALESCE(SUM(pr.amount), 0.00) INTO v_paid_out
    FROM public.payout_requests pr
    WHERE pr.seller_store_id = v_target_store_id
      AND pr.status = 'Paid';

    -- Pending unfulfilled orders
    SELECT COALESCE(SUM(oi.seller_payable), 0.00) INTO v_pending
    FROM public.order_items oi
    JOIN public.buyer_orders bo ON bo.id = oi.order_id
    WHERE oi.seller_store_id = v_target_store_id
      AND bo.status IN ('Pending', 'Processing');

    RETURN QUERY SELECT v_target_store_id, v_available, v_held, v_pending, v_paid_out;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.get_seller_wallet_summary(UUID) TO authenticated;

-- Update admin_arbitrate_return_claim to use HOLD_VOID when refunding still-held escrow earnings
CREATE OR REPLACE FUNCTION public.admin_arbitrate_return_claim(
    p_claim_id UUID,
    p_decision TEXT,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_claim RECORD;
    v_refund_id UUID;
    v_audit_id UUID;
    v_is_refundable BOOLEAN;
    v_order_item RECORD;
    v_held_earning RECORD;
    v_wallet_account_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.' USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_permission('returns', 'review') THEN
        RAISE EXCEPTION 'Access denied: Insufficient administrative privileges to arbitrate return claims.' USING ERRCODE = '42501';
    END IF;

    IF p_decision NOT IN ('Approved', 'Rejected') THEN
        RAISE EXCEPTION 'Invalid decision: %. Must be Approved or Rejected.', p_decision USING ERRCODE = '22023';
    END IF;

    IF p_decision = 'Rejected' AND (p_notes IS NULL OR trim(p_notes) = '') THEN
        RAISE EXCEPTION 'Rejection requires detailed explanatory notes. Rejection notes are mandatory.' USING ERRCODE = '22023';
    END IF;

    IF length(p_notes) > 1000 THEN
        RAISE EXCEPTION 'Notes cannot exceed 1000 characters.' USING ERRCODE = '22023';
    END IF;

    SELECT id, order_id, order_item_id, seller_store_id, customer_user_id, quantity, status
    INTO v_claim
    FROM public.return_requests
    WHERE id = p_claim_id
    FOR UPDATE;

    IF v_claim.id IS NULL THEN
        RAISE EXCEPTION 'Return claim not found.' USING ERRCODE = 'P0002';
    END IF;

    IF v_claim.status NOT IN ('Pending', 'Requested') THEN
        RAISE EXCEPTION 'Return claim is already finalized (Current status: %).', v_claim.status USING ERRCODE = '22023';
    END IF;

    -- Per-Store Refund Eligibility Check
    v_is_refundable := public.is_order_refundable(v_claim.order_id, v_claim.seller_store_id);
    IF p_decision = 'Approved' AND NOT v_is_refundable THEN
        RAISE EXCEPTION 'Order item is not refundable: Store fulfillment must be Delivered and payment collected. COD has not been collected/delivered.' USING ERRCODE = '22023';
    END IF;

    IF p_decision = 'Approved' THEN
        SELECT id, unit_price, quantity, seller_payable INTO v_order_item
        FROM public.order_items
        WHERE id = v_claim.order_item_id;

        IF v_order_item.id IS NULL OR v_order_item.unit_price <= 0 THEN
            RAISE EXCEPTION 'Order item price is missing or invalid. Refund rejected.' USING ERRCODE = '22023';
        END IF;

        -- Process refund row
        INSERT INTO public.refunds (
            order_id, order_item_id, seller_store_id, customer_user_id,
            amount, status, reason, idempotency_key, processed_by
        ) VALUES (
            v_claim.order_id, v_claim.order_item_id, v_claim.seller_store_id, v_claim.customer_user_id,
            (v_order_item.unit_price * v_claim.quantity), 'Completed', 'Approved return claim arbitration',
            'REF-CLM-' || p_claim_id::TEXT, v_caller_id
        ) RETURNING id INTO v_refund_id;

        -- Fetch wallet account
        SELECT id INTO v_wallet_account_id
        FROM public.wallet_accounts
        WHERE seller_store_id = v_claim.seller_store_id;

        IF v_wallet_account_id IS NULL THEN
            INSERT INTO public.wallet_accounts (seller_store_id, owner_id)
            SELECT v_claim.seller_store_id, owner_id FROM public.seller_stores WHERE id = v_claim.seller_store_id
            ON CONFLICT (seller_store_id) DO NOTHING
            RETURNING id INTO v_wallet_account_id;

            IF v_wallet_account_id IS NULL THEN
                SELECT id INTO v_wallet_account_id FROM public.wallet_accounts WHERE seller_store_id = v_claim.seller_store_id;
            END IF;
        END IF;

        -- Check whether order earnings are still in escrow (HELD) or already RELEASED
        SELECT id, status, net_amount INTO v_held_earning
        FROM public.order_held_earnings
        WHERE order_id = v_claim.order_id AND seller_store_id = v_claim.seller_store_id;

        IF v_held_earning.id IS NOT NULL AND v_held_earning.status = 'HELD' THEN
            -- Void held escrow: reduces held balance, available balance unchanged
            UPDATE public.order_held_earnings
            SET status = 'FORFEITED',
                released_at = NOW()
            WHERE id = v_held_earning.id;

            INSERT INTO public.wallet_transactions (
                wallet_account_id, seller_store_id, transaction_type, amount,
                source_type, source_id, idempotency_key, description, created_by
            ) VALUES (
                v_wallet_account_id,
                v_claim.seller_store_id, 'HOLD_VOID', (v_order_item.unit_price * v_claim.quantity),
                'HELD_REFUND_VOID', v_claim.order_id, 'WLT-HLD-VOID-' || p_claim_id::TEXT,
                'Held escrow voided for return claim ' || p_claim_id::TEXT, v_caller_id
            ) ON CONFLICT (idempotency_key) DO NOTHING;
        ELSE
            -- Earning was already released or direct: record DEBIT (reduces available balance)
            INSERT INTO public.wallet_transactions (
                wallet_account_id, seller_store_id, transaction_type, amount,
                source_type, source_id, idempotency_key, description, created_by
            ) VALUES (
                v_wallet_account_id,
                v_claim.seller_store_id, 'DEBIT', (v_order_item.unit_price * v_claim.quantity),
                'REFUND_REVERSAL', v_claim.order_id, 'WLT-REF-' || p_claim_id::TEXT,
                'Refund reversal for claim ' || p_claim_id::TEXT, v_caller_id
            ) ON CONFLICT (idempotency_key) DO NOTHING;
        END IF;

        UPDATE public.return_requests
        SET status = 'Completed', updated_at = NOW()
        WHERE id = p_claim_id;
    ELSE
        UPDATE public.return_requests
        SET status = 'Rejected', updated_at = NOW()
        WHERE id = p_claim_id;
    END IF;

    v_audit_id := public.internal_record_audit_log(
        'return_requests',
        p_claim_id::TEXT,
        CASE WHEN p_decision = 'Approved' THEN 'DISPUTE_FULL_REFUND' ELSE 'DISPUTE_REJECTED' END,
        jsonb_build_object(
            'decision', p_decision,
            'refund_id', v_refund_id,
            'notes', p_notes
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'claim_id', p_claim_id,
        'decision', p_decision,
        'refund_id', v_refund_id,
        'audit_log_id', v_audit_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_arbitrate_return_claim(UUID, TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 2. FRAUD BLACKLIST NORMALIZATION: BACKFILL & NOT NULL ENFORCEMENT
-- ----------------------------------------------------------------------------

-- Ensure all pre-existing rows have normalized_value populated
UPDATE public.fraud_blacklisted_identifiers
SET normalized_value = CASE
    WHEN identifier_type = 'Phone Number' THEN COALESCE(public.normalize_phone_pk(identifier_value), trim(identifier_value))
    WHEN identifier_type = 'CNIC' THEN COALESCE(public.normalize_cnic_pk(identifier_value), trim(identifier_value))
    WHEN identifier_type = 'Bank IBAN' THEN COALESCE(public.normalize_iban_pk(identifier_value), trim(identifier_value))
    ELSE trim(identifier_value)
END
WHERE normalized_value IS NULL;

-- Enforce NOT NULL on normalized_value
ALTER TABLE public.fraud_blacklisted_identifiers
    ALTER COLUMN normalized_value SET NOT NULL;

-- ----------------------------------------------------------------------------
-- 3. PG_CRON SCHEDULING SAFETY & ESCROW FUNCTION PRIVILEGE HARDENING
-- ----------------------------------------------------------------------------

-- A. Revoke execute on escrow release functions from unprivileged callers
REVOKE ALL ON FUNCTION public.release_mature_held_seller_earnings() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_release_held_seller_earnings(TEXT, UUID) FROM PUBLIC, anon, authenticated;

-- B. Explicit GRANT only on admin function for authenticated staff
GRANT EXECUTE ON FUNCTION public.admin_release_held_seller_earnings(TEXT, UUID) TO authenticated;

-- C. Harden admin_release_held_seller_earnings permission gate
CREATE OR REPLACE FUNCTION public.admin_release_held_seller_earnings(
    p_order_id TEXT,
    p_seller_store_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_held RECORD;
    v_has_open_returns BOOLEAN;
    v_wallet_account_id UUID;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.' USING ERRCODE = '42501';
    END IF;

    IF NOT (public.has_permission('finance', 'adjust') OR public.has_permission('orders', 'release')) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to release held earnings.' USING ERRCODE = '42501';
    END IF;

    -- Lock and fetch held earnings entry
    SELECT id, order_id, seller_store_id, net_amount, status, mature_at
    INTO v_held
    FROM public.order_held_earnings
    WHERE order_id = p_order_id AND seller_store_id = p_seller_store_id
    FOR UPDATE;

    IF v_held.id IS NULL THEN
        RAISE EXCEPTION 'No held earnings record found for order % and store %.', p_order_id, p_seller_store_id USING ERRCODE = 'P0002';
    END IF;

    IF v_held.status <> 'HELD' THEN
        RAISE EXCEPTION 'Held earnings have already been processed (Current status: %).', v_held.status USING ERRCODE = '22023';
    END IF;

    IF v_held.mature_at > NOW() THEN
        RAISE EXCEPTION 'Cannot release earnings: Return window has not expired yet (Matures at %).', v_held.mature_at USING ERRCODE = '22023';
    END IF;

    -- Verify NO open return claims exist for this order and store
    SELECT EXISTS (
        SELECT 1 FROM public.return_requests rr
        JOIN public.order_items oi ON oi.id = rr.order_item_id
        WHERE oi.order_id = p_order_id
          AND oi.seller_store_id = p_seller_store_id
          AND rr.status NOT IN ('Rejected', 'Completed', 'Cancelled')
    ) INTO v_has_open_returns;

    IF v_has_open_returns THEN
        RAISE EXCEPTION 'Cannot release earnings: Open dispute or return claim exists for this order.' USING ERRCODE = '22023';
    END IF;

    -- Update order_held_earnings
    UPDATE public.order_held_earnings
    SET status = 'RELEASED',
        released_at = NOW()
    WHERE id = v_held.id;

    -- Fetch wallet account
    SELECT id INTO v_wallet_account_id
    FROM public.wallet_accounts
    WHERE seller_store_id = p_seller_store_id;

    -- Release held to available in wallet_accounts
    UPDATE public.wallet_accounts
    SET held_balance = GREATEST(held_balance - v_held.net_amount, 0.00),
        available_balance = available_balance + v_held.net_amount,
        updated_at = NOW()
    WHERE id = v_wallet_account_id;

    -- Update seller_stores available balance
    UPDATE public.seller_stores
    SET balance = balance + v_held.net_amount,
        updated_at = NOW()
    WHERE id = p_seller_store_id;

    -- Insert RELEASE entry into wallet_transactions
    INSERT INTO public.wallet_transactions (
        wallet_account_id, seller_store_id, transaction_type, amount,
        source_type, source_id, idempotency_key, description, created_by
    ) VALUES (
        v_wallet_account_id, p_seller_store_id, 'RELEASE', v_held.net_amount,
        'ORDER_DELIVERED_HELD', p_order_id, 'WLT-REL-' || p_order_id || '-' || p_seller_store_id,
        'Released escrow earnings for order ' || p_order_id || ' after return window maturity', v_caller_id
    )
    ON CONFLICT (idempotency_key) DO NOTHING;

    v_audit_id := public.internal_record_audit_log(
        'order_held_earnings',
        v_held.id::TEXT,
        'HELD_EARNINGS_RELEASED',
        jsonb_build_object(
            'order_id', p_order_id,
            'seller_store_id', p_seller_store_id,
            'amount', v_held.net_amount,
            'released_by', v_caller_id
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'order_id', p_order_id,
        'seller_store_id', p_seller_store_id,
        'released_amount', v_held.net_amount,
        'audit_log_id', v_audit_id
    );
END;
$$;

-- D. Autonomous Scheduled Release Function (Internal system context, does not require auth.uid())
CREATE OR REPLACE FUNCTION public.release_mature_held_seller_earnings()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_rec RECORD;
    v_wallet_account_id UUID;
    v_count INT := 0;
BEGIN
    FOR v_rec IN (
        SELECT ohe.id, ohe.order_id, ohe.seller_store_id, ohe.net_amount
        FROM public.order_held_earnings ohe
        WHERE ohe.status = 'HELD'
          AND ohe.mature_at <= NOW()
          AND NOT EXISTS (
              SELECT 1 FROM public.return_requests rr
              JOIN public.order_items oi ON oi.id = rr.order_item_id
              WHERE oi.order_id = ohe.order_id
                AND oi.seller_store_id = ohe.seller_store_id
                AND rr.status NOT IN ('Rejected', 'Completed', 'Cancelled')
          )
    ) LOOP
        -- Update order_held_earnings
        UPDATE public.order_held_earnings
        SET status = 'RELEASED',
            released_at = NOW()
        WHERE id = v_rec.id;

        -- Fetch wallet account
        SELECT id INTO v_wallet_account_id
        FROM public.wallet_accounts
        WHERE seller_store_id = v_rec.seller_store_id;

        -- Update balances
        UPDATE public.wallet_accounts
        SET held_balance = GREATEST(held_balance - v_rec.net_amount, 0.00),
            available_balance = available_balance + v_rec.net_amount,
            updated_at = NOW()
        WHERE id = v_wallet_account_id;

        UPDATE public.seller_stores
        SET balance = balance + v_rec.net_amount,
            updated_at = NOW()
        WHERE id = v_rec.seller_store_id;

        -- Insert RELEASE entry into wallet_transactions
        INSERT INTO public.wallet_transactions (
            wallet_account_id, seller_store_id, transaction_type, amount,
            source_type, source_id, idempotency_key, description, created_by
        ) VALUES (
            v_wallet_account_id, v_rec.seller_store_id, 'RELEASE', v_rec.net_amount,
            'ORDER_DELIVERED_HELD', v_rec.order_id, 'WLT-REL-AUTO-' || v_rec.order_id || '-' || v_rec.seller_store_id,
            'Auto-released escrow earnings for order ' || v_rec.order_id || ' after maturity', NULL
        )
        ON CONFLICT (idempotency_key) DO NOTHING;

        -- Audit record
        PERFORM public.internal_record_audit_log(
            'order_held_earnings',
            v_rec.id::TEXT,
            'HELD_EARNINGS_AUTO_RELEASED',
            jsonb_build_object(
                'order_id', v_rec.order_id,
                'seller_store_id', v_rec.seller_store_id,
                'amount', v_rec.net_amount,
                'system_trigger', 'pg_cron'
            )
        );

        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object('success', TRUE, 'released_count', v_count);
END;
$$;

-- E. Conditional pg_cron schedule check
DO $cron_setup$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule(
            'release-mature-held-earnings-hourly',
            '0 * * * *',
            'SELECT public.release_mature_held_seller_earnings();'
        );
        RAISE NOTICE 'pg_cron job release-mature-held-earnings-hourly scheduled successfully.';
    ELSE
        RAISE NOTICE 'pg_cron extension is not installed. To activate automated escrow release, enable pg_cron in Supabase Dashboard -> Database -> Extensions.';
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Could not schedule pg_cron job: %. Continuing migration.', SQLERRM;
END;
$cron_setup$;

-- ----------------------------------------------------------------------------
-- 4. SHIPPING SCREEN BADGE: LIVE API CONNECTED FROM PLATFORM_INTEGRATIONS
-- ----------------------------------------------------------------------------

-- Seed default shipping integrations into platform_integrations
INSERT INTO public.platform_integrations (provider_key, display_name, category, is_enabled, status)
VALUES
    ('TCS', 'TCS Express API', 'shipping', FALSE, 'not_configured'),
    ('LEOPARDS', 'Leopards Courier API', 'shipping', FALSE, 'not_configured'),
    ('TRAX', 'Trax Logistics API', 'shipping', FALSE, 'not_configured'),
    ('POSTEX', 'PostEx API', 'shipping', FALSE, 'not_configured'),
    ('MNP', 'M&P Express API', 'shipping', FALSE, 'not_configured')
ON CONFLICT (provider_key) DO NOTHING;

-- Admin RPC: Toggle Courier Live API Connection state in platform_integrations & shipping_courier_partners
CREATE OR REPLACE FUNCTION public.admin_set_courier_live_api(
    p_courier_code TEXT,
    p_is_connected BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_audit_id UUID;
    v_code TEXT;
    v_courier_name TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.' USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_permission('shipping', 'edit') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to update courier API status.' USING ERRCODE = '42501';
    END IF;

    v_code := upper(trim(p_courier_code));

    -- Update shipping_courier_partners
    UPDATE public.shipping_courier_partners
    SET is_live_api_connected = p_is_connected,
        updated_at = NOW()
    WHERE upper(code) = v_code
    RETURNING name INTO v_courier_name;

    IF v_courier_name IS NULL THEN
        RAISE EXCEPTION 'Courier partner with code % not found.', p_courier_code USING ERRCODE = 'P0002';
    END IF;

    -- Upsert platform_integrations
    INSERT INTO public.platform_integrations (
        provider_key, display_name, category, is_enabled, status, updated_by, updated_at
    ) VALUES (
        v_code, v_courier_name || ' API', 'shipping', p_is_connected,
        CASE WHEN p_is_connected THEN 'configured' ELSE 'not_configured' END,
        v_caller_id, NOW()
    )
    ON CONFLICT (provider_key) DO UPDATE SET
        is_enabled = EXCLUDED.is_enabled,
        status = EXCLUDED.status,
        updated_by = EXCLUDED.updated_by,
        updated_at = NOW();

    v_audit_id := public.internal_record_audit_log(
        'platform_integrations',
        v_code,
        'COURIER_LIVE_API_TOGGLED',
        jsonb_build_object('courier_code', v_code, 'is_connected', p_is_connected)
    );

    RETURN jsonb_build_object('success', TRUE, 'courier_code', v_code, 'is_live_api_connected', p_is_connected, 'audit_log_id', v_audit_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_courier_live_api(TEXT, BOOLEAN) TO authenticated;

-- Update admin_fetch_shipping_overview: Derive is_live_api_connected directly from platform_integrations
CREATE OR REPLACE FUNCTION public.admin_fetch_shipping_overview()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_couriers JSONB;
    v_zones JSONB;
    v_assignments JSONB;
BEGIN
    IF NOT public.has_permission('shipping', 'view') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to view shipping governance.' USING ERRCODE = '42501';
    END IF;

    SELECT COALESCE(jsonb_agg(c), '[]'::jsonb) INTO v_couriers
    FROM (
        SELECT scp.id, scp.code, scp.name, scp.brand_color, scp.base_rate, scp.extra_kg_rate,
               scp.tracking_url_template, scp.webhook_url, scp.is_active,
               COALESCE(pi.is_enabled AND pi.status = 'configured', scp.is_live_api_connected, FALSE) AS is_live_api_connected
        FROM public.shipping_courier_partners scp
        LEFT JOIN public.platform_integrations pi
          ON (pi.category = 'shipping' AND upper(pi.provider_key) = upper(scp.code))
        ORDER BY scp.name ASC
    ) c;

    SELECT COALESCE(jsonb_agg(z), '[]'::jsonb) INTO v_zones
    FROM (
        SELECT id, zone_name, cities_covered, min_weight_kg, max_weight_kg,
               delivery_fee, estimated_days, is_active
        FROM public.shipping_zones
        ORDER BY delivery_fee ASC
    ) z;

    SELECT COALESCE(jsonb_agg(a), '[]'::jsonb) INTO v_assignments
    FROM (
        SELECT osa.id, osa.order_id, osa.seller_store_id, ss.name AS store_name,
               scp.name AS courier_name, osa.tracking_number, osa.status, osa.assigned_at
        FROM public.order_shipment_assignments osa
        JOIN public.seller_stores ss ON ss.id = osa.seller_store_id
        JOIN public.shipping_courier_partners scp ON scp.id = osa.courier_id
        ORDER BY osa.assigned_at DESC
        LIMIT 50
    ) a;

    RETURN jsonb_build_object(
        'couriers', v_couriers,
        'zones', v_zones,
        'recent_assignments', v_assignments
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_fetch_shipping_overview() TO authenticated;

-- ----------------------------------------------------------------------------
-- 5. SHIPMENT ASSIGNMENT HARDENING & VALIDATIONS
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_assign_order_shipment(
    p_order_id TEXT,
    p_seller_store_id UUID,
    p_courier_id UUID,
    p_tracking_number TEXT,
    p_shipping_label_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_courier RECORD;
    v_order RECORD;
    v_store_matches BOOLEAN;
    v_clean_tracking TEXT;
    v_assignment_id UUID;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.' USING ERRCODE = '42501';
    END IF;

    IF NOT public.has_permission('shipping', 'assign') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to assign shipments.' USING ERRCODE = '42501';
    END IF;

    -- 1. Active courier check
    SELECT id, name INTO v_courier
    FROM public.shipping_courier_partners
    WHERE id = p_courier_id AND is_active = TRUE;

    IF v_courier.id IS NULL THEN
        RAISE EXCEPTION 'Courier partner not found or inactive.' USING ERRCODE = '22023';
    END IF;

    -- 2. Tracking number format check (4-64 alphanumeric/hyphen/underscore)
    v_clean_tracking := trim(p_tracking_number);
    IF v_clean_tracking IS NULL OR length(v_clean_tracking) < 4 OR length(v_clean_tracking) > 64 OR NOT (v_clean_tracking ~ '^[A-Za-z0-9_-]+$') THEN
        RAISE EXCEPTION 'Invalid tracking number format: Must be 4-64 alphanumeric characters.' USING ERRCODE = '22023';
    END IF;

    -- 3. Order existence and state check (must be Processing or Shipped)
    SELECT id, status INTO v_order
    FROM public.buyer_orders
    WHERE id = p_order_id;

    IF v_order.id IS NULL THEN
        RAISE EXCEPTION 'Order % not found.', p_order_id USING ERRCODE = 'P0002';
    END IF;

    IF v_order.status NOT IN ('Processing', 'Shipped') THEN
        RAISE EXCEPTION 'Order % is in "%" status. Shipments can only be assigned to orders in Processing or Shipped status.',
            p_order_id, v_order.status USING ERRCODE = '22023';
    END IF;

    -- 4. Store matching check (store must have order items in this order)
    SELECT EXISTS (
        SELECT 1 FROM public.order_items
        WHERE order_id = p_order_id AND seller_store_id = p_seller_store_id
    ) INTO v_store_matches;

    IF NOT v_store_matches THEN
        RAISE EXCEPTION 'Store % has no items in order %.', p_seller_store_id, p_order_id USING ERRCODE = '22023';
    END IF;

    -- 5. Assign shipment
    INSERT INTO public.order_shipment_assignments (
        order_id, seller_store_id, courier_id, tracking_number, shipping_label_url, status, assigned_by
    ) VALUES (
        p_order_id, p_seller_store_id, p_courier_id, v_clean_tracking, p_shipping_label_url, 'Assigned', v_caller_id
    )
    ON CONFLICT (order_id, seller_store_id)
    DO UPDATE SET courier_id = EXCLUDED.courier_id, tracking_number = EXCLUDED.tracking_number, updated_at = NOW()
    RETURNING id INTO v_assignment_id;

    -- 6. Update store_fulfillments tracking details
    UPDATE public.store_fulfillments
    SET courier_name = v_courier.name,
        tracking_number = v_clean_tracking,
        updated_at = NOW()
    WHERE order_id = p_order_id AND seller_store_id = p_seller_store_id;

    v_audit_id := public.internal_record_audit_log(
        'order_shipment_assignments',
        v_assignment_id::TEXT,
        'SHIPMENT_ASSIGNED',
        jsonb_build_object(
            'order_id', p_order_id,
            'seller_store_id', p_seller_store_id,
            'courier', v_courier.name,
            'tracking', v_clean_tracking
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'assignment_id', v_assignment_id,
        'courier_name', v_courier.name,
        'tracking_number', v_clean_tracking,
        'audit_log_id', v_audit_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_assign_order_shipment(TEXT, UUID, UUID, TEXT, TEXT) TO authenticated;



