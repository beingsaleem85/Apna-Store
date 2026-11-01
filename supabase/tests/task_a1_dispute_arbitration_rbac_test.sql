-- ============================================================================
-- SQL Test: Task A1 - Dispute Arbitration Server RBAC & Audit Logging Tests
-- ============================================================================

BEGIN;
SELECT plan(18);

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
    ('10000000-0000-0000-0000-000000000021', 'staff_auditor@test.com')
ON CONFLICT (id) DO NOTHING;

-- Seed Staff Roles in user_roles
INSERT INTO public.user_roles (user_id, role, staff_role) VALUES
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

-- Seed Return Claims
INSERT INTO public.return_requests (id, order_id, order_item_id, seller_store_id, customer_user_id, return_reason, quantity, status)
VALUES
    ('20000000-0000-0000-0000-000000000001', 'ORD-COD-DELIVERED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Defective', 1, 'Requested'),
    ('20000000-0000-0000-0000-000000000002', 'ORD-COD-SHIPPED', '55555555-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Shipped COD refund attempt', 1, 'Requested'),
    ('20000000-0000-0000-0000-000000000003', 'ORD-COD-DELIVERED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Already processed', 1, 'Completed'),
    ('20000000-0000-0000-0000-000000000004', 'ORD-COD-DELIVERED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Approve test', 1, 'Requested')
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
-- 2-13. ASSERTIONS: 12 Staff Roles RBAC Matrix Evaluation
-- Allowed: owner, superAdmin, disputeManager
-- Denied: financeAdmin, sellerManager, supportAdmin, catalogManager, orderManager, marketingManager, fraudAnalyst, reportingAnalyst, auditor
-- ----------------------------------------------------------------------------

-- Role 1: owner (Allowed)
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000010', true);
SELECT is(
    (public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'Owner reject') ->> 'success')::BOOLEAN,
    TRUE,
    '2. Staff role: owner succeeds'
);

-- Reset claim 1 for subsequent role tests
UPDATE public.return_requests SET status = 'Requested' WHERE id = '20000000-0000-0000-0000-000000000001';

-- Role 2: superAdmin (Allowed)
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
SELECT is(
    (public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'SuperAdmin reject') ->> 'success')::BOOLEAN,
    TRUE,
    '3. Staff role: superAdmin succeeds'
);

UPDATE public.return_requests SET status = 'Requested' WHERE id = '20000000-0000-0000-0000-000000000001';

-- Role 3: disputeManager (Allowed)
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000012', true);
SELECT is(
    (public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'DisputeManager reject') ->> 'success')::BOOLEAN,
    TRUE,
    '4. Staff role: disputeManager succeeds'
);

UPDATE public.return_requests SET status = 'Requested' WHERE id = '20000000-0000-0000-0000-000000000001';

-- Role 4: financeAdmin (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000013', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'Finance reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '5. Staff role: financeAdmin is rejected with 42501'
);

-- Role 5: sellerManager (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000014', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'SellerManager reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '6. Staff role: sellerManager is rejected with 42501'
);

-- Role 6: supportAdmin (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000015', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'Support reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '7. Staff role: supportAdmin is rejected with 42501'
);

-- Role 7: catalogManager (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000016', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'Catalog reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '8. Staff role: catalogManager is rejected with 42501'
);

-- Role 8: orderManager (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000017', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'Order reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '9. Staff role: orderManager is rejected with 42501'
);

-- Role 9: marketingManager (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000018', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'Marketing reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '10. Staff role: marketingManager is rejected with 42501'
);

-- Role 10: fraudAnalyst (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000019', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'Fraud reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '11. Staff role: fraudAnalyst is rejected with 42501'
);

-- Role 11: reportingAnalyst (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000020', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'Report reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '12. Staff role: reportingAnalyst is rejected with 42501'
);

-- Role 12: auditor (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000021', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'Auditor reject');
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
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', '');
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
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000003'::uuid, 'Rejected', 'Completed claim reject');
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
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000002'::uuid, 'Approved', 'Shipped COD approve');
    $$,
    '%has not been collected/delivered%',
    '16. Approval of COD claim in Shipped status throws P0006'
);

-- ----------------------------------------------------------------------------
-- 17. ASSERTION: COD + Delivered (collected) order refund succeeds
-- ----------------------------------------------------------------------------
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);

SELECT is(
    (public.admin_arbitrate_return_claim(
        '20000000-0000-0000-0000-000000000004'::uuid,
        'Approved',
        'Valid approval for collected COD order item'
    ) ->> 'success')::BOOLEAN,
    TRUE,
    '17. Approved arbitration succeeds on Delivered COD order'
);

-- ----------------------------------------------------------------------------
-- 18. ASSERTION: Calling arbitration twice throws P0003
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
    SELECT public.admin_arbitrate_return_claim(
        '20000000-0000-0000-0000-000000000004'::uuid,
        'Approved',
        'Duplicate refund attempt'
    );
    $$,
    '%already finalized%',
    '18. Calling arbitration twice is blocked by finalized claim check'
);

SELECT * FROM finish();
ROLLBACK;
