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
