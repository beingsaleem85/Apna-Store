-- ============================================================================
-- PGTAP TEST SUITE: PHASE 7 STORAGE SECURITY, CANONICAL KYC & SELLER LIFECYCLE TESTS
-- File: supabase/tests/phase_7_storage_security_test.sql
-- ============================================================================

BEGIN;

SELECT plan(25);

-- ----------------------------------------------------------------------------
-- SETUP: Seed Test Users & Storage Objects
-- ----------------------------------------------------------------------------

-- Seed auth users
INSERT INTO auth.users (id, email) VALUES
    ('77777777-7777-7777-7777-777777770001', 'buyer_p7@example.com'),
    ('77777777-7777-7777-7777-777777770002', 'seller_p7@example.com'),
    ('77777777-7777-7777-7777-777777770003', 'admin_p7@example.com'),
    ('77777777-7777-7777-7777-777777770004', 'other_seller_p7@example.com')
ON CONFLICT (id) DO NOTHING;

-- Seed user roles with explicit timestamps
INSERT INTO public.user_roles (user_id, role, granted_at) VALUES
    ('77777777-7777-7777-7777-777777770001', 'buyer'::public.app_role, NOW()),
    ('77777777-7777-7777-7777-777777770002', 'buyer'::public.app_role, NOW() + INTERVAL '1 second'),
    ('77777777-7777-7777-7777-777777770003', 'super_admin'::public.app_role, NOW() + INTERVAL '2 seconds'),
    ('77777777-7777-7777-7777-777777770004', 'buyer'::public.app_role, NOW() + INTERVAL '3 seconds')
ON CONFLICT (user_id, role) DO UPDATE SET granted_at = EXCLUDED.granted_at;

-- Seed Seller Store
INSERT INTO public.seller_stores (id, owner_id, shop_name, shop_slug) VALUES
    ('99999999-9999-9999-9999-999999990002', '77777777-7777-7777-7777-777777770002', 'P7 Test Store', 'p7-test-store')
ON CONFLICT (id) DO NOTHING;

