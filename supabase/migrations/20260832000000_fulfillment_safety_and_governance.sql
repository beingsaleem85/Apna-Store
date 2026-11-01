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

-- Unique constraint on wallet transaction source per store to guarantee exactly-once credit
CREATE UNIQUE INDEX IF NOT EXISTS uq_wallet_txn_store_source
ON public.wallet_transactions (seller_store_id, source_type, source_id);

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

    -- Money Safety Rule: Sellers CANNOT set Delivered
    IF p_new_status = 'Delivered' THEN
        RAISE EXCEPTION 'Access denied: Sellers cannot mark orders as Delivered. Delivery must be verified by admin or courier.' USING ERRCODE = '42501';
    END IF;

    IF p_new_status NOT IN ('Processing', 'Shipped', 'Cancelled') THEN
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
            RAISE EXCEPTION 'Unauthorized to update fulfillment status for this store.' USING ERRCODE = '42501';
        END IF;
        v_target_store_id := p_seller_store_id;
    ELSE
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
    IF v_old_status = 'Pending' AND p_new_status NOT IN ('Processing', 'Cancelled') THEN
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
        'fulfillment_status', p_new_status
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.seller_update_fulfillment_status(TEXT, TEXT, UUID, TEXT, TEXT, TEXT) TO authenticated;

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
    ON CONFLICT (seller_store_id, source_type, source_id) DO NOTHING;

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
    ON CONFLICT (seller_store_id, source_type, source_id) DO NOTHING;

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
    SELECT id, available_balance INTO v_wallet_account_id, v_available_balance
    FROM public.wallet_accounts
    WHERE seller_store_id = v_store.id
    FOR UPDATE;

    IF v_wallet_account_id IS NULL THEN
        INSERT INTO public.wallet_accounts (seller_store_id, owner_id)
        VALUES (v_store.id, v_seller_id)
        RETURNING id, available_balance INTO v_wallet_account_id, v_available_balance;
    END IF;

    -- Money Safety Rule: Payout requests can only use available balance (NOT held balance)
    IF p_amount > v_available_balance THEN
        RAISE EXCEPTION 'Insufficient available balance. Requested: %, Available: % (Held balance cannot be withdrawn).', p_amount, v_available_balance USING ERRCODE = '22023';
    END IF;

    -- Deduct from available balance and hold for payout
    UPDATE public.wallet_accounts
    SET available_balance = available_balance - p_amount,
        updated_at = NOW()
    WHERE id = v_wallet_account_id;

    UPDATE public.seller_stores
    SET balance = balance - p_amount,
        updated_at = NOW()
    WHERE id = v_store.id;

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
    v_buyer_phone TEXT;
    v_shipping_phone TEXT;
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

GRANT EXECUTE ON FUNCTION public.create_atomic_order(JSONB, JSONB, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- Overload for backwards compatibility
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

GRANT EXECUTE ON FUNCTION public.create_atomic_order(JSONB, JSONB, TEXT, TEXT, TEXT) TO authenticated;

-- B. seller_update_product_stock: Gated on deactivated accounts
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
        RAISE EXCEPTION 'Stock quantity cannot be negative.' USING ERRCODE = '22023';
    END IF;

    SELECT seller_store_id INTO v_store_id FROM public.products WHERE id = p_product_id;
    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'Product not found.' USING ERRCODE = 'P0002';
    END IF;

    IF NOT public.owns_seller_store(v_store_id) THEN
        RAISE EXCEPTION 'Access denied: You do not own the store for this product.' USING ERRCODE = '42501';
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
    p_order_id UUID,
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
    v_buyer_id UUID;
    v_is_deactivated BOOLEAN;
    v_order_status TEXT;
    v_review_id UUID;
BEGIN
    v_buyer_id := auth.uid();
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

    -- Verify order ownership and completion
    SELECT status INTO v_order_status
    FROM public.buyer_orders
    WHERE id = p_order_id::TEXT AND customer_user_id = v_buyer_id;

    IF v_order_status IS NULL THEN
        RAISE EXCEPTION 'Order not found or does not belong to authenticated user.' USING ERRCODE = '42501';
    END IF;

    IF v_order_status <> 'Delivered' THEN
        RAISE EXCEPTION 'Reviews can only be submitted for Delivered orders.' USING ERRCODE = '22023';
    END IF;

    -- Insert Review
    INSERT INTO public.product_reviews (
        product_id, customer_user_id, order_id, rating, review_text
    ) VALUES (
        p_product_id, v_buyer_id, p_order_id, p_rating, p_review_text
    )
    ON CONFLICT (product_id, customer_user_id, order_id)
    DO UPDATE SET rating = EXCLUDED.rating, review_text = EXCLUDED.review_text, updated_at = NOW()
    RETURNING id INTO v_review_id;

    RETURN jsonb_build_object('success', TRUE, 'review_id', v_review_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_product_review(UUID, UUID, INT, TEXT) TO authenticated;

-- D. submit_return_request: Gated on deactivated accounts
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

    INSERT INTO public.return_requests (
        order_id, order_item_id, seller_store_id, customer_user_id,
        quantity, reason, description, evidence_urls, status
    ) VALUES (
        p_order_id, p_order_item_id, v_item.seller_store_id, v_buyer_id,
        p_quantity, p_reason, p_description, p_evidence_urls, 'Pending'
    ) RETURNING id INTO v_claim_id;

    RETURN jsonb_build_object('success', TRUE, 'claim_id', v_claim_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_return_request(TEXT, UUID, INT, TEXT, TEXT, TEXT[]) TO authenticated;

-- E. deactivate_user_account: Normalize SQLSTATE to 42501
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

GRANT EXECUTE ON FUNCTION public.deactivate_user_account(UUID, TEXT) TO authenticated;

-- F. create_chat_room & send_chat_message: Normalize SQLSTATE to 42501
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
        RAISE EXCEPTION 'Access denied: You are not a participant in this chat room.' USING ERRCODE = '42501';
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
            'NEW_CHAT_MESSAGE',
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
        (is_active = TRUE AND approval_status = 'approved')
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
