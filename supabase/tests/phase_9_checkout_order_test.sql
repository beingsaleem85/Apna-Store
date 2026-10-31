-- ============================================================================
-- PGTAP TEST SUITE: PHASE 9 CART, ATOMIC CHECKOUT & ORDER CREATION TESTS
-- File: supabase/tests/phase_9_checkout_order_test.sql
-- ============================================================================

BEGIN;

SELECT plan(33);

-- ----------------------------------------------------------------------------
-- SETUP: Seed Test Users, Stores, Categories, Products & Variants
-- ----------------------------------------------------------------------------

-- Seed auth users
INSERT INTO auth.users (id, email) VALUES
    ('99999999-9999-9999-9999-999999990001', 'buyer_p9@example.com'),
    ('99999999-9999-9999-9999-999999990002', 'seller_a_p9@example.com'),
    ('99999999-9999-9999-9999-999999990003', 'seller_b_p9@example.com'),
    ('99999999-9999-9999-9999-999999990004', 'admin_p9@example.com'),
    ('99999999-9999-9999-9999-999999990005', 'buyer_b_p9@example.com')
ON CONFLICT (id) DO NOTHING;

-- Seed user profiles
INSERT INTO public.profiles (id, full_name, email) VALUES
    ('99999999-9999-9999-9999-999999990001', 'Buyer P9 Test', 'buyer_p9@example.com'),
    ('99999999-9999-9999-9999-999999990002', 'Seller A P9 Test', 'seller_a_p9@example.com'),
    ('99999999-9999-9999-9999-999999990003', 'Seller B P9 Test', 'seller_b_p9@example.com'),
    ('99999999-9999-9999-9999-999999990004', 'Admin P9 Test', 'admin_p9@example.com'),
    ('99999999-9999-9999-9999-999999990005', 'Buyer B P9 Test', 'buyer_b_p9@example.com')
ON CONFLICT (id) DO NOTHING;

-- Seed user roles
INSERT INTO public.user_roles (user_id, role, granted_at) VALUES
    ('99999999-9999-9999-9999-999999990001', 'buyer'::public.app_role, NOW()),
    ('99999999-9999-9999-9999-999999990002', 'seller'::public.app_role, NOW() + INTERVAL '1 sec'),
    ('99999999-9999-9999-9999-999999990003', 'seller'::public.app_role, NOW() + INTERVAL '2 sec'),
    ('99999999-9999-9999-9999-999999990004', 'super_admin'::public.app_role, NOW() + INTERVAL '3 sec'),
    ('99999999-9999-9999-9999-999999990005', 'buyer'::public.app_role, NOW() + INTERVAL '4 sec')
ON CONFLICT (user_id, role) DO UPDATE SET granted_at = EXCLUDED.granted_at;

-- Seed Seller Stores
INSERT INTO public.seller_stores (id, owner_id, shop_name, shop_slug, is_approved, is_suspended, commission_rate) VALUES
    ('aaaa3333-3333-3333-3333-333333333333', '99999999-9999-9999-9999-999999990002', 'Seller A Store P9', 'seller-a-store-p9', TRUE, FALSE, 10.00),
    ('aaaa4444-4444-4444-4444-444444444444', '99999999-9999-9999-9999-999999990003', 'Seller B Store P9', 'seller-b-store-p9', TRUE, FALSE, 12.50)
ON CONFLICT (id) DO NOTHING;

