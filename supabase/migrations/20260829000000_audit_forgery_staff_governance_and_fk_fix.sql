-- Migration: 20260829000000_audit_forgery_staff_governance_and_fk_fix.sql
-- Description: Audit forgery protection, strict legacy admin deny, granular role assign/revoke rules, and FK safety

-- ----------------------------------------------------------------------------
-- 1. AUDIT FORGERY PROTECTION
-- ----------------------------------------------------------------------------

-- Revoke INSERT on public.admin_audit_logs (view) and public.audit_logs (table)
REVOKE INSERT, UPDATE, DELETE ON public.admin_audit_logs FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.audit_logs FROM PUBLIC, anon, authenticated;

GRANT SELECT ON public.admin_audit_logs TO authenticated;
GRANT SELECT ON public.audit_logs TO authenticated;

-- Restrict the INSTEAD OF trigger on admin_audit_logs to ignore client-supplied actor ID
CREATE OR REPLACE FUNCTION public.trg_admin_audit_logs_compat_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required for audit logging.' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.audit_logs (
        actor_user_id,
        actor_role,
        action,
        target_type,
        target_id,
        metadata,
        details
    ) VALUES (
        auth.uid(),
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

-- ----------------------------------------------------------------------------
-- 2. AUDIT LOG FOREIGN KEY INTEGRITY
-- ----------------------------------------------------------------------------
-- Ensure actor_user_id explicitly uses ON DELETE NO ACTION to prevent mutation on user deletion
ALTER TABLE public.audit_logs
    DROP CONSTRAINT IF EXISTS audit_logs_actor_user_id_fkey;

ALTER TABLE public.audit_logs
    ADD CONSTRAINT audit_logs_actor_user_id_fkey
    FOREIGN KEY (actor_user_id) REFERENCES auth.users(id) ON DELETE NO ACTION;

-- ----------------------------------------------------------------------------
-- 3. LEGACY ADMIN DEFAULT DENY & NOTICE UNASSIGNED
-- ----------------------------------------------------------------------------
-- Notice unassigned legacy admin users during migration
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT ur.user_id, u.email
        FROM public.user_roles ur
        LEFT JOIN auth.users u ON u.id = ur.user_id
        WHERE ur.role = 'admin'::public.app_role
          AND ur.staff_role IS NULL
    ) LOOP
        RAISE NOTICE 'UNASSIGNED_LEGACY_ADMIN: user_id=%, email=%', r.user_id, r.email;
    END LOOP;
END $$;

-- Update has_permission: Users with role = 'admin' but NO staff_role get default FALSE
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

    -- 1. Owner / Super Admin bypass from user_roles
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

    -- 2. Staff Role Evaluation:
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
              AND (srp.module = '*' OR srp.module = required_module)
              AND (srp.action = '*' OR srp.action = required_action)
        ) THEN
            RETURN TRUE;
        END IF;

        -- Staff role users are evaluated EXCLUSIVELY through staff_role_permissions
        RETURN FALSE;
    END IF;

    -- 3. Legacy check:
    -- If user has role = 'admin' but NO staff_role, default DENY (RETURN FALSE)
    v_app_role := public.get_current_user_role();
    IF v_app_role = 'admin'::public.app_role THEN
        RETURN FALSE;
    END IF;

    -- Non-admin roles (buyer, seller) evaluate through legacy role_permissions
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
-- 4. GRANULAR STAFF ROLE ASSIGNMENT & REVOCATION
-- ----------------------------------------------------------------------------

