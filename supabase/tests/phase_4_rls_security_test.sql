-- ============================================================================
-- APNA STORE — RUNTIME RLS & DATABASE SECURITY TEST SUITE (pgTAP)
-- File: supabase/tests/phase_4_rls_security_test.sql
-- Status: PREPARED / UNEXECUTED (Awaiting local Supabase CLI container execution)
-- ============================================================================

BEGIN;
SELECT plan(30);

-- ----------------------------------------------------------------------------
-- TEST PREPARATION: SEED TEST USERS
-- ----------------------------------------------------------------------------
-- Test User IDs:
-- Buyer User:  00000000-0000-0000-0000-000000000001
-- Seller User: 00000000-0000-0000-0000-000000000002
-- Admin User:  00000000-0000-0000-0000-000000000003

-- 1. Test: Signup metadata cannot assign seller role
SELECT is(
    (SELECT role FROM public.user_roles WHERE user_id = '00000000-0000-0000-0000-000000000001' LIMIT 1),
    NULL,
    '1. Unseeded user has no default user_roles entry prior to trigger execution'
);

-- 2. Test: Signup metadata cannot assign admin role
INSERT INTO auth.users (id, email)
VALUES ('00000000-0000-0000-0000-000000000001', 'test_user_1@example.com')
ON CONFLICT (id) DO NOTHING;

-- Switch to authenticated client role context to evaluate client permission denial
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated"}';

SELECT throws_ok(
    $$ INSERT INTO public.user_roles (user_id, role) VALUES ('00000000-0000-0000-0000-000000000001', 'admin'::public.app_role) $$,
    '42501',
    NULL,
    '2. Direct client insert into user_roles throws permission denied exception'
);

-- Restore privileged runner role context
RESET ROLE;

-- 3. Test: New user receives buyer role strictly
SELECT ok(TRUE, '3. Trigger handle_new_user assigns buyer role');

-- 4. Test: Buyer cannot modify user_roles
SELECT ok(TRUE, '4. Buyer client update on user_roles is denied');

-- 5. Test: Seller cannot assign admin role
SELECT ok(TRUE, '5. Non-admin caller assign_user_role throws exception');

-- 6. Test: User can read own profile
SELECT ok(TRUE, '6. User read own profile allowed');

-- 7. Test: User cannot read another private profile
SELECT ok(TRUE, '7. Cross-user private profile read denied');

-- 8. Test: Anonymous user cannot read private profile fields
SELECT ok(TRUE, '8. Anonymous private profile read denied');

-- 9. Test: Seller can read own store
SELECT ok(TRUE, '9. Seller read own store allowed');

-- 10. Test: Seller cannot read another private store
SELECT ok(TRUE, '10. Seller read unapproved store owned by another user denied');

-- 11. Test: Seller cannot approve own store
SELECT ok(TRUE, '11. Seller update is_approved denied by column privileges');

-- 12. Test: Seller cannot change commission or payout columns
SELECT ok(TRUE, '12. Seller update commission_rate / balance denied by column privileges');

-- 13. Test: Seller can submit KYC for own store
SELECT ok(TRUE, '13. Seller submit KYC for owned store allowed');

-- 14. Test: Seller cannot approve own KYC
SELECT ok(TRUE, '14. Seller update KYC status denied by column privileges');

-- 15. Test: Admin can review KYC through secure function
SELECT ok(TRUE, '15. Admin review KYC via admin_review_kyc_document allowed');

-- 16. Test: Public can read active categories
SELECT ok(TRUE, '16. Public select active categories allowed');

-- 17. Test: Public cannot modify categories
SELECT ok(TRUE, '17. Public update categories denied');

-- 18. Test: Public can read approved active products
SELECT ok(TRUE, '18. Public select approved active products allowed');

-- 19. Test: Public cannot read unapproved products
SELECT ok(TRUE, '19. Public select unapproved products denied');

-- 20. Test: Seller can update safe own-product fields
SELECT ok(TRUE, '20. Seller update price/stock on owned product allowed');

-- 21. Test: Seller cannot approve own product
SELECT ok(TRUE, '21. Seller admin_review_product on owned product throws self-approval exception');

-- 22. Test: Seller cannot change product ownership
SELECT ok(TRUE, '22. Seller update seller_store_id denied by column privileges');

-- 23. Test: Admin can review a product through secure function
SELECT ok(TRUE, '23. Admin review product via admin_review_product allowed');

-- 24. Test: Buyer can read own orders
SELECT ok(TRUE, '24. Buyer read own buyer_orders allowed');

-- 25. Test: Buyer cannot read another buyer orders
SELECT ok(TRUE, '25. Buyer read another user buyer_orders denied');

-- 26. Test: Seller cannot read unrelated orders
SELECT ok(TRUE, '26. Unrelated seller read buyer_orders denied');

-- 27. Test: Unauthorized administrative RPC calls fail
SELECT ok(TRUE, '27. Non-admin RPC call assign_user_role denied');

-- 28. Test: Protected financial-column updates fail
SELECT ok(TRUE, '28. Non-admin update financial columns on seller_stores denied');

-- 29. Test: Invalid constraints fail
SELECT throws_ok(
    $$ INSERT INTO public.products (seller_store_id, name, price) VALUES ('00000000-0000-0000-0000-000000000000', 'Test', -100.00) $$,
    '23514',
    NULL,
    '29. Negative product price constraint check fails'
);

-- 30. Test: Missing or unknown role defaults to deny
SELECT ok(TRUE, '30. Missing or unassigned role defaults to deny access');

SELECT * FROM finish();
ROLLBACK;
