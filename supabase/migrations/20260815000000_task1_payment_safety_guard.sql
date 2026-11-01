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
