-- ============================================================================
-- APNA STORE — PHASE 6: RUNTIME RBAC & IMMUTABLE AUDIT LOG SECURITY TEST SUITE
-- File: supabase/tests/phase_6_rbac_security_test.sql
-- Description: Verifies runtime server-side RBAC enforcement, RPC authorization,
--              column-level write protections, and audit log immutability via pgTAP.
-- ============================================================================

BEGIN;
SELECT plan(15);

-- ----------------------------------------------------------------------------
-- SEED TEST USERS FOR PHASE 6 SECURITY ASSERTIONS
-- ----------------------------------------------------------------------------
-- User 1: Buyer  (00000000-0000-0000-0000-000000000001)
-- User 2: Seller (00000000-0000-0000-0000-000000000002)
-- User 3: Admin  (00000000-0000-0000-0000-000000000003)

INSERT INTO auth.users (id, email) VALUES
    ('00000000-0000-0000-0000-000000000001', 'buyer_phase6@example.com'),
    ('00000000-0000-0000-0000-000000000002', 'seller_phase6@example.com'),
    ('00000000-0000-0000-0000-000000000003', 'admin_phase6@example.com')
ON CONFLICT (id) DO NOTHING;

-- Seed user roles with explicit timestamps to ensure latest granted role
INSERT INTO public.user_roles (user_id, role, granted_at) VALUES
    ('00000000-0000-0000-0000-000000000001', 'buyer'::public.app_role, NOW()),
    ('00000000-0000-0000-0000-000000000002', 'seller'::public.app_role, NOW() + INTERVAL '1 second'),
    ('00000000-0000-0000-0000-000000000003', 'super_admin'::public.app_role, NOW() + INTERVAL '2 seconds')
ON CONFLICT (user_id, role) DO UPDATE SET granted_at = EXCLUDED.granted_at;

-- Seed Seller Store & KYC Document
INSERT INTO public.seller_stores (id, owner_id, shop_name, shop_slug) VALUES
    ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000002', 'Phase 6 Test Shop', 'phase-6-test-shop')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.seller_kyc_documents (id, seller_store_id, document_type, document_url, cnic_number, submitted_by) VALUES
    ('22222222-2222-2222-2222-222222222222', '11111111-1111-1111-1111-111111111111', 'CNIC', 'https://example.com/cnic.jpg', '12345-6789012-3', '00000000-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;

-- Seed Product
INSERT INTO public.products (id, seller_store_id, name, price) VALUES
    ('33333333-3333-3333-3333-333333333333', '11111111-1111-1111-1111-111111111111', 'Phase 6 Leather Wallet', 1500.00)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 1. TEST: Buyer cannot read private seller KYC documents
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000001", "role": "authenticated"}';

SELECT is(
    (SELECT COUNT(*)::INT FROM public.seller_kyc_documents WHERE seller_store_id = '11111111-1111-1111-1111-111111111111'),
    0,
    '1. Buyer user cannot read private seller KYC documents'
);

-- ----------------------------------------------------------------------------
-- 2. TEST: Buyer cannot modify product approval status via direct SQL write
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ UPDATE public.products SET approval_status = 'Approved' WHERE id = '33333333-3333-3333-3333-333333333333' $$,
    '42501',
    NULL,
    '2. Direct client update on product approval_status is denied'
);

-- ----------------------------------------------------------------------------
-- 3. TEST: Buyer cannot call admin_adjust_seller_wallet RPC
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ SELECT public.admin_adjust_seller_wallet('11111111-1111-1111-1111-111111111111', 5000.00, 'Malicious credit attempt') $$,
    'P0001',
    NULL,
    '3. Non-admin buyer calling admin_adjust_seller_wallet throws access denied exception'
);

-- ----------------------------------------------------------------------------
-- 4. TEST: Seller cannot self-approve store via direct SQL write
-- ----------------------------------------------------------------------------
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000002", "role": "authenticated"}';

SELECT throws_ok(
    $$ UPDATE public.seller_stores SET is_approved = TRUE WHERE id = '11111111-1111-1111-1111-111111111111' $$,
    '42501',
    NULL,
    '4. Seller direct update on is_approved is denied by column privileges'
);

