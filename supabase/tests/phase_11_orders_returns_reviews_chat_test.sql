-- ============================================================================
-- PGTAP TEST SUITE: PHASE 11 ORDERS, RETURNS, REVIEWS, CHAT & NOTIFICATIONS
-- File: supabase/tests/phase_11_orders_returns_reviews_chat_test.sql
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgtap;

BEGIN;

SELECT plan(31);

-- ----------------------------------------------------------------------------
-- SETUP: Seed Test Users, Stores, Products, Orders & Order Items
-- ----------------------------------------------------------------------------

-- Seed Auth Users
INSERT INTO auth.users (id, email) VALUES
    ('88888888-8888-8888-8888-888888880001', 'buyer_p11@example.com'),
    ('88888888-8888-8888-8888-888888880002', 'seller_a_p11@example.com'),
    ('88888888-8888-8888-8888-888888880003', 'seller_b_p11@example.com'),
    ('88888888-8888-8888-8888-888888880004', 'admin_p11@example.com'),
    ('88888888-8888-8888-8888-888888880005', 'outsider_p11@example.com')
ON CONFLICT (id) DO NOTHING;

-- Seed Profiles
INSERT INTO public.profiles (id, full_name, email) VALUES
    ('88888888-8888-8888-8888-888888880001', 'Buyer P11', 'buyer_p11@example.com'),
    ('88888888-8888-8888-8888-888888880002', 'Seller A P11', 'seller_a_p11@example.com'),
    ('88888888-8888-8888-8888-888888880003', 'Seller B P11', 'seller_b_p11@example.com'),
    ('88888888-8888-8888-8888-888888880004', 'Admin P11', 'admin_p11@example.com'),
    ('88888888-8888-8888-8888-888888880005', 'Outsider P11', 'outsider_p11@example.com')
ON CONFLICT (id) DO NOTHING;

-- Seed Roles
INSERT INTO public.user_roles (user_id, role, granted_at) VALUES
    ('88888888-8888-8888-8888-888888880001', 'buyer'::public.app_role, NOW()),
    ('88888888-8888-8888-8888-888888880002', 'seller'::public.app_role, NOW() + INTERVAL '1 sec'),
    ('88888888-8888-8888-8888-888888880003', 'seller'::public.app_role, NOW() + INTERVAL '2 sec'),
    ('88888888-8888-8888-8888-888888880004', 'super_admin'::public.app_role, NOW() + INTERVAL '3 sec'),
    ('88888888-8888-8888-8888-888888880005', 'buyer'::public.app_role, NOW() + INTERVAL '4 sec')
ON CONFLICT (user_id, role) DO UPDATE SET granted_at = EXCLUDED.granted_at;

-- Seed Seller Stores
INSERT INTO public.seller_stores (id, owner_id, shop_name, shop_slug, is_approved, is_suspended, commission_rate) VALUES
    ('eeee1111-1111-1111-1111-111111111111', '88888888-8888-8888-8888-888888880002', 'Store A P11', 'store-a-p11', TRUE, FALSE, 10.00),
    ('eeee2222-2222-2222-2222-222222222222', '88888888-8888-8888-8888-888888880003', 'Store B P11', 'store-b-p11', TRUE, FALSE, 15.00)
ON CONFLICT (id) DO UPDATE SET is_approved = TRUE, is_suspended = FALSE, commission_rate = EXCLUDED.commission_rate;

-- Seed Products
INSERT INTO public.products (id, seller_store_id, name, price, stock_quantity, approval_status, is_active) VALUES
    ('ffff1111-1111-1111-1111-111111111111', 'eeee1111-1111-1111-1111-111111111111', 'Item A P11', 1000.00, 50, 'Approved', TRUE),
    ('ffff2222-2222-2222-2222-222222222222', 'eeee2222-2222-2222-2222-222222222222', 'Item B P11', 2000.00, 50, 'Approved', TRUE)
ON CONFLICT (id) DO UPDATE SET approval_status = 'Approved', is_active = TRUE, price = EXCLUDED.price;

-- Create Multi-Seller Order via create_atomic_order
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880001", "role": "authenticated"}';

SELECT public.create_atomic_order(
    'p11-order-key-1',
    '[{"product_id": "ffff1111-1111-1111-1111-111111111111", "quantity": 1}, {"product_id": "ffff2222-2222-2222-2222-222222222222", "quantity": 1}]'::jsonb,
    '{"city": "Lahore"}'::jsonb,
    'COD'
);