-- admin_assign_staff_role: Only owner can assign superAdmin; superAdmin can assign other 10
CREATE OR REPLACE FUNCTION public.admin_assign_staff_role(
    p_user_id UUID,
    p_staff_role public.admin_staff_role
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_is_owner BOOLEAN;
    v_is_super_admin BOOLEAN;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.' USING ERRCODE = '42501';
    END IF;

    -- Check caller authority
    v_is_owner := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (role = 'owner'::public.app_role OR staff_role = 'owner'::public.admin_staff_role)
    );

    v_is_super_admin := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (role = 'super_admin'::public.app_role OR staff_role = 'superAdmin'::public.admin_staff_role)
    );

    IF NOT (v_is_owner OR v_is_super_admin) THEN
        RAISE EXCEPTION 'Access denied: Only Owner or Super Admin can assign staff roles.'
            USING ERRCODE = '42501';
    END IF;

    -- Self-assignment prevention
    IF p_user_id = v_caller_id THEN
        RAISE EXCEPTION 'Self-assignment of staff roles is prohibited.' USING ERRCODE = '42501';
    END IF;

    -- Owner assignment is prohibited
    IF p_staff_role = 'owner'::public.admin_staff_role THEN
        RAISE EXCEPTION 'Assignment of the Owner role is prohibited.' USING ERRCODE = '42501';
    END IF;

    -- Only Owner may assign superAdmin
    IF p_staff_role = 'superAdmin'::public.admin_staff_role AND NOT v_is_owner THEN
        RAISE EXCEPTION 'Access denied: Only Owner can assign the superAdmin role.'
            USING ERRCODE = '42501';
    END IF;

    -- Target user validation
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'Target user not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Upsert role into user_roles
    INSERT INTO public.user_roles (user_id, role, staff_role)
    VALUES (p_user_id, 'admin'::public.app_role, p_staff_role)
    ON CONFLICT (user_id, role)
    DO UPDATE SET staff_role = EXCLUDED.staff_role, granted_at = NOW();

    -- Record Audit Log
    v_audit_id := public.internal_record_audit_log(
        'user_role',
        p_user_id::TEXT,
        'STAFF_ROLE_ASSIGNED',
        jsonb_build_object(
            'assigned_staff_role', p_staff_role::TEXT,
            'assigned_by', v_caller_id
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'user_id', p_user_id,
        'staff_role', p_staff_role,
        'audit_log_id', v_audit_id
    );
END;
$$;

-- admin_revoke_staff_role: Only owner can revoke superAdmin; superAdmin can revoke other 10
CREATE OR REPLACE FUNCTION public.admin_revoke_staff_role(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_is_owner BOOLEAN;
    v_is_super_admin BOOLEAN;
    v_target_staff_role public.admin_staff_role;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.' USING ERRCODE = '42501';
    END IF;

    -- Self-revocation prevention
    IF p_user_id = v_caller_id THEN
        RAISE EXCEPTION 'Self-revocation of staff roles is prohibited.' USING ERRCODE = '42501';
    END IF;

    -- Caller authority
    v_is_owner := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (role = 'owner'::public.app_role OR staff_role = 'owner'::public.admin_staff_role)
    );

    v_is_super_admin := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (role = 'super_admin'::public.app_role OR staff_role = 'superAdmin'::public.admin_staff_role)
    );

    IF NOT (v_is_owner OR v_is_super_admin) THEN
        RAISE EXCEPTION 'Access denied: Only Owner or Super Admin can revoke staff roles.'
            USING ERRCODE = '42501';
    END IF;

    -- Target role check
    SELECT staff_role INTO v_target_staff_role
    FROM public.user_roles
    WHERE user_id = p_user_id AND staff_role IS NOT NULL
    LIMIT 1;

    IF v_target_staff_role IS NULL THEN
        RAISE EXCEPTION 'Target user does not have an active staff role.' USING ERRCODE = 'P0002';
    END IF;

    -- Only Owner can revoke a superAdmin role
    IF v_target_staff_role = 'superAdmin'::public.admin_staff_role AND NOT v_is_owner THEN
        RAISE EXCEPTION 'Access denied: Only Owner can revoke the superAdmin role.'
            USING ERRCODE = '42501';
    END IF;

    -- Revoke staff_role
    UPDATE public.user_roles
    SET staff_role = NULL, granted_at = NOW()
    WHERE user_id = p_user_id AND role = 'admin'::public.app_role;

    -- Record Audit Log
    v_audit_id := public.internal_record_audit_log(
        'user_role',
        p_user_id::TEXT,
        'STAFF_ROLE_REVOKED',
        jsonb_build_object(
            'revoked_staff_role', v_target_staff_role::TEXT,
            'revoked_by', v_caller_id
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'user_id', p_user_id,
        'revoked_staff_role', v_target_staff_role,
        'audit_log_id', v_audit_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_revoke_staff_role(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_revoke_staff_role(UUID) TO authenticated;
