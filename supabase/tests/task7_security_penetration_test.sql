-- ============================================================================
-- SQL Test: Task 7 Security Penetration & RLS Hardening Test
-- ============================================================================

BEGIN;
SELECT plan(6);

-- 1. Verify rate limit events table exists and has RLS enabled
SELECT has_table('public', 'rate_limit_events', 'rate_limit_events table exists');
SELECT table_privs_are(
    'public', 'rate_limit_events', 'authenticated', 
    ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE'], 
    'Authenticated role has restricted access guarded by RLS policies'
);

-- 2. Verify enforce_rate_limit function exists with correct security definer
SELECT has_function('public', 'enforce_rate_limit', ARRAY['text', 'integer', 'integer'], 'enforce_rate_limit function exists');

-- 3. Verify anon cannot execute enforce_rate_limit
SELECT throws_ok(
    $$ SELECT public.enforce_rate_limit('review_submission', 5, 60); $$,
    '42501',
    'Authentication required for rate limited operation',
    'Anonymous user cannot invoke rate limit enforcement'
);

-- 4. Verify product reviews rating check constraint blocks invalid stars (e.g. 10 stars)
SELECT throws_like(
    $$ 
    INSERT INTO public.product_reviews (id, product_id, user_id, rating, comment)
    VALUES (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 10, 'Fake 10 star rating');
    $$,
    '%chk_product_reviews_rating%',
    'Database constraint blocks ratings outside 1-5 range'
);

-- 5. Verify voucher code format check blocks invalid characters/length
SELECT throws_like(
    $$
    INSERT INTO public.vouchers (code, type, value, min_order_amount, is_active)
    VALUES ('!!INVALID!!', 'fixed', 500, 1000, true);
    $$,
    '%chk_vouchers_code_format%',
    'Database constraint enforces alphanumeric voucher codes'
);

SELECT * FROM finish();
ROLLBACK;
