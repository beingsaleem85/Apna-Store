-- ============================================================================
-- APNA STORE — PHASE 6: GRANULAR RBAC, SERVER-SIDE SECURITY & IMMUTABLE AUDIT LOGS
-- Migration: 20260806000000_phase_6_rbac_admin_audit.sql
-- Description: Establishes role_permissions table, immutable audit_logs table,
--              internal audit logging helper, granular has_permission() check,
--              and retrofitted/hardened SECURITY DEFINER RPC functions.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. ADD NEW PROTECTED SECURITY COLUMNS TO seller_stores
-- ----------------------------------------------------------------------------
ALTER TABLE public.seller_stores
    ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS payout_locked BOOLEAN NOT NULL DEFAULT FALSE;

-- Revoke direct UPDATE on newly added protected fields from authenticated/anon clients
REVOKE ALL ON public.seller_stores FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.seller_stores TO anon, authenticated;
GRANT INSERT (owner_id, shop_name, shop_slug, business_name, business_address, city, country, category, shop_description, shop_logo, shop_banner) ON public.seller_stores TO authenticated;
GRANT UPDATE (shop_name, shop_slug, business_name, business_address, city, country, category, shop_description, shop_logo, shop_banner, updated_at) ON public.seller_stores TO authenticated;

-- ----------------------------------------------------------------------------
-- 2. PROTECTED GRANULAR ROLE PERMISSIONS TABLE (role_permissions)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role public.app_role NOT NULL,
    module TEXT NOT NULL,
    action TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT role_permissions_role_module_action_key UNIQUE (role, module, action)
);

ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.role_permissions FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.role_permissions TO authenticated;

DROP POLICY IF EXISTS "Authenticated users view role permissions" ON public.role_permissions;
CREATE POLICY "Authenticated users view role permissions" ON public.role_permissions
    FOR SELECT USING (auth.uid() IS NOT NULL);

-- Seed Canonical Role Permissions Matrix
INSERT INTO public.role_permissions (role, module, action) VALUES
    ('owner'::public.app_role, '*', '*'),
    ('super_admin'::public.app_role, '*', '*'),
    ('admin'::public.app_role, 'sellers', 'view'),
    ('admin'::public.app_role, 'sellers', 'approve'),
    ('admin'::public.app_role, 'sellers', 'suspend'),
    ('admin'::public.app_role, 'kyc', 'view'),
    ('admin'::public.app_role, 'kyc', 'verify'),
    ('admin'::public.app_role, 'products', 'view'),
    ('admin'::public.app_role, 'products', 'approve'),
    ('admin'::public.app_role, 'finance', 'view'),
    ('admin'::public.app_role, 'finance', 'adjust'),
    ('admin'::public.app_role, 'commission', 'view'),
    ('admin'::public.app_role, 'commission', 'edit'),
    ('admin'::public.app_role, 'payouts', 'view'),
    ('admin'::public.app_role, 'payouts', 'hold'),
    ('admin'::public.app_role, 'roles', 'assign'),
    ('seller'::public.app_role, 'store', 'manage'),
    ('seller'::public.app_role, 'products', 'create'),
    ('seller'::public.app_role, 'kyc', 'submit'),
    ('buyer'::public.app_role, 'orders', 'create')
ON CONFLICT (role, module, action) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. IMMUTABLE AUDIT LOGS TABLE & TRIGGER (audit_logs)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_user_id UUID REFERENCES auth.users(id),
    actor_role public.app_role NOT NULL,
    action TEXT NOT NULL,
    target_type TEXT NOT NULL,
    target_id TEXT NOT NULL,
    metadata JSONB DEFAULT '{}'::jsonb,
    correlation_id UUID DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.audit_logs FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.audit_logs TO authenticated;

DROP POLICY IF EXISTS "Admins can view audit logs" ON public.audit_logs;
CREATE POLICY "Admins can view audit logs" ON public.audit_logs
    FOR SELECT USING (public.is_admin());

-- Immutable Trigger: Block ANY direct UPDATE or DELETE on audit_logs
CREATE OR REPLACE FUNCTION public.prevent_audit_log_tampering()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Audit log records are immutable and cannot be modified or deleted.';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

DROP TRIGGER IF EXISTS trg_prevent_audit_log_tampering ON public.audit_logs;
CREATE TRIGGER trg_prevent_audit_log_tampering
    BEFORE UPDATE OR DELETE ON public.audit_logs
    FOR EACH ROW EXECUTE PROCEDURE public.prevent_audit_log_tampering();

