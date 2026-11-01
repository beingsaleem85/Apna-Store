-- Migration: 20260827000000_unify_audit_logs_and_staff_roles_rbac.sql
-- Description: Unifies audit logging into public.audit_logs, establishes 12 admin staff roles & permissions, creates is_order_refundable helper

-- ----------------------------------------------------------------------------
-- 1. UNIFY AUDIT LOGS (CANONICAL: public.audit_logs)
-- ----------------------------------------------------------------------------
-- Ensure public.audit_logs has all needed columns
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS details JSONB DEFAULT '{}'::jsonb;

-- Internal recording helper: Canonical writer for all administrative actions
CREATE OR REPLACE FUNCTION public.internal_record_audit_log(
    p_target_type TEXT,
    p_target_id TEXT,
    p_action TEXT,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_actor UUID;
    v_role public.app_role;
    v_id UUID;
BEGIN
    v_actor := auth.uid();
    IF v_actor IS NULL THEN
        RAISE EXCEPTION 'Authentication required for audit logging.' USING ERRCODE = '42501';
    END IF;

    v_role := COALESCE(public.get_current_user_role(), 'admin'::public.app_role);

    INSERT INTO public.audit_logs (
        actor_user_id,
        actor_role,
        action,
        target_type,
        target_id,
        metadata,
        details
    ) VALUES (
        v_actor,
        v_role,
        p_action,
        p_target_type,
        p_target_id,
        p_metadata,
        p_metadata
    )
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

-- Convert public.admin_audit_logs into a backward-compatibility view safely
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'admin_audit_logs'
    ) THEN
        INSERT INTO public.audit_logs (
            actor_user_id,
            actor_role,
            action,
            target_type,
            target_id,
            metadata,
            details,
            created_at
        )
        SELECT
            COALESCE(admin_user_id, admin_id),
            'admin'::public.app_role,
            COALESCE(action, action_type, 'ADMIN_ACTION'),
            COALESCE(target_type, target_entity, 'UNKNOWN'),
            COALESCE(target_id, 'UNKNOWN'),
            COALESCE(details, '{}'::jsonb),
            COALESCE(details, '{}'::jsonb),
            COALESCE(created_at, NOW())
        FROM public.admin_audit_logs;

        DROP TABLE public.admin_audit_logs CASCADE;
    END IF;
END $$;

CREATE OR REPLACE VIEW public.admin_audit_logs AS
SELECT
    id,
    actor_user_id AS admin_id,
    actor_user_id AS admin_user_id,
    action,
    action AS action_type,
    target_type,
    target_type AS target_entity,
    target_id,
    COALESCE(metadata, details, '{}'::jsonb) AS details,
    created_at
FROM public.audit_logs;

CREATE OR REPLACE FUNCTION public.trg_admin_audit_logs_compat_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.audit_logs (
        actor_user_id,
        actor_role,
        action,
        target_type,
        target_id,
        metadata,
        details
    ) VALUES (
        COALESCE(NEW.admin_id, NEW.admin_user_id, auth.uid()),
        COALESCE(public.get_current_user_role(), 'admin'::public.app_role),
        COALESCE(NEW.action, NEW.action_type, 'ADMIN_ACTION'),
        COALESCE(NEW.target_type, NEW.target_entity, 'UNKNOWN'),
        COALESCE(NEW.target_id, 'UNKNOWN'),
        COALESCE(NEW.details, '{}'::jsonb),
        COALESCE(NEW.details, '{}'::jsonb)
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_admin_audit_logs_compat ON public.admin_audit_logs;
CREATE TRIGGER trg_admin_audit_logs_compat
    INSTEAD OF INSERT ON public.admin_audit_logs
    FOR EACH ROW EXECUTE FUNCTION public.trg_admin_audit_logs_compat_insert();

-- ----------------------------------------------------------------------------
-- 2. 12 ADMIN STAFF ROLES & PERMISSIONS SYSTEM
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'admin_staff_role') THEN
        CREATE TYPE public.admin_staff_role AS ENUM (
            'owner',
            'superAdmin',
            'financeAdmin',
            'sellerManager',
            'supportAdmin',
            'catalogManager',
            'orderManager',
            'disputeManager',
            'marketingManager',
            'fraudAnalyst',
            'reportingAnalyst',
            'auditor',
            'shippingManager'
        );
    END IF;
END $$;

ALTER TABLE public.user_roles ADD COLUMN IF NOT EXISTS staff_role public.admin_staff_role;

CREATE TABLE IF NOT EXISTS public.staff_role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_role public.admin_staff_role NOT NULL,
    module TEXT NOT NULL,
    action TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT staff_role_permissions_key UNIQUE (staff_role, module, action)
);

ALTER TABLE public.staff_role_permissions ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.staff_role_permissions TO authenticated;