-- Seed Products
INSERT INTO public.products (id, seller_store_id, name, price, sale_price, stock_quantity, approval_status, is_active) VALUES
    ('bbbb4444-4444-4444-4444-444444444444', 'aaaa3333-3333-3333-3333-333333333333', 'Product A1 P9', 200.00, 180.00, 10, 'Approved', TRUE),
    ('bbbb5555-5555-5555-5555-555555555555', 'aaaa4444-4444-4444-4444-444444444444', 'Product B1 P9', 300.00, NULL, 5, 'Approved', TRUE),
    ('bbbb6666-6666-6666-6666-666666666666', 'aaaa3333-3333-3333-3333-333333333333', 'Draft Product P9', 100.00, NULL, 10, 'Draft', TRUE),
    ('bbbb7777-7777-7777-7777-777777777777', 'aaaa3333-3333-3333-3333-333333333333', 'Out of Stock Product P9', 50.00, NULL, 0, 'Approved', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Seed Variant
INSERT INTO public.product_variants (id, product_id, seller_store_id, sku, variant_name, price_override, stock_quantity, is_active) VALUES
    ('dddd1111-1111-1111-1111-111111111111', 'bbbb4444-4444-4444-4444-444444444444', 'aaaa3333-3333-3333-3333-333333333333', 'SKU-A1-BLUE', 'Blue Variant', 170.00, 4, TRUE)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 1. TEST: Unauthenticated user checkout fails
-- ----------------------------------------------------------------------------
SET LOCAL ROLE anon;

SELECT throws_ok(
    $$ SELECT public.create_atomic_order('key-anon-1', '[{"product_id": "bbbb4444-4444-4444-4444-444444444444", "quantity": 1}]'::jsonb, '{}'::jsonb) $$,
    'P0001',
    NULL,
    '1. Unauthenticated user checkout raises access denied exception'
);

-- ----------------------------------------------------------------------------
-- 2. TEST: Client cannot directly INSERT into buyer_orders
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "99999999-9999-9999-9999-999999990001", "role": "authenticated"}';

SELECT throws_ok(
    $$ INSERT INTO public.buyer_orders (id, customer_name, customer_email, amount, payment_method) VALUES ('fake-id-1', 'Malicious Buyer', 'fake@example.com', 0.01, 'COD') $$,
    '42501',
    NULL,
    '2. Direct client insert into buyer_orders is denied by table privileges'
);

-- ----------------------------------------------------------------------------
-- 3. TEST: Direct INSERT into order_items is denied
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ INSERT INTO public.order_items (order_id, product_id, seller_store_id, product_name, sku, unit_price, quantity, total_price) VALUES ('fake-id-1', 'bbbb4444-4444-4444-4444-444444444444', 'aaaa3333-3333-3333-3333-333333333333', 'Fake Item', 'SKU-FAKE', 1.00, 1, 1.00) $$,
    '42501',
    NULL,
    '3. Direct client insert into order_items is denied by table privileges'
);

-- ----------------------------------------------------------------------------
-- 4. TEST: Direct INSERT into order_status_history is denied
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ INSERT INTO public.order_status_history (order_id, status) VALUES ('fake-id-1', 'Delivered') $$,
    '42501',
    NULL,
    '4. Direct client insert into order_status_history is denied by table privileges'
);

-- ----------------------------------------------------------------------------
-- 5. TEST: Direct client UPDATE on buyer_orders is denied
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ UPDATE public.buyer_orders SET grand_total = 0.00 WHERE customer_user_id = '99999999-9999-9999-9999-999999990001' $$,
    '42501',
    NULL,
    '5. Direct client UPDATE on buyer_orders financial/status columns is denied'
);

-- ----------------------------------------------------------------------------
-- 6. TEST: Server-Side Payment Method Gate (Unintegrated methods fail)
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ SELECT public.create_atomic_order('key-invalid-pm', '[{"product_id": "bbbb4444-4444-4444-4444-444444444444", "quantity": 1}]'::jsonb, '{}'::jsonb, 'FakeGateway') $$,
    'P0001',
    NULL,
    '6a. Arbitrary unsupported payment method raises exception'
);

SELECT throws_ok(
    $$ SELECT public.create_atomic_order('key-jc-pm', '[{"product_id": "bbbb4444-4444-4444-4444-444444444444", "quantity": 1}]'::jsonb, '{}'::jsonb, 'JazzCash') $$,
    'P0001',
    'Payment method JazzCash is not currently available.',
    '6b. JazzCash direct RPC checkout fails server-side gate'
);

