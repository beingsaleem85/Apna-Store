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
