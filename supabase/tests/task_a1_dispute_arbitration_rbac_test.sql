-- ============================================================================
-- SQL Test: Task A1 - Dispute Arbitration Server RBAC & Audit Logging Tests
-- ============================================================================

BEGIN;
SELECT plan(3);

-- Setup test entities
DO $$
DECLARE
    v_buyer_id UUID := gen_random_uuid();
    v_seller_owner UUID := gen_random_uuid();
    v_store_id UUID := gen_random_uuid();
    v_claim_id UUID := '00000000-0000-0000-0000-000000000077'::UUID;
BEGIN
    INSERT INTO public.seller_stores (id, owner_id, name, shop_slug, is_approved)
    VALUES (v_store_id, v_seller_owner, 'Arbitration Test Store', 'arb-test-store', TRUE);

    INSERT INTO public.buyer_orders (id, customer_user_id, customer_name, customer_email, amount, payment_method, status)
    VALUES ('ORD-ARB-001', v_buyer_id, 'Test Buyer', 'buyer@test.com', 2000.00, 'COD', 'Delivered');

    INSERT INTO public.return_requests (id, order_id, seller_store_id, customer_user_id, return_reason, status)
    VALUES (v_claim_id, 'ORD-ARB-001', v_store_id, v_buyer_id, 'Defective item on delivery', 'Requested');
END $$;

-- 1. Test: Non-admin caller is rejected (error 42501)
SELECT throws_like(
    $$
    -- Simulate non-admin regular authenticated user
    SELECT public.admin_arbitrate_return_claim(
        '00000000-0000-0000-0000-000000000077'::UUID,
        'Rejected',
        'Unauthorized arbitrate attempt'
    );
    $$,
    '%Access denied: Insufficient administrative privileges%',
    'Non-admin caller is rejected with 42501 error code'
);

-- 2. Test: Wrong-role admin (e.g. catalogManager) is rejected (error 42501)
DO $$
DECLARE
    v_wrong_admin_id UUID := gen_random_uuid();
    v_threw BOOLEAN := FALSE;
BEGIN
    -- Assign catalogManager role (does not have returns/dispute privilege)
    INSERT INTO public.user_roles (user_id, role)
    VALUES (v_wrong_admin_id, 'catalogManager');

    PERFORM set_config('request.jwt.claim.sub', v_wrong_admin_id::text, true);

    BEGIN
        PERFORM public.admin_arbitrate_return_claim(
            '00000000-0000-0000-0000-000000000077'::UUID,
            'Rejected',
            'Catalog manager cannot arbitrate'
        );
    EXCEPTION WHEN OTHERS THEN
        IF SQLSTATE = '42501' THEN
            v_threw := TRUE;
        END IF;
    END;

    IF v_threw THEN
        PERFORM pass('Wrong-role admin (catalogManager) is rejected with 42501');
    ELSE
        PERFORM fail('Wrong-role admin was unexpectedly permitted to arbitrate dispute');
    END IF;
END $$;

-- 3. Test: Authorized SuperAdmin arbitrates and creates audit log
DO $$
DECLARE
    v_super_admin_id UUID := gen_random_uuid();
    v_res JSONB;
    v_audit_count INT;
BEGIN
    INSERT INTO public.user_roles (user_id, role)
    VALUES (v_super_admin_id, 'superAdmin');

    PERFORM set_config('request.jwt.claim.sub', v_super_admin_id::text, true);

    v_res := public.admin_arbitrate_return_claim(
        '00000000-0000-0000-0000-000000000077'::UUID,
        'Rejected',
        'Evidence reviewed by Super Admin'
    );

    SELECT COUNT(*) INTO v_audit_count
    FROM public.admin_audit_logs
    WHERE target_id = '00000000-0000-0000-0000-000000000077'
      AND action = 'DISPUTE_REJECTED';

    IF (v_res->>'success')::BOOLEAN = TRUE AND v_audit_count = 1 THEN
        PERFORM pass('Authorized SuperAdmin arbitrates claim and writes immutable audit log entry');
    ELSE
        PERFORM fail('Dispute arbitration failed to complete or log audit entry');
    END IF;
END $$;

SELECT * FROM finish();
ROLLBACK;
