-- ============================================================================
-- SQL Test: Task A1 - Seller Ownership Security & Cross-Tenant Boundary Tests
-- ============================================================================

BEGIN;
SELECT plan(5);

-- Seed Auth Users & Tenant fixtures
INSERT INTO auth.users (id, email) VALUES
    ('00000000-0000-0000-0000-000000000091', 'caller_seller_a@test.com'),
    ('00000000-0000-0000-0000-000000000092', 'other_seller_b@test.com'),
    ('00000000-0000-0000-0000-000000000093', 'buyer_user@test.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, full_name, email, role, phone, is_deactivated) VALUES
    ('00000000-0000-0000-0000-000000000091', 'Seller A', 'caller_seller_a@test.com', 'seller'::public.app_role, '+923000000091', FALSE),
    ('00000000-0000-0000-0000-000000000092', 'Seller B', 'other_seller_b@test.com', 'seller'::public.app_role, '+923000000092', FALSE),
    ('00000000-0000-0000-0000-000000000093', 'Buyer U', 'buyer_user@test.com', 'buyer'::public.app_role, '+923000000093', FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.seller_stores (id, owner_id, name, shop_slug, is_approved, is_suspended) VALUES
    ('00000000-0000-0000-0000-000000000071', '00000000-0000-0000-0000-000000000091', 'Store A', 'store-a-own', TRUE, FALSE),
    ('00000000-0000-0000-0000-000000000072', '00000000-0000-0000-0000-000000000092', 'Store B', 'store-b-other', TRUE, FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.products (id, seller_store_id, name, price, stock_quantity, is_active, approval_status) VALUES
    ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000072', 'Product B', 100.00, 10, TRUE, 'Approved')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.buyer_orders (id, customer_user_id, customer_name, customer_email, order_number, amount, total_amount, grand_total, status, payment_status, payment_method) VALUES
    ('ORD-FAKE-999', '00000000-0000-0000-0000-000000000093', 'Buyer', 'buyer_user@test.com', 'ORD-999', 100.00, 100.00, 100.00, 'Processing', 'Pending', 'Cash on Delivery')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.order_items (id, order_id, product_id, seller_store_id, product_name, unit_price, quantity, total_price) VALUES
    ('00000000-0000-0000-0000-000000000004', 'ORD-FAKE-999', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000072', 'Product B', 100.00, 1, 100.00)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.chat_rooms (id, buyer_user_id, seller_store_id) VALUES
    ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000093', '00000000-0000-0000-0000-000000000072')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.return_requests (id, order_id, order_item_id, seller_store_id, customer_user_id, quantity, reason, status) VALUES
    ('00000000-0000-0000-0000-000000000003', 'ORD-FAKE-999', '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000072', '00000000-0000-0000-0000-000000000093', 1, 'Defective', 'Requested')
ON CONFLICT (id) DO NOTHING;

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000091", "role": "authenticated"}';

-- 1. Test: Seller A cannot update Seller B's stock
SELECT throws_like(
    $$
    -- Simulate authenticated call as an unauthorized user
    SELECT public.seller_update_product_stock('00000000-0000-0000-0000-000000000001'::uuid, 50);
    $$,
    '%Access denied%Cannot manage inventory for another seller store%',
    'Security Definer RPC enforces store ownership check on stock update'
);

-- 2. Test: Stock quantity cannot go negative
SELECT throws_like(
    $$
    -- Simulate attempt with negative stock value
    SELECT public.seller_update_product_stock('00000000-0000-0000-0000-000000000001'::uuid, -10);
    $$,
    '%negative%',
    'Database RPC enforces non-negative stock quantity'
);

-- 3. Test: Seller cannot change fulfillment status of another store's order
SELECT throws_like(
    $$
    -- Call with unowned seller store or cross-tenant order
    SELECT public.seller_update_fulfillment_status('ORD-FAKE-999', 'Shipped', 'TRACK-123');
    $$,
    '%User does not own a registered seller store.%',
    'Order fulfillment update enforces registered seller store ownership'
);

-- 4. Test: Third user cannot send message in someone else's chat room
SELECT throws_like(
    $$
    SELECT public.send_chat_message('00000000-0000-0000-0000-000000000002'::uuid, 'Malicious eavesdrop message');
    $$,
    '%Access denied%not a participant in chat room%',
    'Chat RPC blocks non-participants from sending messages'
);

-- 5. Test: Seller cannot approve a return that belongs to another store
SELECT throws_like(
    $$
    SELECT public.review_return_request('00000000-0000-0000-0000-000000000003'::uuid, 'Approved', 'Unauthorized approval');
    $$,
    '%Access denied%Insufficient privileges to review return request%',
    'Return review RPC enforces store ownership for return processing'
);

SELECT * FROM finish();
ROLLBACK;