-- Internal Audit Logging Helper (Revoked from PUBLIC/client execution; only RPCs can invoke)
CREATE OR REPLACE FUNCTION public.internal_record_audit_log(
    p_target_type TEXT,
    p_target_id TEXT,
    p_action TEXT,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID AS $$
DECLARE
    v_actor UUID;
    v_role public.app_role;
    v_id UUID;
BEGIN
    v_actor := auth.uid();
    IF v_actor IS NULL THEN
        RAISE EXCEPTION 'Authentication required for audit logging.';
    END IF;

    v_role := public.get_current_user_role();

    INSERT INTO public.audit_logs (
        actor_user_id,
        actor_role,
        action,
        target_type,
        target_id,
        metadata,
        correlation_id,
        created_at
    ) VALUES (
        v_actor,
        v_role,
        p_action,
        p_target_type,
        p_target_id,
        p_metadata,
        gen_random_uuid(),
        NOW()
    ) RETURNING id INTO v_id;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

REVOKE EXECUTE ON FUNCTION public.internal_record_audit_log(TEXT, TEXT, TEXT, JSONB) FROM PUBLIC, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 4. GRANULAR PERMISSION CHECKING FUNCTION (has_permission)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.has_permission(required_module TEXT, required_action TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_role public.app_role;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;

    v_role := public.get_current_user_role();

    -- Owner and Super Admin have full unrestricted privileges
    IF v_role IN ('owner'::public.app_role, 'super_admin'::public.app_role) THEN
        RETURN TRUE;
    END IF;

    -- Evaluate explicit permission mapping in role_permissions table
    RETURN EXISTS (
        SELECT 1 FROM public.role_permissions
        WHERE role = v_role
          AND (module = '*' OR module = required_module)
          AND (action = '*' OR action = required_action)
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

-- ----------------------------------------------------------------------------
-- 5. HARDENED & RETROFITTED PRIVILEGED RPC FUNCTIONS WITH AUDIT LOGGING
-- ----------------------------------------------------------------------------

-- A. assign_user_role
CREATE OR REPLACE FUNCTION public.assign_user_role(target_user_id UUID, new_role public.app_role)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT public.has_permission('roles', 'assign') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for role assignment.';
    END IF;

    INSERT INTO public.user_roles (user_id, role, granted_by)
    VALUES (target_user_id, new_role, auth.uid())
    ON CONFLICT (user_id, role) DO UPDATE SET granted_at = NOW(), granted_by = auth.uid();

    PERFORM public.internal_record_audit_log(
        'user_roles',
        target_user_id::text,
        'ASSIGN_USER_ROLE',
        jsonb_build_object('assigned_role', new_role::text)
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- B. admin_review_seller_store
CREATE OR REPLACE FUNCTION public.admin_review_seller_store(
    target_store_id UUID,
    approve BOOLEAN,
    new_commission NUMERIC(5,2) DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT public.has_permission('sellers', 'approve') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for seller store review.';
    END IF;

    UPDATE public.seller_stores
    SET is_approved = approve,
        commission_rate = COALESCE(new_commission, commission_rate),
        updated_at = NOW()
    WHERE id = target_store_id;

    PERFORM public.internal_record_audit_log(
        'seller_stores',
        target_store_id::text,
        'REVIEW_SELLER_STORE',
        jsonb_build_object('is_approved', approve, 'commission_rate', new_commission)
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- C. admin_review_kyc_document
CREATE OR REPLACE FUNCTION public.admin_review_kyc_document(
    target_kyc_id UUID,
    new_status TEXT,
    reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT public.has_permission('kyc', 'verify') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for KYC document review.';
    END IF;

    IF new_status NOT IN ('Approved', 'Rejected', 'Pending') THEN
        RAISE EXCEPTION 'Invalid KYC status value.';
    END IF;

    UPDATE public.seller_kyc_documents
    SET status = new_status,
        reviewed_by = auth.uid(),
        reviewed_at = NOW(),
        rejection_reason = reason,
        updated_at = NOW()
    WHERE id = target_kyc_id;

    IF new_status = 'Approved' THEN
        UPDATE public.seller_stores
        SET kyc_status = 'Approved', updated_at = NOW()
        WHERE id = (SELECT seller_store_id FROM public.seller_kyc_documents WHERE id = target_kyc_id);
    END IF;

    PERFORM public.internal_record_audit_log(
        'seller_kyc_documents',
        target_kyc_id::text,
        'REVIEW_KYC_DOCUMENT',
        jsonb_build_object('kyc_status', new_status, 'rejection_reason', reason)
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- D. admin_review_product
CREATE OR REPLACE FUNCTION public.admin_review_product(
    target_product_id UUID,
    approve BOOLEAN
)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT public.has_permission('products', 'approve') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for product approval.';
    END IF;

    -- Strict Self-Approval Protection: Sellers cannot approve their own products even if they possess an admin role
    IF EXISTS (
        SELECT 1 FROM public.products p
        JOIN public.seller_stores s ON s.id = p.seller_store_id
        WHERE p.id = target_product_id AND s.owner_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Access denied: Sellers cannot approve their own products.';
    END IF;

    UPDATE public.products
    SET approval_status = CASE WHEN approve THEN 'Approved' ELSE 'Rejected' END,
        updated_at = NOW()
    WHERE id = target_product_id;

    PERFORM public.internal_record_audit_log(
        'products',
        target_product_id::text,
        'REVIEW_PRODUCT',
        jsonb_build_object('approval_status', CASE WHEN approve THEN 'Approved' ELSE 'Rejected' END)
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- E. admin_adjust_seller_wallet (NEW FINANCIAL RPC)
CREATE OR REPLACE FUNCTION public.admin_adjust_seller_wallet(
    target_store_id UUID,
    amount_delta NUMERIC(12,2),
    reason TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_old_bal NUMERIC(12,2);
    v_new_bal NUMERIC(12,2);
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT public.has_permission('finance', 'adjust') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for wallet adjustment.';
    END IF;

    SELECT balance INTO v_old_bal FROM public.seller_stores WHERE id = target_store_id;
    IF v_old_bal IS NULL THEN
        RAISE EXCEPTION 'Target store not found.';
    END IF;

    v_new_bal := v_old_bal + amount_delta;
    IF v_new_bal < 0.00 THEN
        RAISE EXCEPTION 'Invalid transaction: Resulting balance cannot be negative.';
    END IF;

    UPDATE public.seller_stores
    SET balance = v_new_bal, updated_at = NOW()
    WHERE id = target_store_id;

    PERFORM public.internal_record_audit_log(
        'seller_stores',
        target_store_id::text,
        'ADJUST_SELLER_WALLET',
        jsonb_build_object('amount_delta', amount_delta, 'old_balance', v_old_bal, 'new_balance', v_new_bal, 'reason', reason)
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- F. admin_toggle_seller_suspension (NEW GOVERNANCE RPC)
CREATE OR REPLACE FUNCTION public.admin_toggle_seller_suspension(
    target_store_id UUID,
    suspend BOOLEAN,
    reason TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT public.has_permission('sellers', 'suspend') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for seller suspension.';
    END IF;

    UPDATE public.seller_stores
    SET is_suspended = suspend, updated_at = NOW()
    WHERE id = target_store_id;

    PERFORM public.internal_record_audit_log(
        'seller_stores',
        target_store_id::text,
        'TOGGLE_SELLER_SUSPENSION',
        jsonb_build_object('is_suspended', suspend, 'reason', reason)
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- G. admin_toggle_payout_lock (NEW FINANCIAL GOVERNANCE RPC)
CREATE OR REPLACE FUNCTION public.admin_toggle_payout_lock(
    target_store_id UUID,
    lock_state BOOLEAN,
    reason TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT public.has_permission('payouts', 'hold') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for payout lock management.';
    END IF;

    UPDATE public.seller_stores
    SET payout_locked = lock_state, updated_at = NOW()
    WHERE id = target_store_id;

    PERFORM public.internal_record_audit_log(
        'seller_stores',
        target_store_id::text,
        'TOGGLE_PAYOUT_LOCK',
        jsonb_build_object('payout_locked', lock_state, 'reason', reason)
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- H. assign_role_permission (OWNER / SUPER ADMIN PERMISSION MANAGEMENT RPC)
CREATE OR REPLACE FUNCTION public.assign_role_permission(
    target_role public.app_role,
    target_module TEXT,
    target_action TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    -- Only Owner and Super Admin can manage role_permissions mapping
    IF public.get_current_user_role() NOT IN ('owner'::public.app_role, 'super_admin'::public.app_role) THEN
        RAISE EXCEPTION 'Access denied: Owner or Super Admin privileges required for permission management.';
    END IF;

    INSERT INTO public.role_permissions (role, module, action)
    VALUES (target_role, target_module, target_action)
    ON CONFLICT (role, module, action) DO NOTHING;

    PERFORM public.internal_record_audit_log(
        'role_permissions',
        target_role::text,
        'ASSIGN_ROLE_PERMISSION',
        jsonb_build_object('module', target_module, 'action', target_action)
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- Revoke execution of privileged RPCs from PUBLIC/anon
REVOKE EXECUTE ON FUNCTION public.assign_user_role(UUID, public.app_role) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_review_seller_store(UUID, BOOLEAN, NUMERIC) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_review_kyc_document(UUID, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_review_product(UUID, BOOLEAN) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_adjust_seller_wallet(UUID, NUMERIC, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_toggle_seller_suspension(UUID, BOOLEAN, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.admin_toggle_payout_lock(UUID, BOOLEAN, TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.assign_role_permission(public.app_role, TEXT, TEXT) FROM PUBLIC, anon;

-- Grant execution of privileged RPCs to authenticated role (internal permissions checked inside functions)
GRANT EXECUTE ON FUNCTION public.assign_user_role(UUID, public.app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_seller_store(UUID, BOOLEAN, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_kyc_document(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_product(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_adjust_seller_wallet(UUID, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_toggle_seller_suspension(UUID, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_toggle_payout_lock(UUID, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.assign_role_permission(public.app_role, TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 6. MIGRATION COMPLETION NOTICE
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE 'Migration 20260806000000 (Phase 6 RBAC, Server Security & Immutable Audit Logs) completed successfully.';
END $$;