SELECT throws_ok(
    $$ SELECT public.create_atomic_order('key-ep-pm', '[{"product_id": "bbbb4444-4444-4444-4444-444444444444", "quantity": 1}]'::jsonb, '{}'::jsonb, 'EasyPaisa') $$,
    'P0001',
    'Payment method EasyPaisa is not currently available.',
    '6c. EasyPaisa direct RPC checkout fails server-side gate'
);

SELECT throws_ok(
    $$ SELECT public.create_atomic_order('key-card-pm', '[{"product_id": "bbbb4444-4444-4444-4444-444444444444", "quantity": 1}]'::jsonb, '{}'::jsonb, 'Card') $$,
    'P0001',
    'Payment method Card is not currently available.',
    '6d. Card direct RPC checkout fails server-side gate'
);

SELECT is(
    (SELECT COUNT(*)::INT FROM public.buyer_orders WHERE idempotency_key IN ('key-invalid-pm', 'key-jc-pm', 'key-ep-pm', 'key-card-pm')),
    0,
    '6e. Rejected payment attempts create 0 buyer_orders and zero artifacts'
);

-- ----------------------------------------------------------------------------
-- 7. TEST: Empty cart items array fails
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ SELECT public.create_atomic_order('key-empty-cart', '[]'::jsonb, '{}'::jsonb, 'COD') $$,
    'P0001',
    NULL,
    '7. Empty cart items array raises exception'
);

-- ----------------------------------------------------------------------------
-- 8. TEST: Unapproved / Draft product checkout fails
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ SELECT public.create_atomic_order('key-draft-prd', '[{"product_id": "bbbb6666-6666-6666-6666-666666666666", "quantity": 1}]'::jsonb, '{}'::jsonb, 'COD') $$,
    'P0001',
    NULL,
    '8. Unapproved or Draft product checkout fails'
);

-- ----------------------------------------------------------------------------
-- 9. TEST: Out-of-stock product checkout fails
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ SELECT public.create_atomic_order('key-out-of-stock', '[{"product_id": "bbbb7777-7777-7777-7777-777777777777", "quantity": 1}]'::jsonb, '{}'::jsonb, 'COD') $$,
    'P0001',
    NULL,
    '9. Out-of-stock product checkout fails'
);

-- ----------------------------------------------------------------------------
-- 10. TEST: Multi-seller successful atomic checkout creates order & updates stock (COD)
-- ----------------------------------------------------------------------------
SELECT ok(
    (public.create_atomic_order(
        'key-valid-checkout-1',
        '[{"product_id": "bbbb4444-4444-4444-4444-444444444444", "quantity": 2}, {"product_id": "bbbb5555-5555-5555-5555-555555555555", "quantity": 1}]'::jsonb,
        '{"city": "Lahore"}'::jsonb,
        'COD'
    ))->>'success' = 'true',
    '10. Valid multi-seller atomic COD checkout RPC returns success'
);

-- ----------------------------------------------------------------------------
-- 11. TEST: Server calculated subtotal, shipping, and grand total correctly
-- ----------------------------------------------------------------------------
-- Product A1: sale_price 180.00 * 2 = 360.00. Product B1: price 300.00 * 1 = 300.00. Subtotal = 660.00. Shipping = 150.00. Grand Total = 810.00.
SELECT is(
    (SELECT grand_total FROM public.buyer_orders WHERE idempotency_key = 'key-valid-checkout-1'),
    810.00,
    '11. Server calculated authoritative subtotal (660.00) + shipping (150.00) = grand total (810.00)'
);

-- ----------------------------------------------------------------------------
-- 12 & 13. TEST: Stock correctly decremented (Product A1: 10 -> 8, Product B1: 5 -> 4)
-- ----------------------------------------------------------------------------
SELECT is(
    (SELECT stock_quantity FROM public.products WHERE id = 'bbbb4444-4444-4444-4444-444444444444'),
    8,
    '12. Product A1 stock atomically decremented from 10 to 8'
);

