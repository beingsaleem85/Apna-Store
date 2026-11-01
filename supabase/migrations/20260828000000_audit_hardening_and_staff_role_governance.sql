-- Migration: 20260828000000_audit_hardening_and_staff_role_governance.sql
-- Description: Audit logs security & immutability, admin_assign_staff_role RPC, and strict staff_role separation in has_permission

-- ----------------------------------------------------------------------------
-- 1. SAFE AUDIT LOG CONSOLIDATION & IMMUTABILITY
-- ----------------------------------------------------------------------------

-- Copy any remaining rows from admin_audit_logs if it exists as a table before converting
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

-- Drop and recreate the compatibility view admin_audit_logs WITH (security_invoker = true)
DROP VIEW IF EXISTS public.admin_audit_logs CASCADE;

CREATE OR REPLACE VIEW public.admin_audit_logs
WITH (security_invoker = true) AS
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

-- Re-create INSTEAD OF INSERT trigger on the view
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

-- Enforce explicit grants on public.audit_logs and admin_audit_logs view
REVOKE ALL ON public.audit_logs FROM PUBLIC, anon;
REVOKE INSERT, UPDATE, DELETE ON public.audit_logs FROM authenticated;
GRANT SELECT ON public.audit_logs TO authenticated;

REVOKE ALL ON public.admin_audit_logs FROM PUBLIC, anon;
REVOKE UPDATE, DELETE ON public.admin_audit_logs FROM authenticated;
GRANT SELECT, INSERT ON public.admin_audit_logs TO authenticated;

-- Ensure audit_logs RLS is enabled and strictly restricted
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view audit logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Audit log view restricted to audit permission" ON public.audit_logs;

CREATE POLICY "Audit log view restricted to audit permission" ON public.audit_logs
    FOR SELECT TO authenticated
    USING (
        public.has_permission('audit', 'view')
    );

-- Tamper prevention: Block ANY UPDATE or DELETE on audit_logs
CREATE OR REPLACE FUNCTION public.prevent_audit_log_tampering()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    RAISE EXCEPTION 'Audit log records are immutable and cannot be modified or deleted.'
        USING ERRCODE = '42501';
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_audit_log_tampering ON public.audit_logs;
CREATE TRIGGER trg_prevent_audit_log_tampering
    BEFORE UPDATE OR DELETE ON public.audit_logs
    FOR EACH ROW EXECUTE FUNCTION public.prevent_audit_log_tampering();

-- Seed audit:view permission for auditor in staff_role_permissions if not present
INSERT INTO public.staff_role_permissions (staff_role, module, action)
VALUES ('auditor', 'audit', 'view')
ON CONFLICT (staff_role, module, action) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. STAFF ROLE ASSIGNMENT RPC: admin_assign_staff_role
-- ----------------------------------------------------------------------------

-- Ensure user_roles has no direct INSERT/UPDATE/DELETE grants for authenticated users
REVOKE INSERT, UPDATE, DELETE ON public.user_roles FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.user_roles TO authenticated;

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
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.' USING ERRCODE = '42501';
    END IF;

    -- 1. Check Caller Privilege: Only owner or superAdmin/super_admin can assign staff roles
    IF NOT EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (
              role IN ('owner'::public.app_role, 'super_admin'::public.app_role)
              OR staff_role IN ('owner'::public.admin_staff_role, 'superAdmin'::public.admin_staff_role)
          )
    ) THEN
        RAISE EXCEPTION 'Access denied: Only Owner or Super Admin can assign staff roles.'
            USING ERRCODE = '42501';
    END IF;

    -- 2. Self-assignment prevention
    IF p_user_id = v_caller_id THEN
        RAISE EXCEPTION 'Self-assignment of staff roles is prohibited.' USING ERRCODE = '42501';
    END IF;

    -- 3. Owner role assignment prevention
    IF p_staff_role = 'owner'::public.admin_staff_role THEN
        RAISE EXCEPTION 'Assignment of the Owner role is prohibited.' USING ERRCODE = '42501';
    END IF;

    -- 4. Target user validation
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'Target user not found.' USING ERRCODE = 'P0002';
    END IF;

    -- 5. Upsert role into user_roles
    INSERT INTO public.user_roles (user_id, role, staff_role)
    VALUES (p_user_id, 'admin'::public.app_role, p_staff_role)
    ON CONFLICT (user_id, role)
    DO UPDATE SET staff_role = EXCLUDED.staff_role, granted_at = NOW();

    -- 6. Record Audit Log
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

REVOKE ALL ON FUNCTION public.admin_assign_staff_role(UUID, public.admin_staff_role) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_assign_staff_role(UUID, public.admin_staff_role) TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. STRICT has_permission REFACTORING & LEGACY ISOLATION
-- ----------------------------------------------------------------------------

-- Remove the legacy ('admin', 'returns', 'review') permission row to prevent any leakage
DELETE FROM public.role_permissions
WHERE role = 'admin'::public.app_role
  AND module = 'returns'
  AND action = 'review';

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
    -- If user has a staff_role, evaluate ONLY through staff_role_permissions.
    SELECT staff_role INTO v_staff_role
    FROM public.user_roles
    WHERE user_id = v_uid
      AND staff_role IS NOT NULL
    ORDER BY granted_at DESC
    LIMIT 1;

    IF v_staff_role IS NOT NULL THEN
        -- Evaluate explicit rows in staff_role_permissions (NO shortcuts)
        IF EXISTS (
            SELECT 1 FROM public.staff_role_permissions srp
            WHERE srp.staff_role = v_staff_role
              AND (srp.module = '*' OR srp.module = required_module)
              AND (srp.action = '*' OR srp.action = required_action)
        ) THEN
            RETURN TRUE;
        END IF;

        -- Staff role users are evaluated EXCLUSIVELY through staff_role_permissions.
        -- Never fall through to legacy role_permissions.
        RETURN FALSE;
    END IF;

    -- 3. Legacy role_permissions check: ONLY for users without a staff_role
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
