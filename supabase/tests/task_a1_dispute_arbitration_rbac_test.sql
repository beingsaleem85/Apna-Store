-- ============================================================================
-- SQL Test: Task A1 - Dispute Arbitration Server RBAC & Audit Logging Tests
-- ============================================================================

BEGIN;
SELECT plan(6);

-- ----------------------------------------------------------------------------
-- 0. SEED TEST FIXTURES & USERS IN auth.users
-- ----------------------------------------------------------------------------
INSERT INTO auth.users (id, email) VALUES
    ('10000000-0000-0000-0000-000000000001', 'buyer_dispute_test@example.com'),
    ('10000000-0000-0000-0000-000000000002', 'seller_dispute_test@example.com'),
    ('10000000-0000-0000-0000-000000000003', 'regular_buyer_test@example.com'),
    ('10000000-0000-0000-0000-000000000004', 'superadmin_dispute_test@example.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_roles (user_id, role) VALUES
    ('10000000-0000-0000-0000-000000000003', 'buyer'::public.app_role),
    ('10000000-0000-0000-0000-000000000004', 'super_admin'::public.app_role)
ON CONFLICT (user_id, role) DO NOTHING;

-- Seed Seller Store
INSERT INTO public.seller_stores (id, owner_id, name, shop_slug, is_approved, is_suspended)
VALUES ('11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'Arbitration Store', 'arb-store-test', TRUE, FALSE)
ON CONFLICT (id) DO NOTHING;

-- Seed Buyer Order
INSERT INTO public.buyer_orders (id, customer_user_id, customer_name, customer_email, amount, payment_method, status)
VALUES ('ORD-ARB-TEST-001', '10000000-0000-0000-0000-000000000001', 'Test Buyer', 'buyer@test.com', 5000.00, 'COD', 'Delivered')
ON CONFLICT (id) DO NOTHING;

-- Seed Product & Category
INSERT INTO public.categories (id, name, slug)
VALUES ('33333333-0000-0000-0000-000000000001', 'Arb Cat', 'arb-cat')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.products (id, seller_store_id, category_id, name, slug, price, stock_quantity)
VALUES ('44444444-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001', 'Arb Item', 'arb-item', 2500.00, 10)
ON CONFLICT (id) DO NOTHING;

-- Seed Valid Order Item
INSERT INTO public.order_items (id, order_id, product_id, seller_store_id, product_name, sku, unit_price, quantity, total_price)
VALUES ('55555555-0000-0000-0000-000000000001', 'ORD-ARB-TEST-001', '44444444-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'Arb Item', 'SKU-ARB-1', 2500.00, 1, 2500.00)
ON CONFLICT (id) DO NOTHING;

-- Seed Return Claims
INSERT INTO public.return_requests (id, order_id, order_item_id, seller_store_id, customer_user_id, return_reason, quantity, status)
VALUES
    ('20000000-0000-0000-0000-000000000001', 'ORD-ARB-TEST-001', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Defective packaging', 1, 'Requested'),
    ('20000000-0000-0000-0000-000000000002', 'ORD-ARB-TEST-001', '00000000-0000-0000-0000-000000000000', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Missing price item', 1, 'Requested'),
    ('20000000-0000-0000-0000-000000000003', 'ORD-ARB-TEST-001', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Already processed claim', 1, 'Completed'),
    ('20000000-0000-0000-0000-000000000004', 'ORD-ARB-TEST-001', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Claim to reject cleanly', 1, 'Requested')
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
-- 2. ASSERTION: Regular buyer role is rejected (RBAC enforcement)
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000003', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'Buyer trying to arbitrate');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    'Regular user without admin role is rejected with 42501'
);

-- ----------------------------------------------------------------------------
-- 3. ASSERTION: Rejection without notes is rejected (P0005)
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000004', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', '');
    $$,
    '%Rejection notes are mandatory%',
    'Rejection without notes is rejected with code P0005'
);

-- ----------------------------------------------------------------------------
-- 4. ASSERTION: Refund with missing or invalid order item price is rejected (P0004)
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000004', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000002'::uuid, 'Approved', 'Approve bad line item');
    $$,
    '%missing or invalid price%',
    'Approval of claim with missing order item price throws P0004 error'
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
-- 6. ASSERTION: Authorized SuperAdmin rejection succeeds and writes audit log
-- ----------------------------------------------------------------------------
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000004', true);

SELECT is(
    (public.admin_arbitrate_return_claim(
        '20000000-0000-0000-0000-000000000004'::uuid,
        'Rejected',
        'Item returned with buyer wear and tear.'
    ) ->> 'success')::BOOLEAN,
    TRUE,
    'Authorized SuperAdmin successfully rejects dispute claim with valid audit trail'
);

SELECT * FROM finish();
ROLLBACK;
