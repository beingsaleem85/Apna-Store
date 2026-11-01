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