SELECT is(
    (SELECT stock_quantity FROM public.products WHERE id = 'bbbb5555-5555-5555-5555-555555555555'),
    4,
    '13. Product B1 stock atomically decremented from 5 to 4'
);

-- ----------------------------------------------------------------------------
-- 14. TEST: Payment Status remains Pending (Unpaid intent)
-- ----------------------------------------------------------------------------
SELECT is(
    (SELECT payment_status FROM public.buyer_orders WHERE idempotency_key = 'key-valid-checkout-1'),
    'Pending',
    '14. Payment status is Pending for COD checkout'
);

-- ----------------------------------------------------------------------------
-- 15 & 16. TEST: Idempotency Protection: Duplicate request with SAME payload returns original order
-- ----------------------------------------------------------------------------
SELECT is(
    (public.create_atomic_order(
        'key-valid-checkout-1',
        '[{"product_id": "bbbb4444-4444-4444-4444-444444444444", "quantity": 2}, {"product_id": "bbbb5555-5555-5555-5555-555555555555", "quantity": 1}]'::jsonb,
        '{"city": "Lahore"}'::jsonb,
        'COD'
    ))->>'idempotent_reused',
    'true',
    '15. Duplicate checkout request with same key AND payload returns idempotent_reused = true'
);

SELECT is(
    (SELECT stock_quantity FROM public.products WHERE id = 'bbbb4444-4444-4444-4444-444444444444'),
    8,
    '16. Replayed idempotent request does not decrement stock again'
);

-- ----------------------------------------------------------------------------
-- 17. TEST: Idempotency Conflict: Same key with DIFFERENT payload throws exception
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ SELECT public.create_atomic_order('key-valid-checkout-1', '[{"product_id": "bbbb4444-4444-4444-4444-444444444444", "quantity": 1}]'::jsonb, '{"city": "Lahore"}'::jsonb, 'COD') $$,
    'P0001',
    NULL,
    '17. Same idempotency key with DIFFERENT payload throws idempotency conflict exception'
);

-- ----------------------------------------------------------------------------
-- 18. TEST: Buyer-Scoped Idempotency: Buyer B can use SAME idempotency key as Buyer A
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "99999999-9999-9999-9999-999999990005", "role": "authenticated"}';

SELECT ok(
    (public.create_atomic_order(
        'key-valid-checkout-1',
        '[{"product_id": "bbbb4444-4444-4444-4444-444444444444", "quantity": 1}]'::jsonb,
        '{"city": "Karachi"}'::jsonb,
        'COD'
    ))->>'success' = 'true',
    '18. Buyer B can use SAME idempotency key (key-valid-checkout-1) as Buyer A independently'
);

-- Re-switch back to Buyer A context
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "99999999-9999-9999-9999-999999990001", "role": "authenticated"}';

-- ----------------------------------------------------------------------------
-- 19. TEST: Variant Stock Decrement & Price Override
-- ----------------------------------------------------------------------------
SELECT ok(
    (public.create_atomic_order(
        'key-variant-checkout-1',
        '[{"product_id": "bbbb4444-4444-4444-4444-444444444444", "variant_id": "dddd1111-1111-1111-1111-111111111111", "quantity": 2}]'::jsonb,
        '{}'::jsonb,
        'COD'
    ))->>'success' = 'true',
    '19. Variant checkout RPC succeeds & decrements variant stock'
);

-- ----------------------------------------------------------------------------
-- 20. TEST: Duplicate Cart Lines Normalized
-- ----------------------------------------------------------------------------
SELECT ok(
    (public.create_atomic_order(
        'key-dup-lines-1',
        '[{"product_id": "bbbb4444-4444-4444-4444-444444444444", "quantity": 1}, {"product_id": "bbbb4444-4444-4444-4444-444444444444", "quantity": 1}]'::jsonb,
        '{}'::jsonb,
        'COD'
    ))->>'success' = 'true',
    '20. Duplicate cart lines normalized & decrements product stock correctly'
);

