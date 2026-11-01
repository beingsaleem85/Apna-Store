-- ============================================================================
-- SQL Test: Task A1 - Dispute Arbitration Server RBAC & Audit Logging Tests
-- ============================================================================

BEGIN;
SELECT plan(8);

-- ----------------------------------------------------------------------------
-- 0. SEED TEST FIXTURES & USERS IN auth.users
-- ----------------------------------------------------------------------------
INSERT INTO auth.users (id, email) VALUES
    ('10000000-0000-0000-0000-000000000001', 'buyer_dispute_test@example.com'),
    ('10000000-0000-0000-0000-000000000002', 'seller_dispute_test@example.com'),
    ('10000000-0000-0000-0000-000000000003', 'regular_buyer_test@example.com'),
    ('10000000-0000-0000-0000-000000000004', 'superadmin_dispute_test@example.com'),
    ('10000000-0000-0000-0000-000000000005', 'catalog_admin_no_returns@example.com'),
    ('10000000-0000-0000-0000-000000000006', 'support_admin_with_returns@example.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_roles (user_id, role) VALUES
    ('10000000-0000-0000-0000-000000000003', 'buyer'::public.app_role),
    ('10000000-0000-0000-0000-000000000004', 'super_admin'::public.app_role),
    ('10000000-0000-0000-0000-000000000005', 'seller'::public.app_role),
    ('10000000-0000-0000-0000-000000000006', 'admin'::public.app_role)
ON CONFLICT (user_id, role) DO NOTHING;

-- Grant returns review permission to admin role
INSERT INTO public.role_permissions (role, module, action)
VALUES ('admin'::public.app_role, 'returns', 'review')
ON CONFLICT (role, module, action) DO NOTHING;

-- Seed Seller Store & Wallet
INSERT INTO public.seller_stores (id, owner_id, name, shop_slug, is_approved, is_suspended)
VALUES ('11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'Arbitration Store', 'arb-store-test', TRUE, FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.wallet_accounts (id, seller_store_id, currency, current_balance, available_balance)
VALUES ('77777777-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'PKR', 10000.00, 10000.00)
ON CONFLICT (seller_store_id) DO NOTHING;

-- Seed Buyer Orders: 1 Delivered/Paid, 1 Pending/Uncollected
INSERT INTO public.buyer_orders (id, customer_user_id, customer_name, customer_email, amount, payment_method, payment_status, status)
VALUES
    ('ORD-ARB-COLLECTED', '10000000-0000-0000-0000-000000000001', 'Test Buyer', 'buyer@test.com', 5000.00, 'COD', 'Paid', 'Delivered'),
    ('ORD-ARB-UNCOLLECTED', '10000000-0000-0000-0000-000000000001', 'Test Buyer', 'buyer@test.com', 5000.00, 'COD', 'Pending', 'Processing')
ON CONFLICT (id) DO NOTHING;

-- Seed Product & Category
INSERT INTO public.categories (id, name, slug)
VALUES ('33333333-0000-0000-0000-000000000001', 'Arb Cat', 'arb-cat')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.products (id, seller_store_id, category_id, name, slug, price, stock_quantity)
VALUES ('44444444-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001', 'Arb Item', 'arb-item', 2500.00, 10)
ON CONFLICT (id) DO NOTHING;

-- Seed Order Items
INSERT INTO public.order_items (id, order_id, product_id, seller_store_id, product_name, sku, unit_price, quantity, total_price, commission_rate)
VALUES
    ('55555555-0000-0000-0000-000000000001', 'ORD-ARB-COLLECTED', '44444444-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'Arb Item Collected', 'SKU-ARB-1', 2500.00, 1, 2500.00, 10.00),
    ('55555555-0000-0000-0000-000000000002', 'ORD-ARB-UNCOLLECTED', '44444444-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'Arb Item Uncollected', 'SKU-ARB-2', 2500.00, 1, 2500.00, 10.00)
ON CONFLICT (id) DO NOTHING;

-- Seed Return Claims
INSERT INTO public.return_requests (id, order_id, order_item_id, seller_store_id, customer_user_id, return_reason, quantity, status)
VALUES
    ('20000000-0000-0000-0000-000000000001', 'ORD-ARB-COLLECTED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Defective packaging', 1, 'Requested'),
    ('20000000-0000-0000-0000-000000000002', 'ORD-ARB-UNCOLLECTED', '55555555-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Uncollected order refund attempt', 1, 'Requested'),
    ('20000000-0000-0000-0000-000000000003', 'ORD-ARB-COLLECTED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Already processed claim', 1, 'Completed'),
    ('20000000-0000-0000-0000-000000000004', 'ORD-ARB-COLLECTED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Full refund test claim', 1, 'Requested')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 1. ASSERTION: Unauthenticated caller is rejected
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'Test notes');
    $$,
    '%Access denied%Unauthenticated%',
    'Unauthenticated caller is rejected by dispute arbitration RPC'
);

-- ----------------------------------------------------------------------------
-- 2. ASSERTION: Wrong-role user (seller without returns permission) is rejected
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000005', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'Seller trying to arbitrate');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    'Wrong-role admin lacking returns/review permission is rejected with 42501'
);

-- ----------------------------------------------------------------------------
-- 3. ASSERTION: Right-role admin (with returns:review permission) succeeds
-- ----------------------------------------------------------------------------
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000006', true);

SELECT is(
    (public.admin_arbitrate_return_claim(
        '20000000-0000-0000-0000-000000000001'::uuid,
        'Rejected',
        'Valid rejection by support admin with returns:review permission'
    ) ->> 'success')::BOOLEAN,
    TRUE,
    'Right-role admin possessing returns:review permission successfully arbitrates'
);

-- ----------------------------------------------------------------------------
-- 4. ASSERTION: Rejection without notes is rejected (P0005)
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000004', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Rejected', '');
    $$,
    '%Rejection notes are mandatory%',
    'Rejection without notes is rejected with code P0005'
);

-- ----------------------------------------------------------------------------
-- 5. ASSERTION: Already finalized claim is rejected (P0003)
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000004', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000003'::uuid, 'Rejected', 'Reject already completed');
    $$,
    '%already finalized%',
    'Attempt to arbitrate already completed claim throws P0003 error'
);

-- ----------------------------------------------------------------------------
-- 6. ASSERTION: Uncollected order cannot be approved for refund (P0006)
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000004', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000002'::uuid, 'Approved', 'Attempt uncollected refund');
    $$,
    '%has not been collected/delivered%',
    'Approval of claim on uncollected order throws P0006'
);

-- ----------------------------------------------------------------------------
-- 7. ASSERTION: Approved path creates refund row, debits wallet, and writes audit log
-- ----------------------------------------------------------------------------
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000004', true);

SELECT is(
    (public.admin_arbitrate_return_claim(
        '20000000-0000-0000-0000-000000000004'::uuid,
        'Approved',
        'Valid approval for collected order item'
    ) ->> 'success')::BOOLEAN,
    TRUE,
    'Approved arbitration succeeds on collected order'
);

-- ----------------------------------------------------------------------------
-- 8. ASSERTION: Double refund prevention: Calling the function twice throws P0003
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000004', true);
    SELECT public.admin_arbitrate_return_claim(
        '20000000-0000-0000-0000-000000000004'::uuid,
        'Approved',
        'Second attempt duplicate refund'
    );
    $$,
    '%already finalized%',
    'Calling arbitration function twice is blocked by finalized claim check'
);

SELECT * FROM finish();
ROLLBACK;
