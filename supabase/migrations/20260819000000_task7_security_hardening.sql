-- ============================================================================
-- Migration: 20260819000000_task7_security_hardening.sql
-- Description: Task 7 - Security Hardening, Input Constraints & Anti-Abuse Rate Limiter
-- Strict Compliance: SET search_path = '', RLS on all tables, Server Authoritative
-- ============================================================================

-- 1. Anti-Abuse Rate Limiting Table
CREATE TABLE IF NOT EXISTS public.rate_limit_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

ALTER TABLE public.rate_limit_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY rate_limit_events_admin_all ON public.rate_limit_events
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles ur
            WHERE ur.user_id = auth.uid()
            AND ur.role IN ('owner', 'superAdmin', 'fraudAnalyst')
        )
    );

CREATE INDEX IF NOT EXISTS idx_rate_limit_user_action 
    ON public.rate_limit_events(user_id, action_type, created_at DESC);

-- 2. Anti-Abuse Rate Limiter Enforcement Function (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.enforce_rate_limit(
    p_action TEXT,
    p_max_requests INT DEFAULT 10,
    p_window_seconds INT DEFAULT 60
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_uid UUID;
    v_recent_count INT;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Authentication required for rate limited operation' USING ERRCODE = '42501';
    END IF;

    -- Clean old logs periodically (> 1 hour old)
    DELETE FROM public.rate_limit_events 
    WHERE created_at < clock_timestamp() - INTERVAL '1 hour';

    -- Count occurrences within window
    SELECT COUNT(*) INTO v_recent_count
    FROM public.rate_limit_events
    WHERE user_id = v_uid 
      AND action_type = p_action
      AND created_at >= (clock_timestamp() - (p_window_seconds || ' seconds')::INTERVAL);

    IF v_recent_count >= p_max_requests THEN
        RAISE EXCEPTION 'Rate limit exceeded for action: %. Maximum % requests allowed per % seconds.',
            p_action, p_max_requests, p_window_seconds
            USING ERRCODE = 'P0001';
    END IF;

    -- Record event
    INSERT INTO public.rate_limit_events (user_id, action_type)
    VALUES (v_uid, p_action);

    RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_rate_limit(TEXT, INT, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.enforce_rate_limit(TEXT, INT, INT) FROM anon;
GRANT EXECUTE ON FUNCTION public.enforce_rate_limit(TEXT, INT, INT) TO authenticated;

-- 3. Input Validation Constraints on Core Tables
DO $$
BEGIN
    -- Support Tickets constraints
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'support_tickets') THEN
        ALTER TABLE public.support_tickets 
            DROP CONSTRAINT IF EXISTS chk_support_tickets_subject_len;
        ALTER TABLE public.support_tickets 
            ADD CONSTRAINT chk_support_tickets_subject_len 
            CHECK (length(trim(subject)) >= 3 AND length(subject) <= 255);

        ALTER TABLE public.support_tickets 
            DROP CONSTRAINT IF EXISTS chk_support_tickets_priority;
        ALTER TABLE public.support_tickets 
            ADD CONSTRAINT chk_support_tickets_priority 
            CHECK (priority IN ('Low', 'Medium', 'High', 'Urgent'));
    END IF;

    -- Product Reviews constraints
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'product_reviews') THEN
        ALTER TABLE public.product_reviews 
            DROP CONSTRAINT IF EXISTS chk_product_reviews_rating;
        ALTER TABLE public.product_reviews 
            ADD CONSTRAINT chk_product_reviews_rating 
            CHECK (rating >= 1 AND rating <= 5);

        ALTER TABLE public.product_reviews 
            DROP CONSTRAINT IF EXISTS chk_product_reviews_comment_len;
        ALTER TABLE public.product_reviews 
            ADD CONSTRAINT chk_product_reviews_comment_len 
            CHECK (comment IS NULL OR (length(trim(comment)) >= 2 AND length(comment) <= 2000));
    END IF;

    -- Vouchers Constraints
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vouchers') THEN
        ALTER TABLE public.vouchers 
            DROP CONSTRAINT IF EXISTS chk_vouchers_code_format;
        ALTER TABLE public.vouchers 
            ADD CONSTRAINT chk_vouchers_code_format 
            CHECK (code ~ '^[A-Z0-9_\-]{3,30}$');
            
        ALTER TABLE public.vouchers 
            DROP CONSTRAINT IF EXISTS chk_vouchers_value_positive;
        ALTER TABLE public.vouchers 
            ADD CONSTRAINT chk_vouchers_value_positive 
            CHECK (value > 0);
    END IF;
END $$;
