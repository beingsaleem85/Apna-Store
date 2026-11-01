-- ============================================================================
-- SQL Test: Task A1 - Dispute Arbitration Server RBAC & Audit Logging Tests
-- ============================================================================

BEGIN;
SELECT plan(26);

-- ----------------------------------------------------------------------------
-- 0. SEED TEST FIXTURES & USERS IN auth.users
-- ----------------------------------------------------------------------------
INSERT INTO auth.users (id, email) VALUES
    ('10000000-0000-0000-0000-000000000001', 'buyer_dispute_test@example.com'),
    ('10000000-0000-0000-0000-000000000002', 'seller_dispute_test@example.com'),
    -- 12 Staff Users
    ('10000000-0000-0000-0000-000000000010', 'staff_owner@test.com'),
    ('10000000-0000-0000-0000-000000000011', 'staff_superAdmin@test.com'),
    ('10000000-0000-0000-0000-000000000012', 'staff_disputeManager@test.com'),
    ('10000000-0000-0000-0000-000000000013', 'staff_financeAdmin@test.com'),
    ('10000000-0000-0000-0000-000000000014', 'staff_sellerManager@test.com'),
    ('10000000-0000-0000-0000-000000000015', 'staff_supportAdmin@test.com'),
    ('10000000-0000-0000-0000-000000000016', 'staff_catalogManager@test.com'),
    ('10000000-0000-0000-0000-000000000017', 'staff_orderManager@test.com'),
    ('10000000-0000-0000-0000-000000000018', 'staff_marketingManager@test.com'),
    ('10000000-0000-0000-0000-000000000019', 'staff_fraudAnalyst@test.com'),
    ('10000000-0000-0000-0000-000000000020', 'staff_reportingAnalyst@test.com'),
    ('10000000-0000-0000-0000-000000000021', 'staff_auditor@test.com'),
    -- Role assignment target user
    ('10000000-0000-0000-0000-000000000099', 'staff_assign_target@test.com')
ON CONFLICT (id) DO NOTHING;