-- Current Product A1 stock after all checkouts (10 - 2 - 1 - 2 = 5)
SELECT is(
    (SELECT stock_quantity FROM public.products WHERE id = 'bbbb4444-4444-4444-4444-444444444444'),
    5,
    '20b. Product A1 stock is 5 after normalized checkouts'
);

-- ----------------------------------------------------------------------------
-- 21 & 22. TEST: Seller Isolation: Seller A cannot see Seller B items
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "99999999-9999-9999-9999-999999990002", "role": "authenticated"}';

SELECT is(
    (SELECT COUNT(*)::INT FROM public.order_items WHERE seller_store_id = 'aaaa4444-4444-4444-4444-444444444444'),
    0,
    '21. Seller A RLS query returns ZERO order items for Seller B store'
);

SELECT is(
    (SELECT COUNT(*)::INT FROM public.order_items WHERE seller_store_id = 'aaaa3333-3333-3333-3333-333333333333'),
    4,
    '22. Seller A RLS query returns ONLY own store order items'
);

-- ----------------------------------------------------------------------------
-- 23, 24, 25. TEST: Buyer Order Privacy RLS
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "99999999-9999-9999-9999-999999990005", "role": "authenticated"}';

SELECT is(
    (SELECT COUNT(*)::INT FROM public.buyer_orders WHERE customer_user_id = '99999999-9999-9999-9999-999999990001'),
    0,
    '23. Buyer B RLS query returns ZERO buyer_orders for Buyer A'
);

SELECT is(
    (SELECT COUNT(*)::INT FROM public.order_items oi JOIN public.buyer_orders bo ON bo.id = oi.order_id WHERE bo.customer_user_id = '99999999-9999-9999-9999-999999990001'),
    0,
    '24. Buyer B RLS query returns ZERO order_items for Buyer A'
);

SELECT is(
    (SELECT COUNT(*)::INT FROM public.order_status_history osh JOIN public.buyer_orders bo ON bo.id = osh.order_id WHERE bo.customer_user_id = '99999999-9999-9999-9999-999999990001'),
    0,
    '25. Buyer B RLS query returns ZERO order_status_history for Buyer A'
);

-- ----------------------------------------------------------------------------
-- 26, 27, 28. TEST: Genuine Post-Stock-Mutation Rollback Confirmation
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "99999999-9999-9999-9999-999999990001", "role": "authenticated"}';

-- Submit multi-line checkout: Line 1 (Product A1, 1 unit -> stock mutation occurs 5 -> 4), Line 2 (Out of stock Product B1, 10 units -> fails!)
SELECT throws_ok(
    $$ SELECT public.create_atomic_order('key-rollback-post-mutation', '[{"product_id": "bbbb4444-4444-4444-4444-444444444444", "quantity": 1}, {"product_id": "bbbb5555-5555-5555-5555-555555555555", "quantity": 10}]'::jsonb, '{}'::jsonb, 'COD') $$,
    'P0001',
    NULL,
    '26. Genuine Post-Stock-Mutation Rollback: Excessive quantity on 2nd line causes complete transaction rollback'
);

-- Verify stock of Product A1 was restored back to 5
SELECT is(
    (SELECT stock_quantity FROM public.products WHERE id = 'bbbb4444-4444-4444-4444-444444444444'),
    5,
    '27. Post-Stock-Mutation Rollback: Product A1 stock remains restored at 5'
);

-- Verify zero buyer_orders created for failed request
SELECT is(
    (SELECT COUNT(*)::INT FROM public.buyer_orders WHERE idempotency_key = 'key-rollback-post-mutation'),
    0,
    '28. Post-Stock-Mutation Rollback: Zero buyer_orders created for failed request'
);

SELECT * FROM finish();
ROLLBACK;
