-- ============================================================================
-- MIGRATION: 20260813000000_phase_c_seller_admin_ops.sql
-- PURPOSE: Phase C Seller & Admin Operations:
--          1. Payout Requests Table with Strict RLS & Ledger Isolation
--          2. Brands Table with Category Governance RLS
--          3. Category Table Full RLS for Administrative CRUD
--          4. Seller Payout Request RPC (seller_request_payout)
--          5. Admin Process Payout RPC (admin_process_payout)
--          6. Admin Seller Suspension & Payout Lock Enforcement RPCs
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SELLER PAYOUT REQUESTS TABLE & AUDIT CONSTRAINTS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.seller_payout_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_store_id UUID NOT NULL REFERENCES public.seller_stores(id) ON DELETE CASCADE,
    requested_by UUID NOT NULL REFERENCES auth.users(id),
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    bank_name TEXT NOT NULL,
    account_number TEXT NOT NULL,
    account_title TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected', 'Processed')),
    rejection_reason TEXT,
    admin_notes TEXT,
    processed_at TIMESTAMPTZ,
    processed_by UUID REFERENCES auth.users(id),
    gateway_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.seller_payout_requests ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_payout_store_id ON public.seller_payout_requests(seller_store_id);
CREATE INDEX IF NOT EXISTS idx_payout_requested_by ON public.seller_payout_requests(requested_by);
CREATE INDEX IF NOT EXISTS idx_payout_status ON public.seller_payout_requests(status);