-- Seed dummy object in storage.objects
INSERT INTO storage.objects (id, bucket_id, name, owner, created_at, updated_at) VALUES
    ('88888888-8888-8888-8888-888888880001', 'kyc-documents', '77777777-7777-7777-7777-777777770002/cnic_front.png', '77777777-7777-7777-7777-777777770002', NOW(), NOW()),
    ('88888888-8888-8888-8888-888888880002', 'seller-store-media', '77777777-7777-7777-7777-777777770002/logo.png', '77777777-7777-7777-7777-777777770002', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 1. TEST: Anonymous user cannot read private KYC document storage object
-- ----------------------------------------------------------------------------
SET LOCAL ROLE anon;

SELECT is(
    (SELECT COUNT(*)::INT FROM storage.objects WHERE bucket_id = 'kyc-documents' AND id = '88888888-8888-8888-8888-888888880001'),
    0,
    '1. Anonymous read on private kyc-documents bucket is denied by RLS'
);

-- ----------------------------------------------------------------------------
-- 2. TEST: Anonymous user CAN read public seller store media (Logo/Banner)
-- ----------------------------------------------------------------------------
SELECT is(
    (SELECT COUNT(*)::INT FROM storage.objects WHERE bucket_id = 'seller-store-media' AND id = '88888888-8888-8888-8888-888888880002'),
    1,
    '2. Anonymous read on public seller-store-media bucket is allowed'
);

-- ----------------------------------------------------------------------------
-- 3. TEST: Unrelated buyer user cannot read seller KYC document object
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770001", "role": "authenticated"}';

SELECT is(
    (SELECT COUNT(*)::INT FROM storage.objects WHERE bucket_id = 'kyc-documents' AND id = '88888888-8888-8888-8888-888888880001'),
    0,
    '3. Unrelated buyer read on seller KYC document is denied by RLS'
);

-- ----------------------------------------------------------------------------
-- 4. TEST: Other seller user cannot read target seller KYC document object
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770004", "role": "authenticated"}';

SELECT is(
    (SELECT COUNT(*)::INT FROM storage.objects WHERE bucket_id = 'kyc-documents' AND id = '88888888-8888-8888-8888-888888880001'),
    0,
    '4. Unrelated seller read on another seller KYC document is denied by RLS'
);

-- ----------------------------------------------------------------------------
-- 5. TEST: Target seller owner CAN read own KYC document object
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770002", "role": "authenticated"}';

SELECT is(
    (SELECT COUNT(*)::INT FROM storage.objects WHERE bucket_id = 'kyc-documents' AND id = '88888888-8888-8888-8888-888888880001'),
    1,
    '5. Owner seller can read own KYC document object from kyc-documents bucket'
);

-- ----------------------------------------------------------------------------
-- 6. TEST: Admin user CAN read seller KYC document object
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770003", "role": "authenticated"}';

SELECT is(
    (SELECT COUNT(*)::INT FROM storage.objects WHERE bucket_id = 'kyc-documents' AND id = '88888888-8888-8888-8888-888888880001'),
    1,
    '6. Admin user with permission can read seller KYC document object'
);

-- ----------------------------------------------------------------------------
-- 7. TEST: Unrelated buyer calling authorize_kyc_document_access returns FALSE
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770001", "role": "authenticated"}';

SELECT is(
    public.authorize_kyc_document_access('77777777-7777-7777-7777-777777770002'),
    FALSE,
    '7. authorize_kyc_document_access returns FALSE for unauthorized buyer'
);

-- ----------------------------------------------------------------------------
-- 8. TEST: Target seller calling authorize_kyc_document_access returns TRUE
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770002", "role": "authenticated"}';

SELECT is(
    public.authorize_kyc_document_access('77777777-7777-7777-7777-777777770002'),
    TRUE,
    '8. authorize_kyc_document_access returns TRUE for owner seller'
);

-- ----------------------------------------------------------------------------
-- 9. TEST: Admin caller authorize_kyc_document_access returns TRUE
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770003", "role": "authenticated"}';

SELECT is(
    public.authorize_kyc_document_access('77777777-7777-7777-7777-777777770002'),
    TRUE,
    '9. authorize_kyc_document_access returns TRUE for admin user'
);

-- ----------------------------------------------------------------------------
-- 10. TEST: Seller cannot upload KYC into another seller folder
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770004", "role": "authenticated"}';

SELECT throws_ok(
    $$ INSERT INTO storage.objects (id, bucket_id, name, owner) VALUES ('88888888-8888-8888-8888-888888880099', 'kyc-documents', '77777777-7777-7777-7777-777777770002/malicious.png', '77777777-7777-7777-7777-777777770004') $$,
    '42501',
    NULL,
    '10. Cross-folder KYC upload attempt is denied by RLS'
);

-- ----------------------------------------------------------------------------
-- 11. TEST: Server-side defaults for newly created seller store
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770002", "role": "authenticated"}';

SELECT is(
    (SELECT is_approved FROM public.seller_stores WHERE id = '99999999-9999-9999-9999-999999990002'),
    FALSE,
    '11. Server-side default for is_approved is FALSE'
);

SELECT is(
    (SELECT kyc_status FROM public.seller_stores WHERE id = '99999999-9999-9999-9999-999999990002'),
    'Pending',
    '12. Server-side default for kyc_status is Pending'
);

SELECT is(
    (SELECT is_verified FROM public.seller_stores WHERE id = '99999999-9999-9999-9999-999999990002'),
    FALSE,
    '13. Server-side default for is_verified is FALSE'
);

-- ----------------------------------------------------------------------------
-- 14. TEST: Seller self-review attempt on own application fails
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770002", "role": "authenticated"}';

SELECT throws_ok(
    $$ SELECT public.admin_review_seller_application('99999999-9999-9999-9999-999999990002', 'Approved', '', '') $$,
    'P0001',
    NULL,
    '14. Seller self-review attempt raises permission denied exception'
);

-- ----------------------------------------------------------------------------
-- 15. TEST: Admin rejection without non-empty reason fails
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770003", "role": "authenticated"}';

SELECT throws_ok(
    $$ SELECT public.admin_review_seller_application('99999999-9999-9999-9999-999999990002', 'Rejected', '', '') $$,
    'P0001',
    NULL,
    '15. Rejection without a non-empty reason fails'
);

-- ----------------------------------------------------------------------------
-- 16. TEST: Admin review rejection with valid reason updates store & logs audit entry
-- ----------------------------------------------------------------------------
SELECT ok(
    public.admin_review_seller_application('99999999-9999-9999-9999-999999990002', 'Rejected', 'CNIC blur image provided', ''),
    '16. Admin review rejection with reason succeeds'
);

SELECT is(
    (SELECT kyc_status FROM public.seller_stores WHERE id = '99999999-9999-9999-9999-999999990002'),
    'Rejected',
    '17. kyc_status updated to Rejected'
);

-- ----------------------------------------------------------------------------
-- 18. TEST: Admin review requesting ResubmissionRequired succeeds and updates constraint
-- ----------------------------------------------------------------------------
SELECT ok(
    public.admin_review_seller_application('99999999-9999-9999-9999-999999990002', 'ResubmissionRequired', 'Selfie does not match CNIC', 'Upload clearer selfie holding CNIC'),
    '18. Admin review decision ResubmissionRequired succeeds'
);

SELECT is(
    (SELECT kyc_status FROM public.seller_stores WHERE id = '99999999-9999-9999-9999-999999990002'),
    'ResubmissionRequired',
    '19. kyc_status successfully set to ResubmissionRequired'
);

-- ----------------------------------------------------------------------------
-- 20. TEST: Seller resubmission transitions state back to Pending
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770002", "role": "authenticated"}';

SELECT ok(
    public.seller_submit_kyc_resubmission('99999999-9999-9999-9999-999999990002', '77777777-7777-7777-7777-777777770002/new_cnic_f.png', '77777777-7777-7777-7777-777777770002/new_cnic_b.png', '77777777-7777-7777-7777-777777770002/new_selfie.png'),
    '20. Seller resubmission RPC execution succeeds'
);

SELECT is(
    (SELECT kyc_status FROM public.seller_stores WHERE id = '99999999-9999-9999-9999-999999990002'),
    'Pending',
    '21. kyc_status transitions back to Pending after resubmission'
);

-- ----------------------------------------------------------------------------
-- 22. TEST: Admin approval provisions seller role & updates store state
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770003", "role": "authenticated"}';

SELECT ok(
    public.admin_review_seller_application('99999999-9999-9999-9999-999999990002', 'Approved', '', ''),
    '22. Admin seller application approval succeeds'
);

-- ----------------------------------------------------------------------------
-- 23. TEST: Shadow table public.kyc_documents does NOT exist
-- ----------------------------------------------------------------------------
SELECT hasnt_table(
    'public',
    'kyc_documents',
    '23. Shadow table public.kyc_documents does not exist in schema'
);

-- ----------------------------------------------------------------------------
-- 24. TEST: Canonical table public.seller_kyc_documents exists
-- ----------------------------------------------------------------------------
SELECT has_table(
    'public',
    'seller_kyc_documents',
    '24. Canonical table public.seller_kyc_documents exists in schema'
);

-- ----------------------------------------------------------------------------
-- 25. TEST: Canonical table public.seller_kyc_documents has Phase 7 path columns
-- ----------------------------------------------------------------------------
SELECT has_column(
    'public',
    'seller_kyc_documents',
    'cnic_front_path',
    '25. Canonical seller_kyc_documents table has cnic_front_path column'
);

SELECT * FROM finish();
ROLLBACK;