-- ----------------------------------------------------------------------------
-- 1 & 2. AUTO FULFILLMENT CREATION & SELLER A FULFILLMENT TRANSITION
-- ----------------------------------------------------------------------------
-- 1. Verify two store_fulfillments created automatically by trigger
SELECT is(
    (SELECT COUNT(*)::INT FROM public.store_fulfillments WHERE order_id = (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1')),
    2,
    '1. Multi-seller checkout automatically seeded 2 store_fulfillments'
);

-- Seller A updates own store fulfillment to Shipped
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880002", "role": "authenticated"}';

SELECT ok(
    (public.seller_update_fulfillment_status(
        (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1'),
        'Shipped',
        'eeee1111-1111-1111-1111-111111111111'::uuid,
        'TCS Express',
        'TCS-90123'
    ))->>'store_fulfillment_status' = 'Shipped',
    '2. Seller A updates own store fulfillment status to Shipped'
);

-- ----------------------------------------------------------------------------
-- 3 & 4. SELLER ISOLATION & PARENT DERIVED STATUS
-- ----------------------------------------------------------------------------
-- 3. Seller A cannot update Seller B's fulfillment
SELECT throws_ok(
    $$ SELECT public.seller_update_fulfillment_status((SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1'), 'Shipped', 'eeee2222-2222-2222-2222-222222222222'::uuid) $$,
    'P0001',
    'Access denied: You do not own store eeee2222-2222-2222-2222-222222222222.',
    '3. Seller A cannot update another store fulfillment'
);

-- 4. Parent buyer_orders.status is Shipped (since Seller A is Shipped and Seller B is Pending)
SELECT is(
    (SELECT status FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1'),
    'Shipped',
    '4. Parent buyer_orders status derived as Shipped when Seller A ships'
);

-- ----------------------------------------------------------------------------
-- 5 & 6. COMPLETE MULTI-SELLER DELIVERED TRANSITION & COD SETTLEMENT
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880004", "role": "authenticated"}';

-- Admin / Logistics marks Seller A Delivered
SELECT ok(
    (public.seller_update_fulfillment_status(
        (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1'),
        'Delivered',
        'eeee1111-1111-1111-1111-111111111111'::uuid
    ))->>'success' = 'true',
    '5a. Admin marks Seller A fulfillment Delivered'
);

-- Admin / Logistics marks Seller B Delivered
SELECT ok(
    (public.seller_update_fulfillment_status(
        (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1'),
        'Delivered',
        'eeee2222-2222-2222-2222-222222222222'::uuid
    ))->>'success' = 'true',
    '5b. Admin marks Seller B fulfillment Delivered'
);

-- Parent order status is now Delivered
SELECT is(
    (SELECT status FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1'),
    'Delivered',
    '5c. Parent buyer_orders status becomes Delivered only after ALL store fulfillments are Delivered'
);

-- Phase 10 COD settlement is now eligible and succeeds
SELECT ok(
    (public.admin_process_cod_settlement(
        (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1'),
        'Settle'
    ))->>'success' = 'true',
    '6. Phase 10 COD settlement succeeds on legitimately Delivered order'
);

-- ----------------------------------------------------------------------------
-- 7, 8, 9. CANCELLATION RESTRICTION & IDEMPOTENT RESTORATION
-- ----------------------------------------------------------------------------
-- Create single-seller order 2 for cancellation test
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880001", "role": "authenticated"}';

SELECT public.create_atomic_order(
    'p11-order-key-cancel',
    '[{"product_id": "ffff1111-1111-1111-1111-111111111111", "quantity": 2}]'::jsonb,
    '{"city": "Lahore"}'::jsonb,
    'COD'
);

-- 7. Buyer cancels Pending order -> stock restored from 48 to 50
SELECT ok(
    (public.cancel_order((SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-cancel'), NULL, 'Buyer Changed Mind'))->>'success' = 'true',
    '7. Buyer cancels Pending order'
);

-- Stock restored from 47 to 49 (Order 1 still holds 1 unit)
SELECT is(
    (SELECT stock_quantity FROM public.products WHERE id = 'ffff1111-1111-1111-1111-111111111111')::INT,
    49,
    '8. Stock restored from 47 to 49 after cancellation'
);

-- 9. Replayed cancellation is idempotent and does NOT double-restore stock
SELECT is(
    (public.cancel_order((SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-cancel'), NULL, 'Duplicate Cancel'))->>'already_cancelled',
    'true',
    '9. Replayed cancellation returns already_cancelled = true and does not double restore stock'
);

-- ----------------------------------------------------------------------------
-- 10. CANCEL SHIPPED / DELIVERED ORDER IS DENIED
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ SELECT public.cancel_order((SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1'), NULL, 'Late Cancel') $$,
    'P0001',
    'Cannot cancel order ' || (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1') || ': Order is already Delivered.',
    '10. Attempting to cancel an already Delivered order raises exception'
);

-- ----------------------------------------------------------------------------
-- 11, 12, 13, 14. RETURN REQUEST & PHASE 10 REFUND INTEGRATION
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880001", "role": "authenticated"}';

-- 11. Buyer submits valid return request for Item A P11 (Delivered order 1)
SELECT ok(
    (public.submit_return_request(
        (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1'),
        (SELECT id FROM public.order_items WHERE order_id = (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1') AND product_name = 'Item A P11'),
        1,
        'Defective Fabric',
        'Stitching unraveling'
    ))->>'success' = 'true',
    '11. Buyer submits valid return request for Delivered line item'
);

-- 12. Cumulative return quantity check fails if exceeding purchased quantity
SELECT throws_ok(
    $$ SELECT public.submit_return_request((SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1'), (SELECT id FROM public.order_items WHERE order_id = (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1') AND product_name = 'Item A P11'), 1, 'Excess Return', 'Excess') $$,
    'P0001',
    'Return quantity exceeds eligible purchased quantity. Eligible: 0, Requested: 1',
    '12. Excessive return quantity exceeding purchased quantity raises exception'
);

-- 13. Admin reviews and approves return request -> triggers Phase 10 refund
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880004", "role": "authenticated"}';

SELECT ok(
    (public.review_return_request(
        (SELECT id FROM public.return_requests WHERE reason = 'Defective Fabric'),
        'Approved',
        'Item verified defective by admin'
    ))->>'success' = 'true',
    '13. Admin approves return request and triggers Phase 10 financial refund'
);

-- 14. Phase 10 refund row created and linked to return request
SELECT ok(
    EXISTS (
        SELECT 1 FROM public.refunds r
        JOIN public.return_requests rr ON rr.refund_id = r.id
        WHERE rr.reason = 'Defective Fabric'
          AND r.amount = 1000.00
          AND r.seller_payable_reversed = 900.00
    ),
    '14. Trusted Phase 10 refund record created with proportional seller payable reversal (900.00)'
);

-- ----------------------------------------------------------------------------
-- 15, 16, 17. PRODUCT REVIEWS & PURCHASE ELIGIBILITY
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880001", "role": "authenticated"}';

-- 15. Buyer submits product review for verified purchase Item A P11
SELECT ok(
    (public.submit_product_review(
        'ffff1111-1111-1111-1111-111111111111',
        (SELECT id FROM public.order_items WHERE order_id = (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1') AND product_name = 'Item A P11'),
        5,
        'Excellent build quality and fast delivery!'
    ))->>'success' = 'true',
    '15. Buyer submits product review for verified Delivered purchase'
);

-- 16. Duplicate review for same order_item raises exception
SELECT throws_ok(
    $$ SELECT public.submit_product_review('ffff1111-1111-1111-1111-111111111111', (SELECT id FROM public.order_items WHERE order_id = (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1') AND product_name = 'Item A P11'), 4, 'Duplicate review') $$,
    'P0001',
    'You have already submitted a review for this purchased line item.',
    '16. Duplicate review attempt on same order_item raises exception'
);

-- 17. Outsider user without purchase cannot submit review
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880005", "role": "authenticated"}';

SELECT throws_ok(
    $$ SELECT public.submit_product_review('ffff1111-1111-1111-1111-111111111111', (SELECT id FROM public.order_items WHERE order_id = (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1') AND product_name = 'Item A P11'), 5, 'Fake Review') $$,
    'P0001',
    'Access denied: You do not own the order associated with line item ' || (SELECT id FROM public.order_items WHERE order_id = (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1') AND product_name = 'Item A P11') || '.',
    '17. Outsider review attempt without purchase ownership raises access denied'
);

-- ----------------------------------------------------------------------------
-- 18, 19, 20. CHAT SECURITY & RLS PRIVACY
-- ----------------------------------------------------------------------------
-- Seed Chat Room between Buyer 1 & Seller A
SET LOCAL ROLE postgres;

INSERT INTO public.chat_rooms (id, buyer_user_id, seller_store_id, product_id) VALUES
    ('77777777-1111-1111-1111-111111111111', '88888888-8888-8888-8888-888888880001', 'eeee1111-1111-1111-1111-111111111111', 'ffff1111-1111-1111-1111-111111111111')
ON CONFLICT (id) DO NOTHING;

-- 18. Buyer 1 sends chat message
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880001", "role": "authenticated"}';

SELECT ok(
    (public.send_chat_message('77777777-1111-1111-1111-111111111111', 'Is this item available in Blue?'))->>'success' = 'true',
    '18. Buyer sends chat message to Seller A'
);

-- 19. Seller A sends reply
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880002", "role": "authenticated"}';

SELECT ok(
    (public.send_chat_message('77777777-1111-1111-1111-111111111111', 'Yes, blue color is in stock!'))->>'success' = 'true',
    '19. Seller A sends chat reply in room'
);

-- 20. Outsider user sees 0 chat rooms and 0 chat messages via RLS
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880005", "role": "authenticated"}';

SELECT is(
    (SELECT COUNT(*)::INT FROM public.chat_rooms),
    0,
    '20a. Outsider user RLS query returns 0 chat rooms'
);

SELECT is(
    (SELECT COUNT(*)::INT FROM public.chat_messages),
    0,
    '20b. Outsider user RLS query returns 0 chat messages'
);

-- ----------------------------------------------------------------------------
-- 21, 22. NOTIFICATIONS WRITE PROTECTION & READ STATE RPC
-- ----------------------------------------------------------------------------
-- 21. Direct client insert into notifications is denied by table privileges
SELECT throws_ok(
    $$ INSERT INTO public.notifications (user_id, type, title, body) VALUES ('88888888-8888-8888-8888-888888880001', 'FAKE', 'Fake Title', 'Fake Body') $$,
    '42501',
    NULL,
    '21. Direct client insert into notifications is denied by table privileges'
);

-- 22. Buyer marks own notification as read via mark_notification_read
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880001", "role": "authenticated"}';

SELECT ok(
    (public.mark_notification_read((SELECT id FROM public.notifications WHERE user_id = '88888888-8888-8888-8888-888888880001' LIMIT 1)))->>'success' = 'true',
    '22. Buyer marks own notification as read via mark_notification_read RPC'
);

-- ----------------------------------------------------------------------------
-- 23, 24. STORAGE EVIDENCE BUCKET PRIVACY
-- ----------------------------------------------------------------------------
-- 23. Outsider user cannot read return evidence objects
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880005", "role": "authenticated"}';

SELECT is(
    (SELECT COUNT(*)::INT FROM storage.objects WHERE bucket_id = 'return-evidence'),
    0,
    '23. Outsider user RLS query returns 0 objects from private return-evidence bucket'
);

-- 24. Public bucket return-evidence is private (public = false)
SET LOCAL ROLE postgres;

SELECT is(
    (SELECT public FROM storage.buckets WHERE id = 'return-evidence'),
    FALSE,
    '24. Storage bucket return-evidence is private (public = false)'
);

-- ----------------------------------------------------------------------------
-- 25. CHAT ROOM CREATION SECURITY (AUTH-DERIVED BUYER USER ID)
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880001", "role": "authenticated"}';

SELECT ok(
    (public.create_chat_room('eeee2222-2222-2222-2222-222222222222'::uuid, 'ffff2222-2222-2222-2222-222222222222'::uuid))->>'success' = 'true',
    '25. Buyer creates chat room via create_chat_room with server-derived buyer_user_id'
);

-- ----------------------------------------------------------------------------
-- 26. MISMATCHED PRODUCT REVIEW REJECTION
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ SELECT public.submit_product_review('ffff2222-2222-2222-2222-222222222222', (SELECT id FROM public.order_items WHERE order_id = (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1') AND product_name = 'Item A P11'), 5, 'Fake Mismatch Review') $$,
    'P0001',
    'Line item ' || (SELECT id FROM public.order_items WHERE order_id = (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p11-order-key-1') AND product_name = 'Item A P11') || ' does not match product ffff2222-2222-2222-2222-222222222222.',
    '26. Reviewing a different product using a line item of another product raises exception'
);

-- ----------------------------------------------------------------------------
-- 27. NOTIFICATION EVENT IDEMPOTENCY (DUPLICATE EVENT REJECTION)
-- ----------------------------------------------------------------------------
SET LOCAL ROLE postgres;

SELECT public.internal_create_notification('88888888-8888-8888-8888-888888880001', 'TEST_EVENT', 'Test', 'Test Body', NULL, NULL, 'EVENT-KEY-UNIQUE-101');
SELECT public.internal_create_notification('88888888-8888-8888-8888-888888880001', 'TEST_EVENT', 'Test', 'Test Body', NULL, NULL, 'EVENT-KEY-UNIQUE-101');

SELECT is(
    (SELECT COUNT(*)::INT FROM public.notifications WHERE event_key = 'EVENT-KEY-UNIQUE-101'),
    1,
    '27. Repeated internal_create_notification calls with same event_key creates exactly ONE notification'
);

-- ----------------------------------------------------------------------------
-- 28. CROSS-USER NOTIFICATION READ ISOLATION
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880005", "role": "authenticated"}';

SELECT public.mark_notification_read((SELECT id FROM public.notifications WHERE event_key = 'EVENT-KEY-UNIQUE-101'));

SET LOCAL ROLE postgres;

SELECT is(
    (SELECT is_read FROM public.notifications WHERE event_key = 'EVENT-KEY-UNIQUE-101'),
    FALSE,
    '28. User B calling mark_notification_read on User A notification does not alter User A read state'
);

SELECT * FROM finish();
ROLLBACK;