-- RLS Policies for Payout Requests
DROP POLICY IF EXISTS "Sellers can view own payout requests" ON public.seller_payout_requests;
CREATE POLICY "Sellers can view own payout requests" ON public.seller_payout_requests
    FOR SELECT
    TO authenticated
    USING (
        requested_by = auth.uid()
        OR seller_store_id IN (SELECT id FROM public.seller_stores WHERE owner_id = auth.uid())
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "Sellers can create payout requests for own store" ON public.seller_payout_requests;
CREATE POLICY "Sellers can create payout requests for own store" ON public.seller_payout_requests
    FOR INSERT
    TO authenticated
    WITH CHECK (
        requested_by = auth.uid()
        AND seller_store_id IN (SELECT id FROM public.seller_stores WHERE owner_id = auth.uid())
    );

DROP POLICY IF EXISTS "Admins can update payout requests" ON public.seller_payout_requests;
CREATE POLICY "Admins can update payout requests" ON public.seller_payout_requests
    FOR UPDATE
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

GRANT SELECT, INSERT ON public.seller_payout_requests TO authenticated;

-- ----------------------------------------------------------------------------
-- 2. BRANDS TABLE & RLS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.brands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    logo_url TEXT,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.brands ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view active brands" ON public.brands;
CREATE POLICY "Anyone can view active brands" ON public.brands
    FOR SELECT
    TO anon, authenticated
    USING (is_active = true OR public.is_admin());

DROP POLICY IF EXISTS "Admins can manage brands" ON public.brands;
CREATE POLICY "Admins can manage brands" ON public.brands
    FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

GRANT SELECT ON public.brands TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.brands TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. CATEGORIES TABLE RLS ENHANCEMENT FOR ADMIN CRUD
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Anyone can view active categories" ON public.categories;
CREATE POLICY "Anyone can view active categories" ON public.categories
    FOR SELECT
    TO anon, authenticated
    USING (is_active = true OR public.is_admin());

DROP POLICY IF EXISTS "Admins can manage categories" ON public.categories;
CREATE POLICY "Admins can manage categories" ON public.categories
    FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

GRANT SELECT ON public.categories TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.categories TO authenticated;

-- ----------------------------------------------------------------------------
-- 4. SELLER PAYOUT REQUEST RPC (seller_request_payout)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.seller_request_payout(NUMERIC, TEXT);
DROP FUNCTION IF EXISTS public.seller_request_payout(NUMERIC(12,2), TEXT);
DROP FUNCTION IF EXISTS public.seller_request_payout(UUID, NUMERIC, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.seller_request_payout(UUID, NUMERIC(12,2), TEXT, TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.seller_request_payout(
    p_store_id UUID,
    p_amount NUMERIC(12,2),
    p_bank_name TEXT,
    p_account_number TEXT,
    p_account_title TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_store RECORD;
    v_new_payout_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Unauthenticated request');
    END IF;

    IF p_amount IS NULL OR p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid payout amount');
    END IF;

    SELECT id, owner_id, is_approved, is_suspended, is_payout_locked, balance, pending_payout
    INTO v_store
    FROM public.seller_stores
    WHERE id = p_store_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Store not found');
    END IF;

    IF v_store.owner_id != auth.uid() AND NOT public.is_admin() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: You do not own this store');
    END IF;

    IF NOT v_store.is_approved THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot request payout: Store is not approved');
    END IF;

    IF COALESCE(v_store.is_suspended, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot request payout: Store account is suspended');
    END IF;

    IF COALESCE(v_store.is_payout_locked, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot request payout: Store payouts are currently locked');
    END IF;

    IF v_store.balance < p_amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient available balance');
    END IF;

    -- Update store balance atomically
    UPDATE public.seller_stores
    SET balance = balance - p_amount,
        pending_payout = COALESCE(pending_payout, 0.00) + p_amount,
        updated_at = NOW()
    WHERE id = p_store_id;

    -- Insert payout record
    INSERT INTO public.seller_payout_requests (
        seller_store_id,
        requested_by,
        amount,
        bank_name,
        account_number,
        account_title,
        status
    )
    VALUES (
        p_store_id,
        auth.uid(),
        p_amount,
        p_bank_name,
        p_account_number,
        p_account_title,
        'Pending'
    )
    RETURNING id INTO v_new_payout_id;

    RETURN jsonb_build_object(
        'success', true,
        'payout_id', v_new_payout_id,
        'amount', p_amount,
        'remaining_balance', v_store.balance - p_amount
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. ADMIN PROCESS PAYOUT RPC (admin_process_payout)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.admin_process_payout(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.admin_process_payout(UUID, TEXT, TEXT, TEXT);
CREATE OR REPLACE FUNCTION public.admin_process_payout(
    p_payout_id UUID,
    p_action TEXT,
    p_reason TEXT DEFAULT NULL,
    p_reference TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_payout RECORD;
BEGIN
    IF auth.uid() IS NULL OR NOT public.is_admin() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Administrator privileges required.');
    END IF;

    SELECT id, seller_store_id, amount, status
    INTO v_payout
    FROM public.seller_payout_requests
    WHERE id = p_payout_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Payout request not found');
    END IF;

    IF v_payout.status != 'Pending' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Payout request is already ' || v_payout.status);
    END IF;

    IF p_action = 'Approve' OR p_action = 'Process' THEN
        UPDATE public.seller_payout_requests
        SET status = 'Processed',
            processed_by = auth.uid(),
            gateway_reference = p_reference,
            updated_at = NOW()
        WHERE id = p_payout_id;

        UPDATE public.seller_stores
        SET pending_payout = GREATEST(0.00, COALESCE(pending_payout, 0.00) - v_payout.amount),
            last_payout = v_payout.amount,
            updated_at = NOW()
        WHERE id = v_payout.seller_store_id;

        RETURN jsonb_build_object('success', true, 'status', 'Processed');

    ELSIF p_action = 'Reject' THEN
        UPDATE public.seller_payout_requests
        SET status = 'Rejected',
            rejection_reason = p_reason,
            processed_by = auth.uid(),
            updated_at = NOW()
        WHERE id = p_payout_id;

        -- Restore amount to store balance
        UPDATE public.seller_stores
        SET balance = balance + v_payout.amount,
            pending_payout = GREATEST(0.00, COALESCE(pending_payout, 0.00) - v_payout.amount),
            updated_at = NOW()
        WHERE id = v_payout.seller_store_id;

        RETURN jsonb_build_object('success', true, 'status', 'Rejected');
    ELSE
        RETURN jsonb_build_object('success', false, 'error', 'Invalid action: Must be Approve, Process, or Reject');
    END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- 6. ADMIN SELLER SUSPENSION & PAYOUT LOCK RPCS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_toggle_seller_suspension(
    p_store_id UUID,
    p_is_suspended BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF auth.uid() IS NULL OR NOT public.is_admin() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Administrator privileges required.');
    END IF;

    UPDATE public.seller_stores
    SET is_suspended = p_is_suspended,
        updated_at = NOW()
    WHERE id = p_store_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Store not found');
    END IF;

    -- If suspended, deactivate listings
    IF p_is_suspended THEN
        UPDATE public.products
        SET is_active = false,
            updated_at = NOW()
        WHERE seller_store_id = p_store_id;
    END IF;

    RETURN jsonb_build_object('success', true, 'is_suspended', p_is_suspended);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_toggle_payout_lock(
    p_store_id UUID,
    p_is_locked BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF auth.uid() IS NULL OR NOT public.is_admin() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Administrator privileges required.');
    END IF;

    UPDATE public.seller_stores
    SET is_payout_locked = p_is_locked,
        updated_at = NOW()
    WHERE id = p_store_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Store not found');
    END IF;

    RETURN jsonb_build_object('success', true, 'is_payout_locked', p_is_locked);
END;
$$;

-- Revoke execution from PUBLIC & anon
REVOKE EXECUTE ON FUNCTION public.seller_request_payout(UUID, NUMERIC, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_process_payout(UUID, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_toggle_seller_suspension(UUID, BOOLEAN) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_toggle_payout_lock(UUID, BOOLEAN) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.seller_request_payout(UUID, NUMERIC, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_process_payout(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_toggle_seller_suspension(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_toggle_payout_lock(UUID, BOOLEAN) TO authenticated;
