-- Migration: 20260825000000_arbitration_hardening_and_audit_alignment.sql
-- Description: Hardened dispute arbitration with mandatory rejection notes, zero fallback pricing, exact public.app_role checks, and dual audit logging

-- 1. Ensure admin_audit_logs table definition exists
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID REFERENCES auth.users(id),
    action TEXT NOT NULL,
    target_type TEXT,
    target_id TEXT,
    details JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.admin_audit_logs FROM PUBLIC, anon;
GRANT SELECT, INSERT ON public.admin_audit_logs TO authenticated;

-- 2. Hardened admin_arbitrate_return_claim RPC
CREATE OR REPLACE FUNCTION public.admin_arbitrate_return_claim(
    p_claim_id UUID,
    p_decision TEXT, -- 'Approved' or 'Rejected'
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_admin_id UUID;
    v_has_privilege BOOLEAN;
    v_claim RECORD;
    v_refund_amount NUMERIC(12,2);
    v_idempotency_key TEXT;
    v_refund_res JSONB;
    v_refund_id UUID;
    v_trimmed_notes TEXT;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    -- Strict Server-Side RBAC Check against exact public.app_role enum
    SELECT EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = v_admin_id
          AND ur.role IN ('owner'::public.app_role, 'super_admin'::public.app_role, 'admin'::public.app_role)
    ) INTO v_has_privilege;

    IF NOT v_has_privilege THEN
        IF NOT public.has_permission('returns', 'review') THEN
            RAISE EXCEPTION 'Access denied: Insufficient administrative privileges to arbitrate return claims.' USING ERRCODE = '42501';
        END IF;
    END IF;

    IF p_decision NOT IN ('Approved', 'Rejected') THEN
        RAISE EXCEPTION 'Invalid arbitration decision: %. Must be Approved or Rejected.', p_decision USING ERRCODE = 'P0001';
    END IF;

    -- Validate notes rules
    v_trimmed_notes := NULLIF(TRIM(COALESCE(p_notes, '')), '');
    IF p_decision = 'Rejected' THEN
        IF v_trimmed_notes IS NULL THEN
            RAISE EXCEPTION 'Rejection notes are mandatory when rejecting a dispute claim.' USING ERRCODE = 'P0005';
        END IF;
        IF length(v_trimmed_notes) > 1000 THEN
            RAISE EXCEPTION 'Rejection notes cannot exceed 1000 characters.' USING ERRCODE = 'P0005';
        END IF;
    ELSIF p_decision = 'Approved' THEN
        IF v_trimmed_notes IS NOT NULL AND length(v_trimmed_notes) > 1000 THEN
            RAISE EXCEPTION 'Approval notes cannot exceed 1000 characters.' USING ERRCODE = 'P0005';
        END IF;
    END IF;

    -- Fetch and lock the claim row
    SELECT id, order_id, order_item_id, seller_store_id, customer_user_id, quantity, status
    INTO v_claim
    FROM public.return_requests
    WHERE id = p_claim_id
    FOR UPDATE;

    IF v_claim.id IS NULL THEN
        RAISE EXCEPTION 'Return claim % not found.', p_claim_id USING ERRCODE = 'P0002';
    END IF;

    -- Block already finalized claims
    IF v_claim.status IN ('Completed', 'Rejected') THEN
        RAISE EXCEPTION 'Claim % is already finalized in status %.', p_claim_id, v_claim.status USING ERRCODE = 'P0003';
    END IF;

    IF p_decision = 'Rejected' THEN
        UPDATE public.return_requests
        SET status = 'Rejected',
            admin_notes = v_trimmed_notes,
            processed_by = v_admin_id,
            updated_at = NOW()
        WHERE id = p_claim_id;

        -- Record Immutable Audit Log
        INSERT INTO public.admin_audit_logs (
            admin_id, action, target_type, target_id, details
        ) VALUES (
            v_admin_id,
            'DISPUTE_REJECTED',
            'return_requests',
            p_claim_id::text,
            jsonb_build_object(
                'order_id', v_claim.order_id,
                'decision', 'Rejected',
                'notes', v_trimmed_notes
            )
        );

        -- Notify Buyer
        PERFORM public.internal_create_notification(
            v_claim.customer_user_id,
            'RETURN_REJECTED',
            'Dispute Arbitration: Claim Rejected',
            v_trimmed_notes,
            'RETURN',
            p_claim_id::text,
            'NOTIF-DISP-' || p_claim_id::text || '-REJ'
        );

        RETURN jsonb_build_object(
            'success', TRUE,
            'claim_id', p_claim_id,
            'status', 'Rejected'
        );

    ELSIF p_decision = 'Approved' THEN
        -- Strictly query order line item unit price (NO fallback value)
        SELECT (unit_price * v_claim.quantity) INTO v_refund_amount
        FROM public.order_items
        WHERE id = v_claim.order_item_id;

        IF v_refund_amount IS NULL OR v_refund_amount <= 0.00 THEN
            RAISE EXCEPTION 'Cannot approve refund: Target order item % has missing or invalid price.', v_claim.order_item_id USING ERRCODE = 'P0004';
        END IF;

        v_idempotency_key := 'ARB-REF-' || p_claim_id::text;

        -- Process Authoritative Refund through Financial Ledger
        v_refund_res := public.admin_process_refund(
            v_claim.order_id,
            v_claim.order_item_id,
            v_refund_amount,
            COALESCE(v_trimmed_notes, 'Arbitrated Full Refund: Claim ' || p_claim_id::text),
            v_idempotency_key
        );

        v_refund_id := (v_refund_res->>'refund_id')::uuid;

        UPDATE public.return_requests
        SET status = 'Completed',
            refund_id = v_refund_id,
            admin_notes = v_trimmed_notes,
            processed_by = v_admin_id,
            updated_at = NOW()
        WHERE id = p_claim_id;

        -- Record Immutable Audit Log
        INSERT INTO public.admin_audit_logs (
            admin_id, action, target_type, target_id, details
        ) VALUES (
            v_admin_id,
            'DISPUTE_FULL_REFUND',
            'return_requests',
            p_claim_id::text,
            jsonb_build_object(
                'order_id', v_claim.order_id,
                'refund_id', v_refund_id,
                'refund_amount', v_refund_amount,
                'notes', v_trimmed_notes
            )
        );

        -- Notify Buyer
        PERFORM public.internal_create_notification(
            v_claim.customer_user_id,
            'RETURN_APPROVED',
            'Dispute Arbitration: Refund Approved',
            'Your dispute was resolved. A refund of PKR ' || v_refund_amount::text || ' was approved.',
            'RETURN',
            p_claim_id::text,
            'NOTIF-DISP-' || p_claim_id::text || '-APP'
        );

        RETURN jsonb_build_object(
            'success', TRUE,
            'claim_id', p_claim_id,
            'refund_id', v_refund_id,
            'refund_amount', v_refund_amount,
            'status', 'Completed'
        );
    END IF;

    RETURN jsonb_build_object('success', FALSE, 'error', 'Unhandled condition');
END;
$$;

REVOKE ALL ON FUNCTION public.admin_arbitrate_return_claim(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_arbitrate_return_claim(UUID, TEXT, TEXT) TO authenticated;
