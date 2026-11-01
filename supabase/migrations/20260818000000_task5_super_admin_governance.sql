-- ============================================================================
-- APNA STORE — TASK 5: SUPER ADMIN GOVERNANCE, COMMISSION, TICKETS & CMS TABLES
-- Migration: 20260818000000_task5_super_admin_governance.sql
-- ============================================================================

-- 1. COMMISSION RULES TABLE
CREATE TABLE IF NOT EXISTS public.commission_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category_name TEXT NOT NULL UNIQUE,
    commission_rate NUMERIC(5,2) NOT NULL CHECK (commission_rate >= 0.0 AND commission_rate <= 100.0),
    min_order_amount NUMERIC(12,2) NOT NULL DEFAULT 0.0 CHECK (min_order_amount >= 0.0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES auth.users(id)
);

ALTER TABLE public.commission_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read on commission rules"
    ON public.commission_rules FOR SELECT
    TO anon, authenticated
    USING (TRUE);

CREATE POLICY "Allow admin write on commission rules"
    ON public.commission_rules FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles ur
            WHERE ur.user_id = auth.uid()
              AND ur.role IN ('super_admin', 'owner', 'admin')
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.user_roles ur
            WHERE ur.user_id = auth.uid()
              AND ur.role IN ('super_admin', 'owner', 'admin')
        )
    );

GRANT SELECT ON public.commission_rules TO anon, authenticated;
GRANT ALL ON public.commission_rules TO authenticated;

-- Seed default categories if not already present
INSERT INTO public.commission_rules (category_name, commission_rate, min_order_amount)
VALUES 
    ('Fashion & Apparel', 12.00, 0.00),
    ('Mobiles & Electronics', 5.00, 0.00),
    ('Groceries & Household', 3.50, 0.00),
    ('Home & Living', 8.00, 0.00),
    ('Health & Beauty', 10.00, 0.00),
    ('Automotive & Tools', 7.50, 0.00)
ON CONFLICT (category_name) DO NOTHING;

-- 2. SUPPORT TICKETS & MESSAGES TABLE
CREATE TABLE IF NOT EXISTS public.support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    user_email TEXT NOT NULL,
    subject TEXT NOT NULL,
    priority TEXT NOT NULL DEFAULT 'Medium' CHECK (priority IN ('Low', 'Medium', 'High', 'Urgent')),
    status TEXT NOT NULL DEFAULT 'Open' CHECK (status IN ('Open', 'In Progress', 'Resolved', 'Closed')),
    category TEXT NOT NULL DEFAULT 'General',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own support tickets"
    ON public.support_tickets FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.user_roles ur
            WHERE ur.user_id = auth.uid()
              AND ur.role IN ('super_admin', 'owner', 'admin')
        )
    );

CREATE POLICY "Users can insert own support tickets"
    ON public.support_tickets FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admins can update support tickets"
    ON public.support_tickets FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles ur
            WHERE ur.user_id = auth.uid()
              AND ur.role IN ('super_admin', 'owner', 'admin')
        )
    );

GRANT SELECT, INSERT ON public.support_tickets TO authenticated;
GRANT ALL ON public.support_tickets TO authenticated;

-- 3. CMS CONTENT & BANNERS TABLE
CREATE TABLE IF NOT EXISTS public.cms_banners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    subtitle TEXT NOT NULL DEFAULT '',
    target_route TEXT NOT NULL DEFAULT '/buyer/home',
    image_url TEXT NOT NULL DEFAULT '',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    display_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.cms_banners ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read active banners"
    ON public.cms_banners FOR SELECT
    TO anon, authenticated
    USING (is_active = TRUE OR EXISTS (
        SELECT 1 FROM public.user_roles ur
        WHERE ur.user_id = auth.uid()
          AND ur.role IN ('super_admin', 'owner', 'admin')
    ));

CREATE POLICY "Admins manage banners"
    ON public.cms_banners FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.user_roles ur
            WHERE ur.user_id = auth.uid()
              AND ur.role IN ('super_admin', 'owner', 'admin')
        )
    );

