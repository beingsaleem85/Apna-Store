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

-- 2. Create voucher_redemptions table
CREATE TABLE IF NOT EXISTS public.voucher_redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    voucher_id UUID NOT NULL REFERENCES public.vouchers(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    order_id UUID REFERENCES public.buyer_orders(id) ON DELETE SET NULL,
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
    v_order_id UUID;
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

-- Also provide 5-arg overload for backwards compatibility
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
BEGIN
    RETURN public.create_atomic_order(p_items, p_shipping_address, p_payment_method, p_idempotency_key, p_notes, NULL);
END;
$$;

REVOKE ALL ON FUNCTION public.create_atomic_order(JSONB, JSONB, TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_atomic_order(JSONB, JSONB, TEXT, TEXT, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_atomic_order(JSONB, JSONB, TEXT, TEXT, TEXT) TO authenticated;

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
