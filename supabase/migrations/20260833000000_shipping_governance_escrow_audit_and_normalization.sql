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
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
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

        IF v_store_fulfillment_status IS NULL OR v_store_fulfillment_status <> 'Delivered' THEN
            RETURN FALSE;
        END IF;

        -- For COD, money must be collected (either order Paid or store Delivered with held balance created)
        IF v_payment_method IN ('Cash on Delivery', 'COD') THEN
            RETURN EXISTS (
                SELECT 1 FROM public.order_held_earnings
                WHERE order_id = p_order_id AND seller_store_id = p_seller_store_id
            ) OR v_payment_status = 'Paid';
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
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
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

    IF v_claim.status <> 'Pending' THEN
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
    v_unit_price NUMERIC(12,2);
    v_line_total NUMERIC(12,2);
    v_commission_rate NUMERIC(5,2);
    v_commission_amount NUMERIC(12,2);
    v_seller_earning NUMERIC(12,2);
    v_existing_order JSONB;
    v_buyer_phone TEXT;
    v_shipping_phone TEXT;
    v_norm_buyer_phone TEXT;
    v_norm_shipping_phone TEXT;
    v_is_blacklisted BOOLEAN;
BEGIN
    v_buyer_id := auth.uid();
    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to create order.' USING ERRCODE = '42501';
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
        RAISE EXCEPTION 'Online payments are not available yet. Please select Cash on Delivery.' USING ERRCODE = '22023';
    END IF;
    v_normalized_payment_method := 'Cash on Delivery';

    -- Check idempotency
    SELECT jsonb_build_object('order_id', id, 'order_number', order_number, 'status', status)
    INTO v_existing_order
    FROM public.buyer_orders
    WHERE idempotency_key = p_idempotency_key;

    IF v_existing_order IS NOT NULL THEN
        RETURN v_existing_order;
    END IF;

    v_order_number := 'ORD-' || UPPER(SUBSTRING(gen_random_uuid()::text, 1, 8));

    -- Validate items and compute totals
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id UUID, quantity INT)
    LOOP
        SELECT id, name, sku, regular_price, sale_price, stock_quantity, seller_store_id, is_active, approval_status
        INTO v_product
        FROM public.products
        WHERE id = v_item.product_id FOR UPDATE;

        IF v_product.id IS NULL OR NOT v_product.is_active OR v_product.approval_status != 'approved' THEN
            RAISE EXCEPTION 'Product % is unavailable or unapproved.', v_item.product_id USING ERRCODE = '22023';
        END IF;

        IF v_product.stock_quantity < v_item.quantity THEN
            RAISE EXCEPTION 'Insufficient stock for product %.', v_product.name USING ERRCODE = '22023';
        END IF;

        UPDATE public.products
        SET stock_quantity = stock_quantity - v_item.quantity,
            updated_at = NOW()
        WHERE id = v_product.id;

        v_unit_price := COALESCE(v_product.sale_price, v_product.regular_price);
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
        customer_user_id, order_number, status, payment_status, payment_method,
        total_amount, shipping_fee, voucher_discount, grand_total,
        shipping_address, customer_notes, idempotency_key
    ) VALUES (
        v_buyer_id, v_order_number, 'Pending', 'Pending', v_normalized_payment_method,
        v_total_amount, v_shipping_fee, v_voucher_discount, v_grand_total,
        p_shipping_address, p_notes, p_idempotency_key
    ) RETURNING id INTO v_order_id;

    -- Insert Order Items
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(product_id UUID, quantity INT)
    LOOP
        SELECT id, name, sku, regular_price, sale_price, seller_store_id INTO v_product
        FROM public.products WHERE id = v_item.product_id;

        v_unit_price := COALESCE(v_product.sale_price, v_product.regular_price);
        v_line_total := v_unit_price * v_item.quantity;
        v_commission_rate := 10.00;
        v_commission_amount := (v_line_total * v_commission_rate / 100.0);
        v_seller_earning := v_line_total - v_commission_amount;

        INSERT INTO public.order_items (
            order_id, product_id, seller_store_id, product_name, sku,
            unit_price, quantity, total_price, commission_rate,
            commission_amount, seller_payable
        ) VALUES (
            v_order_id::text, v_product.id, v_product.seller_store_id, v_product.name, v_product.sku,
            v_unit_price, v_item.quantity, v_line_total, v_commission_rate,
            v_commission_amount, v_seller_earning
        );
    END LOOP;

    RETURN jsonb_build_object(
        'order_id', v_order_id,
        'order_number', v_order_number,
        'status', 'Pending',
        'grand_total', v_grand_total
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. SINGLE SOURCE OF TRUTH: LEDGER-DERIVED SELLER BALANCES
-- ----------------------------------------------------------------------------
-- wallet_transactions is the canonical append-only ledger of record.
-- Revoke direct updates to seller_stores balance & pending_payout.
-- get_seller_wallet_summary derives balances strictly from ledger entries.

REVOKE UPDATE (balance, pending_payout) ON public.seller_stores FROM authenticated, anon, PUBLIC;

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
        IF NOT (public.has_permission('finance', 'view') OR public.has_permission('payouts', 'view')) THEN
            SELECT id INTO v_target_store_id FROM public.seller_stores WHERE id = p_seller_store_id AND owner_id = auth.uid();
            IF v_target_store_id IS NULL THEN
                RAISE EXCEPTION 'Access denied: You do not own store %.', p_seller_store_id USING ERRCODE = '42501';
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
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
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
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
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
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
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
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
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