GRANT SELECT ON public.cms_banners TO anon, authenticated;
GRANT ALL ON public.cms_banners TO authenticated;

-- Seed default banner
INSERT INTO public.cms_banners (title, subtitle, target_route, image_url, is_active, display_order)
VALUES 
    ('Pakistan Mega Shopping Festival', 'Enjoy verified local sellers with fast doorstep delivery.', '/buyer/home', 'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=1200', TRUE, 1)
ON CONFLICT DO NOTHING;

-- 4. SERVER RPC: ADMIN UPDATE COMMISSION RULE
CREATE OR REPLACE FUNCTION public.admin_update_commission_rule(
    p_category_name TEXT,
    p_rate NUMERIC,
    p_min_order NUMERIC DEFAULT 0.0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_rule_id UUID;
BEGIN
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated admin request.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_admin_id
          AND role IN ('super_admin', 'owner', 'admin')
    ) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to update commission rule.';
    END IF;

    IF p_rate < 0.0 OR p_rate > 100.0 THEN
        RAISE EXCEPTION 'Commission rate must be between 0.0 and 100.0 percent.';
    END IF;

    INSERT INTO public.commission_rules (category_name, commission_rate, min_order_amount, updated_at, updated_by)
    VALUES (p_category_name, p_rate, p_min_order, NOW(), v_admin_id)
    ON CONFLICT (category_name) DO UPDATE
    SET commission_rate = EXCLUDED.commission_rate,
        min_order_amount = EXCLUDED.min_order_amount,
        updated_at = NOW(),
        updated_by = v_admin_id
    RETURNING id INTO v_rule_id;

    -- Audit Log Entry
    INSERT INTO public.admin_audit_logs (admin_user_id, action_type, target_entity, details)
    VALUES (
        v_admin_id,
        'COMMISSION_RULE_UPDATE',
        'Category: ' || p_category_name,
        'Updated commission rate to ' || p_rate::text || '% (Min order: Rs. ' || p_min_order::text || ')'
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'rule_id', v_rule_id,
        'category_name', p_category_name,
        'commission_rate', p_rate
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_update_commission_rule(TEXT, NUMERIC, NUMERIC) TO authenticated;

-- 5. SERVER RPC: ADMIN BROADCAST NOTIFICATION
CREATE OR REPLACE FUNCTION public.admin_broadcast_notification(
    p_title TEXT,
    p_body TEXT,
    p_target_role TEXT DEFAULT 'ALL'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_admin_id UUID := auth.uid();
    v_count INT := 0;
    v_user RECORD;
BEGIN
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Unauthenticated admin request.';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_admin_id
          AND role IN ('super_admin', 'owner', 'admin')
    ) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to broadcast notifications.';
    END IF;

    IF trim(p_title) = '' OR trim(p_body) = '' THEN
        RAISE EXCEPTION 'Notification title and body cannot be empty.';
    END IF;

    FOR v_user IN
        SELECT DISTINCT u.id
        FROM auth.users u
        LEFT JOIN public.user_roles ur ON ur.user_id = u.id
        WHERE (p_target_role = 'ALL')
           OR (p_target_role = 'BUYER' AND (ur.role IS NULL OR ur.role = 'buyer'))
           OR (p_target_role = 'SELLER' AND ur.role = 'seller')
    LOOP
        INSERT INTO public.notifications (user_id, type, title, message, reference_type, reference_id, idempotency_key)
        VALUES (
            v_user.id,
            'SYSTEM_ANNOUNCEMENT',
            p_title,
            p_body,
            'BROADCAST',
            v_admin_id::text,
            'NOTIF-BC-' || v_user.id::text || '-' || EXTRACT(EPOCH FROM NOW())::int::text
        )
        ON CONFLICT (idempotency_key) DO NOTHING;
        v_count := v_count + 1;
    END LOOP;

    RETURN jsonb_build_object('success', TRUE, 'recipients_count', v_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_broadcast_notification(TEXT, TEXT, TEXT) TO authenticated;
