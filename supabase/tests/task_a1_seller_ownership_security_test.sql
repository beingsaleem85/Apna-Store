-- ============================================================================
-- SQL Test: Task A1 - Seller Ownership Security & Cross-Tenant Boundary Tests
-- ============================================================================

BEGIN;
SELECT plan(5);

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
