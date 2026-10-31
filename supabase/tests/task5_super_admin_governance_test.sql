BEGIN;
SELECT plan(6);

-- 1. Table assertions
SELECT has_table('public', 'commission_rules', 'commission_rules table exists');
SELECT has_table('public', 'support_tickets', 'support_tickets table exists');
SELECT has_table('public', 'cms_banners', 'cms_banners table exists');

-- 2. Function assertions
SELECT has_function('public', 'admin_update_commission_rule', ARRAY['text', 'numeric', 'numeric'], 'admin_update_commission_rule RPC exists');
SELECT has_function('public', 'admin_broadcast_notification', ARRAY['text', 'text', 'text'], 'admin_broadcast_notification RPC exists');

-- 3. Row checks
SELECT ok(
    EXISTS (SELECT 1 FROM public.commission_rules WHERE category_name = 'Fashion & Apparel'),
    'Default commission rules seeded'
);

SELECT * FROM finish();
ROLLBACK;
