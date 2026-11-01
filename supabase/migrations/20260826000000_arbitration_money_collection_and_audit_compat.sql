-- Migration: 20260826000000_arbitration_money_collection_and_audit_compat.sql
-- Description: Money collection check on refunds, strict has_permission RBAC, admin_fetch_return_claims RPC, and admin_audit_logs column compatibility

-- 1. admin_audit_logs backward compatibility columns
ALTER TABLE public.admin_audit_logs ADD COLUMN IF NOT EXISTS target_entity TEXT;
ALTER TABLE public.admin_audit_logs ADD COLUMN IF NOT EXISTS admin_user_id UUID REFERENCES auth.users(id);
ALTER TABLE public.admin_audit_logs ADD COLUMN IF NOT EXISTS action_type TEXT;

-- 2. Server-Authoritative Dispute Arbitration RPC
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
    v_order_status TEXT;
    v_payment_status TEXT;
    v_payment_method TEXT;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    -- Strict RBAC: Check has_permission('returns', 'review') with owner/super_admin bypass only
    SELECT EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = v_admin_id
          AND ur.role IN ('owner'::public.app_role, 'super_admin'::public.app_role)
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
            admin_id, action, target_type, target_entity, target_id, details
        ) VALUES (
            v_admin_id,
            'DISPUTE_REJECTED',
            'return_requests',
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
        -- Check order money collection status
        SELECT status, payment_status, payment_method
        INTO v_order_status, v_payment_status, v_payment_method
        FROM public.buyer_orders
        WHERE id = v_claim.order_id;

        IF NOT (
            v_payment_status = 'Paid'
            OR (v_payment_method = 'COD' AND v_order_status = 'Delivered')
        ) THEN
            RAISE EXCEPTION 'Cannot approve refund: Order % has not been collected/delivered (status: %, payment_status: %).',
                v_claim.order_id, v_order_status, v_payment_status USING ERRCODE = 'P0006';
        END IF;

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
            admin_id, action, target_type, target_entity, target_id, details
        ) VALUES (
            v_admin_id,
            'DISPUTE_FULL_REFUND',
            'return_requests',
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

-- 3. Update review_return_request with money collection check
CREATE OR REPLACE FUNCTION public.review_return_request(
    p_return_id UUID,
    p_decision TEXT, -- 'Approved' or 'Rejected'
    p_admin_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_reviewer_id UUID;
    v_return RECORD;
    v_refund_amount NUMERIC(12,2);
    v_idempotency_key TEXT;
    v_refund_res JSONB;
    v_refund_id UUID;
    v_result JSONB;
    v_order_status TEXT;
    v_payment_status TEXT;
    v_payment_method TEXT;
BEGIN
    v_reviewer_id := auth.uid();
    IF v_reviewer_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    IF p_decision NOT IN ('Approved', 'Rejected') THEN
        RAISE EXCEPTION 'Invalid return review decision: %', p_decision USING ERRCODE = 'P0001';
    END IF;

    -- Lock & Fetch Return Request Row
    SELECT id, order_id, order_item_id, seller_store_id, customer_user_id, quantity, status
    INTO v_return
    FROM public.return_requests
    WHERE id = p_return_id FOR UPDATE;

    IF v_return.id IS NULL THEN
        RAISE EXCEPTION 'Return request % not found.', p_return_id USING ERRCODE = 'P0002';
    END IF;

    -- Authorization: Seller store owner or Admin with returns:review permission
    IF NOT (
        EXISTS (SELECT 1 FROM public.seller_stores WHERE id = v_return.seller_store_id AND owner_id = v_reviewer_id)
        OR EXISTS (
            SELECT 1 FROM public.user_roles ur
            WHERE ur.user_id = v_reviewer_id
              AND ur.role IN ('owner'::public.app_role, 'super_admin'::public.app_role)
        )
        OR public.has_permission('returns', 'review')
    ) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to review return request.' USING ERRCODE = '42501';
    END IF;

    IF v_return.status <> 'Requested' THEN
        RAISE EXCEPTION 'Return request % is already in % status.', p_return_id, v_return.status USING ERRCODE = 'P0003';
    END IF;

    IF p_decision = 'Rejected' THEN
        UPDATE public.return_requests
        SET status = 'Rejected', admin_notes = p_admin_notes, processed_by = v_reviewer_id, updated_at = NOW()
        WHERE id = p_return_id;

        PERFORM public.internal_create_notification(
            v_return.customer_user_id,
            'RETURN_REJECTED',
            'Return Request Rejected',
            COALESCE(p_admin_notes, 'Your return request for order ' || v_return.order_id || ' was rejected.'),
            'RETURN',
            p_return_id::text,
            'NOTIF-RET-DEC-' || p_return_id::text || '-REJ'
        );

        RETURN jsonb_build_object('success', TRUE, 'status', 'Rejected', 'return_id', p_return_id);

    ELSIF p_decision = 'Approved' THEN
        -- Check money was collected before approving
        SELECT status, payment_status, payment_method
        INTO v_order_status, v_payment_status, v_payment_method
        FROM public.buyer_orders
        WHERE id = v_return.order_id;

        IF NOT (
            v_payment_status = 'Paid'
            OR (v_payment_method = 'COD' AND v_order_status = 'Delivered')
        ) THEN
            RAISE EXCEPTION 'Cannot approve return: Order % is not in a paid or collected state (status: %, payment_status: %).',
                v_return.order_id, v_order_status, v_payment_status USING ERRCODE = 'P0006';
        END IF;

        -- Calculate Refund Amount based on Line Item Unit Price * Returned Quantity
        SELECT (unit_price * v_return.quantity) INTO v_refund_amount
        FROM public.order_items
        WHERE id = v_return.order_item_id;

        IF v_refund_amount IS NULL OR v_refund_amount <= 0.00 THEN
            RAISE EXCEPTION 'Cannot approve return: Order item has invalid price.' USING ERRCODE = 'P0004';
        END IF;

        v_idempotency_key := 'REF-RET-' || p_return_id::text;

        -- Invoke Phase 10 Authoritative Refund Function
        v_refund_res := public.admin_process_refund(
            v_return.order_id,
            v_return.order_item_id,
            v_refund_amount,
            COALESCE(p_admin_notes, 'Seller approved return: ' || p_return_id::text),
            v_idempotency_key
        );

        v_refund_id := (v_refund_res->>'refund_id')::uuid;

        UPDATE public.return_requests
        SET status = 'Completed', refund_id = v_refund_id, admin_notes = p_admin_notes, processed_by = v_reviewer_id, updated_at = NOW()
        WHERE id = p_return_id;

        PERFORM public.internal_create_notification(
            v_return.customer_user_id,
            'RETURN_APPROVED',
            'Return Request Approved',
            'Your return request for order ' || v_return.order_id || ' was approved and refunded.',
            'RETURN',
            p_return_id::text,
            'NOTIF-RET-DEC-' || p_return_id::text || '-APP'
        );

        RETURN jsonb_build_object('success', TRUE, 'status', 'Completed', 'return_id', p_return_id, 'refund_id', v_refund_id);
    END IF;

    RETURN jsonb_build_object('success', FALSE, 'error', 'Unhandled condition');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- 4. Server-Authoritative Paginated Admin RPC for claims list
CREATE OR REPLACE FUNCTION public.admin_fetch_return_claims(
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0,
    p_status TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    order_id TEXT,
    order_item_id UUID,
    seller_store_id UUID,
    seller_store_name TEXT,
    customer_user_id UUID,
    customer_name TEXT,
    product_name TEXT,
    quantity INT,
    requested_amount NUMERIC(12,2),
    reason TEXT,
    status TEXT,
    admin_notes TEXT,
    created_at TIMESTAMPTZ,
    total_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_admin_id UUID;
    v_has_privilege BOOLEAN;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    -- Strict RBAC check
    SELECT EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = v_admin_id
          AND ur.role IN ('owner'::public.app_role, 'super_admin'::public.app_role)
    ) INTO v_has_privilege;

    IF NOT v_has_privilege THEN
        IF NOT public.has_permission('returns', 'review') AND NOT public.has_permission('finance', 'view') THEN
            RAISE EXCEPTION 'Access denied: Insufficient privileges.' USING ERRCODE = '42501';
        END IF;
    END IF;

    RETURN QUERY
    WITH filtered AS (
        SELECT rr.*
        FROM public.return_requests rr
        WHERE (p_status IS NULL OR rr.status = p_status)
    ),
    counted AS (
        SELECT COUNT(*) AS cnt FROM filtered
    )
    SELECT
        f.id,
        f.order_id,
        f.order_item_id,
        f.seller_store_id,
        COALESCE(ss.name, 'Seller Store')::TEXT AS seller_store_name,
        f.customer_user_id,
        COALESCE(p.full_name, bo.customer_name, 'Verified Buyer')::TEXT AS customer_name,
        COALESCE(oi.product_name, 'Order Item #' || f.order_id)::TEXT AS product_name,
        f.quantity,
        COALESCE(oi.total_price, (oi.unit_price * f.quantity), 0.00)::NUMERIC(12,2) AS requested_amount,
        f.reason,
        f.status,
        f.admin_notes,
        f.created_at,
        c.cnt AS total_count
    FROM filtered f
    CROSS JOIN counted c
    LEFT JOIN public.seller_stores ss ON ss.id = f.seller_store_id
    LEFT JOIN public.profiles p ON p.id = f.customer_user_id
    LEFT JOIN public.buyer_orders bo ON bo.id = f.order_id
    LEFT JOIN public.order_items oi ON oi.id = f.order_item_id
    ORDER BY f.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_fetch_return_claims(INT, INT, TEXT) TO authenticated;
