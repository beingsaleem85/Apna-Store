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
    owner_id UUID NOT NULL REFERENCES auth.users(id),
    currency TEXT NOT NULL DEFAULT 'PKR',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.wallet_accounts ENABLE ROW LEVEL SECURITY;

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
