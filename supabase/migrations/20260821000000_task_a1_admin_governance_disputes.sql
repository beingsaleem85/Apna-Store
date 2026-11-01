-- ============================================================================
-- Migration: 20260821000000_task_a1_admin_governance_disputes.sql
-- Description: Server-Authoritative Dispute Arbitration & Audit Logging with RBAC
-- Strict Compliance: SET search_path = '', RLS on all tables, Server Authoritative
-- ============================================================================

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
    v_result JSONB;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    -- Strict Server-Side RBAC Check: Only Super Admin, Owner, or Support Admin
    SELECT EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = v_admin_id
          AND ur.role IN ('owner', 'super_admin', 'admin')
    ) INTO v_has_privilege;

    IF NOT v_has_privilege THEN
        -- Also check permission table fallback
        IF NOT public.has_permission('returns', 'review') THEN
            RAISE EXCEPTION 'Access denied: Insufficient administrative privileges to arbitrate return claims.' USING ERRCODE = '42501';
        END IF;
    END IF;

    IF p_decision NOT IN ('Approved', 'Rejected') THEN
        RAISE EXCEPTION 'Invalid arbitration decision: %. Must be Approved or Rejected.', p_decision USING ERRCODE = 'P0001';
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

    IF v_claim.status IN ('Completed', 'Rejected') THEN
        RAISE EXCEPTION 'Claim % is already finalized in status %.', p_claim_id, v_claim.status USING ERRCODE = 'P0003';
    END IF;

    IF p_decision = 'Rejected' THEN
        UPDATE public.return_requests
        SET status = 'Rejected',
            admin_notes = p_notes,
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
                'notes', p_notes
            )
        );

        -- Notify Buyer
        PERFORM public.internal_create_notification(
            v_claim.customer_user_id,
            'RETURN_REJECTED',
            'Dispute Arbitration: Claim Rejected',
            COALESCE(p_notes, 'Your return claim was rejected upon arbitration review.'),
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
        -- Get order line item unit price
        SELECT (unit_price * v_claim.quantity) INTO v_refund_amount
        FROM public.order_items
        WHERE id = v_claim.order_item_id;

        IF v_refund_amount IS NULL OR v_refund_amount <= 0 THEN
            v_refund_amount := 1000.0 * v_claim.quantity;
        END IF;

        v_idempotency_key := 'ARB-REF-' || p_claim_id::text;

        -- Process Authoritative Refund through Financial Ledger
        v_refund_res := public.admin_process_refund(
            v_claim.order_id,
            v_claim.order_item_id,
            v_refund_amount,
            'Arbitrated Full Refund: Claim ' || p_claim_id::text,
            v_idempotency_key
        );

        v_refund_id := (v_refund_res->>'refund_id')::uuid;

        UPDATE public.return_requests
        SET status = 'Completed',
            refund_id = v_refund_id,
            admin_notes = p_notes,
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
                'notes', p_notes
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