-- Seed exact permissions mirroring RbacEngine.permissionMatrix from rbac_engine.dart
INSERT INTO public.staff_role_permissions (staff_role, module, action) VALUES
    ('owner', '*', '*'),
    ('superAdmin', '*', '*'),
    -- financeAdmin
    ('financeAdmin', 'finance', 'view'),
    ('financeAdmin', 'finance', 'approve'),
    ('financeAdmin', 'finance', 'export'),
    ('financeAdmin', 'finance', 'adjust'),
    ('financeAdmin', 'commission', 'view'),
    ('financeAdmin', 'commission', 'edit'),
    ('financeAdmin', 'commission', 'approve'),
    ('financeAdmin', 'payouts', 'view'),
    ('financeAdmin', 'payouts', 'approve'),
    ('financeAdmin', 'payouts', 'hold'),
    ('financeAdmin', 'payouts', 'export'),
    ('financeAdmin', 'disputes', 'view'),
    ('financeAdmin', 'disputes', 'refund'),
    ('financeAdmin', 'reports', 'view'),
    ('financeAdmin', 'reports', 'export'),
    -- sellerManager
    ('sellerManager', 'sellers', 'view'),
    ('sellerManager', 'sellers', 'approve'),
    ('sellerManager', 'sellers', 'reject'),
    ('sellerManager', 'sellers', 'suspend'),
    ('sellerManager', 'sellers', 'edit'),
    ('sellerManager', 'kyc', 'view'),
    ('sellerManager', 'kyc', 'verify'),
    ('sellerManager', 'kyc', 'reject'),
    ('sellerManager', 'products', 'view'),
    ('sellerManager', 'products', 'moderate'),
    ('sellerManager', 'support', 'view'),
    ('sellerManager', 'support', 'respond'),
    -- supportAdmin
    ('supportAdmin', 'support', 'view'),
    ('supportAdmin', 'support', 'assign'),
    ('supportAdmin', 'support', 'respond'),
    ('supportAdmin', 'support', 'close'),
    ('supportAdmin', 'customers', 'view'),
    ('supportAdmin', 'customers', 'assist'),
    ('supportAdmin', 'orders', 'view'),
    ('supportAdmin', 'orders', 'hold'),
    ('supportAdmin', 'disputes', 'view'),
    ('supportAdmin', 'disputes', 'escalate'),
    -- catalogManager
    ('catalogManager', 'categories', 'view'),
    ('catalogManager', 'categories', 'create'),
    ('catalogManager', 'categories', 'edit'),
    ('catalogManager', 'categories', 'delete'),
    ('catalogManager', 'products', 'view'),
    ('catalogManager', 'products', 'approve'),
    ('catalogManager', 'products', 'reject'),
    ('catalogManager', 'products', 'suspend'),
    ('catalogManager', 'brands', 'view'),
    ('catalogManager', 'brands', 'verify'),
    -- orderManager
    ('orderManager', 'orders', 'view'),
    ('orderManager', 'orders', 'cancel'),
    ('orderManager', 'orders', 'hold'),
    ('orderManager', 'orders', 'release'),
    ('orderManager', 'orders', 'reassign'),
    ('orderManager', 'shipping', 'view'),
    ('orderManager', 'shipping', 'update'),
    ('orderManager', 'shipping', 'assign'),
    ('orderManager', 'shipping', 'edit'),
    -- shippingManager
    ('shippingManager', 'orders', 'view'),
    ('shippingManager', 'orders', 'release'),
    ('shippingManager', 'shipping', 'view'),
    ('shippingManager', 'shipping', 'update'),
    ('shippingManager', 'shipping', 'assign'),
    ('shippingManager', 'shipping', 'edit'),
    -- disputeManager (Explicitly has returns:review / disputes:refund)
    ('disputeManager', 'disputes', 'view'),
    ('disputeManager', 'disputes', 'approve'),
    ('disputeManager', 'disputes', 'reject'),
    ('disputeManager', 'disputes', 'refund'),
    ('disputeManager', 'disputes', 'appeal'),
    ('disputeManager', 'returns', 'review'),
    ('disputeManager', 'returns', 'view'),
    ('disputeManager', 'orders', 'view'),
    -- marketingManager
    ('marketingManager', 'promotions', 'view'),
    ('marketingManager', 'promotions', 'create'),
    ('marketingManager', 'promotions', 'edit'),
    ('marketingManager', 'promotions', 'approve'),
    ('marketingManager', 'cms', 'view'),
    ('marketingManager', 'cms', 'edit'),
    ('marketingManager', 'notifications', 'view'),
    ('marketingManager', 'notifications', 'send'),
    ('marketingManager', 'notifications', 'schedule'),
    -- fraudAnalyst
    ('fraudAnalyst', 'fraud', 'view'),
    ('fraudAnalyst', 'fraud', 'blacklist'),
    ('fraudAnalyst', 'fraud', 'score'),
    ('fraudAnalyst', 'fraud', 'audit'),
    ('fraudAnalyst', 'customers', 'view'),
    ('fraudAnalyst', 'customers', 'suspend'),
    ('fraudAnalyst', 'orders', 'view'),
    ('fraudAnalyst', 'orders', 'hold'),
    -- reportingAnalyst
    ('reportingAnalyst', 'reports', 'view'),
    ('reportingAnalyst', 'reports', 'export'),
    ('reportingAnalyst', 'dashboard', 'view'),
    ('reportingAnalyst', 'sellers', 'view'),
    ('reportingAnalyst', 'orders', 'view'),
    -- auditor
    ('auditor', '*', 'view')