-- Seed Staff Roles in user_roles
INSERT INTO public.user_roles (user_id, role, staff_role) VALUES
    ('10000000-0000-0000-0000-000000000001', 'buyer'::public.app_role, NULL),
    ('10000000-0000-0000-0000-000000000002', 'seller'::public.app_role, NULL),
    ('10000000-0000-0000-0000-000000000010', 'owner'::public.app_role, 'owner'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000011', 'super_admin'::public.app_role, 'superAdmin'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000012', 'admin'::public.app_role, 'disputeManager'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000013', 'admin'::public.app_role, 'financeAdmin'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000014', 'admin'::public.app_role, 'sellerManager'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000015', 'admin'::public.app_role, 'supportAdmin'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000016', 'admin'::public.app_role, 'catalogManager'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000017', 'admin'::public.app_role, 'orderManager'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000018', 'admin'::public.app_role, 'marketingManager'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000019', 'admin'::public.app_role, 'fraudAnalyst'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000020', 'admin'::public.app_role, 'reportingAnalyst'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000021', 'admin'::public.app_role, 'auditor'::public.admin_staff_role)
ON CONFLICT (user_id, role) DO UPDATE SET staff_role = EXCLUDED.staff_role;

-- Seed Seller Store & Wallet
INSERT INTO public.seller_stores (id, owner_id, name, shop_slug, is_approved, is_suspended)
VALUES ('11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'Arbitration Store', 'arb-store-test', TRUE, FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.wallet_accounts (id, seller_store_id, currency, current_balance, available_balance)
VALUES ('77777777-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'PKR', 10000.00, 10000.00)
ON CONFLICT (seller_store_id) DO NOTHING;

-- Seed Orders: Delivered/Collected vs Shipped/Uncollected
INSERT INTO public.buyer_orders (id, customer_user_id, customer_name, customer_email, amount, payment_method, payment_status, status)
VALUES
    ('ORD-COD-DELIVERED', '10000000-0000-0000-0000-000000000001', 'Test Buyer', 'buyer@test.com', 2500.00, 'Cash on Delivery', 'Pending', 'Delivered'),
    ('ORD-COD-SHIPPED', '10000000-0000-0000-0000-000000000001', 'Test Buyer', 'buyer@test.com', 2500.00, 'Cash on Delivery', 'Pending', 'Shipped')
ON CONFLICT (id) DO NOTHING;

-- Seed Category & Product
INSERT INTO public.categories (id, name, slug)
VALUES ('33333333-0000-0000-0000-000000000001', 'Arb Cat', 'arb-cat')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.products (id, seller_store_id, category_id, name, slug, price, stock_quantity)
VALUES ('44444444-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001', 'Arb Item', 'arb-item', 2500.00, 10)
ON CONFLICT (id) DO NOTHING;

-- Seed Order Items
INSERT INTO public.order_items (id, order_id, product_id, seller_store_id, product_name, sku, unit_price, quantity, total_price, commission_rate)
VALUES
    ('55555555-0000-0000-0000-000000000001', 'ORD-COD-DELIVERED', '44444444-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'Item 1', 'SKU-1', 2500.00, 1, 2500.00, 10.00),
    ('55555555-0000-0000-0000-000000000002', 'ORD-COD-SHIPPED', '44444444-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'Item 2', 'SKU-2', 2500.00, 1, 2500.00, 10.00)
ON CONFLICT (id) DO NOTHING;

-- Seed Separate Return Claims for each scenario:
-- Claim 1: Owner test
-- Claim 2: superAdmin test
-- Claim 3: disputeManager test
-- Claim 4: Denied roles tests
-- Claim 5: Missing notes test
-- Claim 6: Already completed claim
-- Claim 7: Shipped COD uncollected
-- Claim 8: Approved refund & duplicate test
INSERT INTO public.return_requests (id, order_id, order_item_id, seller_store_id, customer_user_id, return_reason, quantity, status)
VALUES
    ('20000000-0000-0000-0000-000000000001', 'ORD-COD-DELIVERED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Claim 1 for Owner', 1, 'Requested'),
    ('20000000-0000-0000-0000-000000000002', 'ORD-COD-DELIVERED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Claim 2 for SuperAdmin', 1, 'Requested'),
    ('20000000-0000-0000-0000-000000000003', 'ORD-COD-DELIVERED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Claim 3 for DisputeManager', 1, 'Requested'),
    ('20000000-0000-0000-0000-000000000004', 'ORD-COD-DELIVERED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Claim 4 for Denied Roles', 1, 'Requested'),
    ('20000000-0000-0000-0000-000000000005', 'ORD-COD-DELIVERED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Claim 5 for Notes validation', 1, 'Requested'),
    ('20000000-0000-0000-0000-000000000006', 'ORD-COD-DELIVERED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Claim 6 Already completed', 1, 'Completed'),
    ('20000000-0000-0000-0000-000000000007', 'ORD-COD-SHIPPED', '55555555-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Claim 7 Shipped COD uncollected', 1, 'Requested'),
    ('20000000-0000-0000-0000-000000000008', 'ORD-COD-DELIVERED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Claim 8 Approval test', 1, 'Requested')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 1. ASSERTION: Unauthenticated caller is rejected
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'Reason');
    $$,
    '%Access denied%Unauthenticated%',
    '1. Unauthenticated caller is rejected'
);

-- ----------------------------------------------------------------------------
-- 2-4. ASSERTIONS: Allowed Roles Succeed on Separate Dedicated Claims
-- ----------------------------------------------------------------------------

-- Role: owner on Claim 1
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000010', true);
SELECT is(
    (public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'Owner reject on claim 1') ->> 'success')::BOOLEAN,
    TRUE,
    '2. Staff role: owner succeeds on separate claim 1'
);

-- Role: superAdmin on Claim 2
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
SELECT is(
    (public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000002'::uuid, 'Rejected', 'SuperAdmin reject on claim 2') ->> 'success')::BOOLEAN,
    TRUE,
    '3. Staff role: superAdmin succeeds on separate claim 2'
);

-- Role: disputeManager on Claim 3
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000012', true);
SELECT is(
    (public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000003'::uuid, 'Rejected', 'DisputeManager reject on claim 3') ->> 'success')::BOOLEAN,
    TRUE,
    '4. Staff role: disputeManager succeeds on separate claim 3'
);

-- ----------------------------------------------------------------------------
-- 5-13. ASSERTIONS: 9 Denied Staff Roles Rejected with 42501 on Claim 4
-- ----------------------------------------------------------------------------

-- Role 4: financeAdmin (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000013', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Rejected', 'Finance reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '5. Staff role: financeAdmin is rejected with 42501'
);

-- Role 5: sellerManager (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000014', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Rejected', 'SellerManager reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '6. Staff role: sellerManager is rejected with 42501'
);

-- Role 6: supportAdmin (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000015', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Rejected', 'Support reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '7. Staff role: supportAdmin is rejected with 42501'
);

-- Role 7: catalogManager (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000016', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Rejected', 'Catalog reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '8. Staff role: catalogManager is rejected with 42501'
);

-- Role 8: orderManager (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000017', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Rejected', 'Order reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '9. Staff role: orderManager is rejected with 42501'
);

-- Role 9: marketingManager (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000018', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Rejected', 'Marketing reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '10. Staff role: marketingManager is rejected with 42501'
);

-- Role 10: fraudAnalyst (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000019', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Rejected', 'Fraud reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '11. Staff role: fraudAnalyst is rejected with 42501'
);

-- Role 11: reportingAnalyst (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000020', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Rejected', 'Report reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '12. Staff role: reportingAnalyst is rejected with 42501'
);

-- Role 12: auditor (Denied for returns/review)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000021', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Rejected', 'Auditor reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '13. Staff role: auditor is rejected with 42501'
);

-- ----------------------------------------------------------------------------
-- 14. ASSERTION: Rejection without notes is rejected (P0005)
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000005'::uuid, 'Rejected', '');
    $$,
    '%Rejection notes are mandatory%',
    '14. Rejection without notes is rejected with code P0005'
);

-- ----------------------------------------------------------------------------
-- 15. ASSERTION: Already finalized claim is rejected (P0003)
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000006'::uuid, 'Rejected', 'Completed claim reject');
    $$,
    '%already finalized%',
    '15. Attempt to arbitrate already completed claim throws P0003 error'
);

-- ----------------------------------------------------------------------------
-- 16. ASSERTION: COD + Shipped (uncollected) order is rejected (P0006)
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000007'::uuid, 'Approved', 'Shipped COD approve');
    $$,
    '%has not been collected/delivered%',
    '16. Approval of COD claim in Shipped status throws P0006'
);

