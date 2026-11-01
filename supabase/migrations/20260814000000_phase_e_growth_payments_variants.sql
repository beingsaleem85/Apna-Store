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
