-- ============================================================================
-- APNA STORE MIGRATION: 20260816000000_task2_platform_integrations_no_secrets.sql
-- Purpose: Task 2 - Platform integrations architecture with ZERO client-side secrets
-- Authoritative: R1 Database Security (SET search_path = ''), R5 Safe Migrations
-- ============================================================================

-- 1. Create platform_integrations table (STRICTLY NO SECRET COLUMNS)
CREATE TABLE IF NOT EXISTS public.platform_integrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_key TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('payment', 'shipping', 'sms', 'storage', 'tax', 'other')),
    is_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    status TEXT NOT NULL DEFAULT 'not_configured' CHECK (status IN ('not_configured', 'configured', 'error')),
    last_checked_at TIMESTAMPTZ,
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Enable Row-Level Security
ALTER TABLE public.platform_integrations ENABLE ROW LEVEL SECURITY;

-- 3. Explicit Policies:
-- Only authenticated administrators (checked via public.is_admin()) can read integration status
CREATE POLICY "Admins can view platform integrations"
    ON public.platform_integrations
    FOR SELECT
    TO authenticated
    USING (public.is_admin());

-- Deny direct client INSERT/UPDATE/DELETE
REVOKE INSERT, UPDATE, DELETE ON public.platform_integrations FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.platform_integrations TO authenticated;

-- 4. RPC to toggle integration enabled state (server-authoritative with audit logging)
CREATE OR REPLACE FUNCTION public.admin_set_integration_enabled(
    p_provider_key TEXT,
    p_enabled BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_admin_id UUID;
    v_admin_role public.app_role;
    v_integration RECORD;
BEGIN
    -- Derive admin identity
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Access denied: Requires administrator privilege.' USING ERRCODE = '42501';
    END IF;

    -- Look up provider
    SELECT * INTO v_integration
    FROM public.platform_integrations
    WHERE provider_key = p_provider_key;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Integration provider % not found.', p_provider_key USING ERRCODE = 'P0002';
    END IF;

    -- Update state
    UPDATE public.platform_integrations
    SET 
        is_enabled = p_enabled,
        updated_by = v_admin_id,
        updated_at = NOW()
    WHERE provider_key = p_provider_key;

    -- Write to audit log
    INSERT INTO public.admin_audit_logs (
        admin_id,
        action,
        target_entity,
        target_id,
        details
    ) VALUES (
        v_admin_id,
        CASE WHEN p_enabled THEN 'INTEGRATION_ENABLED' ELSE 'INTEGRATION_DISABLED' END,
        'platform_integrations',
        v_integration.id::text,
        jsonb_build_object(
            'provider_key', p_provider_key,
            'is_enabled', p_enabled,
            'category', v_integration.category
        )
    );

    RETURN jsonb_build_object(
        'success', true,
        'provider_key', p_provider_key,
        'is_enabled', p_enabled
    );
END;
$$;

-- Security grants on RPC
REVOKE ALL ON FUNCTION public.admin_set_integration_enabled(TEXT, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_set_integration_enabled(TEXT, BOOLEAN) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_set_integration_enabled(TEXT, BOOLEAN) TO authenticated;

-- 5. Seed default integrations
INSERT INTO public.platform_integrations (provider_key, display_name, category, is_enabled, status)
VALUES
    ('jazzcash', 'JazzCash Mobile Gateway', 'payment', FALSE, 'not_configured'),
    ('easypaisa', 'Easypaisa Mobile Wallet', 'payment', FALSE, 'not_configured'),
    ('onelink', '1Link Inter-Bank / PayPak', 'payment', FALSE, 'not_configured'),
    ('stripe_card', 'Stripe Card Gateway (Visa/MasterCard)', 'payment', FALSE, 'not_configured'),
    ('tcs', 'TCS Express Logistics', 'shipping', FALSE, 'not_configured'),
    ('leopard', 'Leopard Courier Logistics', 'shipping', FALSE, 'not_configured'),
    ('trax', 'Trax Logistics Network', 'shipping', FALSE, 'not_configured'),
    ('callcourier', 'Call Courier Services', 'shipping', FALSE, 'not_configured'),
    ('sms_gateway', 'Transactional SMS Gateway', 'sms', FALSE, 'not_configured'),
    ('s3_storage', 'External S3 Cloud Storage', 'storage', FALSE, 'not_configured'),
    ('fbr_pos', 'FBR Digital Invoicing & POS', 'tax', FALSE, 'not_configured')
ON CONFLICT (provider_key) DO NOTHING;