-- ----------------------------------------------------------------------------
-- 17. ASSERTION: COD + Delivered order approval succeeds and writes status 'Completed'
-- ----------------------------------------------------------------------------
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);

SELECT is(
    (
        SELECT rr.status
        FROM (
            SELECT public.admin_arbitrate_return_claim(
                '20000000-0000-0000-0000-000000000008'::uuid,
                'Approved',
                'Valid approval for collected COD order item'
            ) AS res
        ) sub
        JOIN public.return_requests rr ON rr.id = '20000000-0000-0000-0000-000000000008'
    ),
    'Completed',
    '17. Approved arbitration succeeds on Delivered COD order and writes status Completed'
);

-- ----------------------------------------------------------------------------
-- 18. ASSERTION: Calling arbitration twice throws P0003
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
    SELECT public.admin_arbitrate_return_claim(
        '20000000-0000-0000-0000-000000000008'::uuid,
        'Approved',
        'Duplicate refund attempt'
    );
    $$,
    '%already finalized%',
    '18. Calling arbitration twice is blocked by finalized claim check'
);

-- ----------------------------------------------------------------------------
-- 19-22. ASSERTIONS: Audit Log Security & Immutability Tests
-- ----------------------------------------------------------------------------

-- 19: Normal authenticated buyer reads 0 rows from audit_logs
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
SELECT is(
    (SELECT count(*)::INT FROM public.audit_logs),
    0,
    '19. Normal user (buyer) reads 0 rows from audit_logs'
);

-- 20: Staff role without audit permission (catalogManager) reads 0 rows
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000016', true);
SELECT is(
    (SELECT count(*)::INT FROM public.audit_logs),
    0,
    '20. Staff role without audit access (catalogManager) reads 0 rows from audit_logs'
);

-- 21: Direct UPDATE on audit_logs fails for every role (trigger blocks)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000010', true);
    UPDATE public.audit_logs SET action = 'TAMPERED';
    $$,
    '%immutable and cannot be modified or deleted%',
    '21. Direct UPDATE on audit_logs fails for all roles'
);

-- 22: Direct DELETE on audit_logs fails for every role (trigger blocks)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000010', true);
    DELETE FROM public.audit_logs;
    $$,
    '%immutable and cannot be modified or deleted%',
    '22. Direct DELETE on audit_logs fails for all roles'
);

-- ----------------------------------------------------------------------------
-- 23-26. ASSERTIONS: Staff Role Assignment Governance & Audit Tests
-- ----------------------------------------------------------------------------

-- 23: User cannot assign staff_role to themselves
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
    SELECT public.admin_assign_staff_role('10000000-0000-0000-0000-000000000011'::uuid, 'disputeManager'::public.admin_staff_role);
    $$,
    '%Self-assignment of staff roles is prohibited%',
    '23. User cannot assign staff_role to themselves'
);

-- 24: financeAdmin cannot assign roles (42501)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000013', true);
    SELECT public.admin_assign_staff_role('10000000-0000-0000-0000-000000000099'::uuid, 'supportAdmin'::public.admin_staff_role);
    $$,
    '%Access denied: Only Owner or Super Admin can assign staff roles%',
    '24. financeAdmin cannot assign staff roles'
);

-- 25: superAdmin can assign roles
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
SELECT is(
    (public.admin_assign_staff_role('10000000-0000-0000-0000-000000000099'::uuid, 'supportAdmin'::public.admin_staff_role) ->> 'success')::BOOLEAN,
    TRUE,
    '25. superAdmin can successfully assign staff roles'
);

-- 26: Assignment writes an audit row
SELECT is(
    (SELECT count(*)::INT FROM public.audit_logs WHERE target_id = '10000000-0000-0000-0000-000000000099' AND action = 'STAFF_ROLE_ASSIGNED'),
    1,
    '26. Staff role assignment writes a row to public.audit_logs'
);

SELECT * FROM finish();
ROLLBACK;
