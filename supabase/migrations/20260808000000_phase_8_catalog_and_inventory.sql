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