ON CONFLICT (staff_role, module, action) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. UPDATED has_permission RESOLVING 12 STAFF ROLES
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.has_permission(required_module TEXT, required_action TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_uid UUID;
    v_app_role public.app_role;
    v_staff_role public.admin_staff_role;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RETURN FALSE;
    END IF;

    -- 1. Check Owner / Super Admin bypass from user_roles
    IF EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_uid
          AND (
              role IN ('owner'::public.app_role, 'super_admin'::public.app_role)
              OR staff_role IN ('owner'::public.admin_staff_role, 'superAdmin'::public.admin_staff_role)
          )
    ) THEN
        RETURN TRUE;
    END IF;

    -- 2. Check granular staff_role permissions from staff_role_permissions table
    SELECT staff_role INTO v_staff_role
    FROM public.user_roles
    WHERE user_id = v_uid
      AND staff_role IS NOT NULL
    ORDER BY granted_at DESC
    LIMIT 1;

    IF v_staff_role IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM public.staff_role_permissions srp
            WHERE srp.staff_role = v_staff_role
              AND (srp.module = '*' OR srp.module = required_module OR (required_module = 'returns' AND srp.module = 'disputes'))
              AND (srp.action = '*' OR srp.action = required_action)
        ) THEN
            RETURN TRUE;
        END IF;
    END IF;

    -- 3. Check legacy role_permissions table
    v_app_role := public.get_current_user_role();
    IF v_app_role IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM public.role_permissions rp
            WHERE rp.role = v_app_role
              AND (rp.module = '*' OR rp.module = required_module)
              AND (rp.action = '*' OR rp.action = required_action)
        ) THEN
            RETURN TRUE;
        END IF;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

-- ----------------------------------------------------------------------------
-- 4. SHARED MONEY COLLECTION HELPER: is_order_refundable
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_order_refundable(p_order_id TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_status TEXT;
    v_payment_status TEXT;
    v_payment_method TEXT;
BEGIN
    SELECT status, payment_status, payment_method
    INTO v_status, v_payment_status, v_payment_method
    FROM public.buyer_orders
    WHERE id = p_order_id;

    IF v_status IS NULL THEN
        RETURN FALSE;
    END IF;

    -- Paid digital payments
    IF v_payment_status = 'Paid' THEN
        RETURN TRUE;
    END IF;

    -- Cash on Delivery: money is collected only when delivered to buyer
    IF v_payment_method IN ('Cash on Delivery', 'COD') AND v_status = 'Delivered' THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_order_refundable(TEXT) TO authenticated, anon;

-- ----------------------------------------------------------------------------
-- 5. REFIT admin_arbitrate_return_claim USING HELPER & UNIFIED AUDIT LOGGING
-- ----------------------------------------------------------------------------
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

    -- Strict RBAC: Check has_permission('returns', 'review') with owner/super_admin bypass only
    IF NOT public.has_permission('returns', 'review') THEN
        RAISE EXCEPTION 'Access denied: Insufficient administrative privileges to arbitrate return claims.' USING ERRCODE = '42501';
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

        -- Record Immutable Audit Log via canonical helper
        PERFORM public.internal_record_audit_log(
            'return_requests',
            p_claim_id::text,
            'DISPUTE_REJECTED',
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
        -- Check money was collected before approving via shared helper
        IF NOT public.is_order_refundable(v_claim.order_id) THEN
            RAISE EXCEPTION 'Cannot approve refund: Order % has not been collected/delivered or paid.',
                v_claim.order_id USING ERRCODE = 'P0006';
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

        -- Record Immutable Audit Log via canonical helper
        PERFORM public.internal_record_audit_log(
            'return_requests',
            p_claim_id::text,
            'DISPUTE_FULL_REFUND',
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

-- ----------------------------------------------------------------------------
-- 6. REFIT review_return_request USING is_order_refundable & UNIFIED AUDIT LOGGING
-- ----------------------------------------------------------------------------
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
        -- Check money was collected before approving via shared helper
        IF NOT public.is_order_refundable(v_return.order_id) THEN
            RAISE EXCEPTION 'Cannot approve return: Order % is not in a paid or collected state.',
                v_return.order_id USING ERRCODE = 'P0006';
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