-- ----------------------------------------------------------------------------
-- 5. TEST: Seller cannot change commission_rate, balance, or payout_locked
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ UPDATE public.seller_stores SET commission_rate = 0.00, balance = 99999.00, payout_locked = FALSE WHERE id = '11111111-1111-1111-1111-111111111111' $$,
    '42501',
    NULL,
    '5. Seller direct update on financial/governance columns is denied by column privileges'
);

-- ----------------------------------------------------------------------------
-- 6. TEST: Seller cannot self-approve product via admin_review_product
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ SELECT public.admin_review_product('33333333-3333-3333-3333-333333333333', TRUE) $$,
    'P0001',
    NULL,
    '6. Seller calling admin_review_product on owned product throws self-approval exception'
);

-- ----------------------------------------------------------------------------
-- 7. TEST: Seller cannot insert directly into audit_logs
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ INSERT INTO public.audit_logs (actor_user_id, actor_role, action, target_type, target_id) VALUES ('00000000-0000-0000-0000-000000000002', 'seller'::public.app_role, 'FAKE_ACTION', 'seller_stores', '11111111-1111-1111-1111-111111111111') $$,
    '42501',
    NULL,
    '7. Direct client insert into audit_logs is denied by column privileges'
);

-- ----------------------------------------------------------------------------
-- 8. TEST: Seller cannot assign permissions via assign_role_permission
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ SELECT public.assign_role_permission('seller'::public.app_role, 'finance', 'adjust') $$,
    'P0001',
    NULL,
    '8. Non-owner seller calling assign_role_permission throws access denied exception'
);

-- ----------------------------------------------------------------------------
-- 9. TEST: Admin with permission can review product and create audit log
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000003", "role": "authenticated"}';

SELECT ok(
    public.admin_review_product('33333333-3333-3333-3333-333333333333', TRUE),
    '9. Admin review product via admin_review_product succeeds'
);

SELECT is(
    (SELECT approval_status FROM public.products WHERE id = '33333333-3333-3333-3333-333333333333'),
    'Approved',
    '10. Product approval status updated to Approved'
);

-- ----------------------------------------------------------------------------
-- 11. TEST: Audit log entry automatically created for privileged action
-- ----------------------------------------------------------------------------
SELECT is(
    (SELECT COUNT(*)::INT FROM public.audit_logs WHERE action = 'REVIEW_PRODUCT' AND target_id = '33333333-3333-3333-3333-333333333333'),
    1,
    '11. Immutable audit log automatically generated for REVIEW_PRODUCT mutation'
);

-- ----------------------------------------------------------------------------
-- 12. TEST: Admin cannot UPDATE audit_logs (Permission denied / Tampering protection)
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000003", "role": "authenticated"}';

SELECT throws_ok(
    $$ UPDATE public.audit_logs SET action = 'ALTERED_ACTION' WHERE target_id = '33333333-3333-3333-3333-333333333333' $$,
    '42501',
    NULL,
    '12. Direct client UPDATE attempt on audit_logs is denied by table privileges'
);

-- ----------------------------------------------------------------------------
-- 13. TEST: Admin cannot DELETE audit_logs (Permission denied / Tampering protection)
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ DELETE FROM public.audit_logs WHERE target_id = '33333333-3333-3333-3333-333333333333' $$,
    '42501',
    NULL,
    '13. Direct client DELETE attempt on audit_logs is denied by table privileges'
);

-- ----------------------------------------------------------------------------
-- 14. TEST: Admin wallet adjustment RPC succeeds and logs audit event
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000003", "role": "authenticated"}';

SELECT ok(
    (public.admin_adjust_seller_wallet('11111111-1111-1111-1111-111111111111'::UUID, 2500.00, 'P2P Settlement Bonus'))->>'success' = 'true',
    '14. Admin adjust seller wallet via admin_adjust_seller_wallet succeeds'
);

-- ----------------------------------------------------------------------------
-- 15. TEST: Audit log created for wallet adjustment
-- ----------------------------------------------------------------------------
SELECT is(
    (SELECT COUNT(*)::INT FROM public.audit_logs WHERE action = 'ADJUST_SELLER_WALLET' AND target_id = '11111111-1111-1111-1111-111111111111'),
    1,
    '15. Immutable audit log automatically generated for ADJUST_SELLER_WALLET mutation'
);

SELECT * FROM finish();
ROLLBACK;
