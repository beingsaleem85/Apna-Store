-- ============================================================================
-- PGTAP TEST SUITE: TASK 1 INTERIM PAYMENT SAFETY GUARD
-- File: supabase/tests/task1_payment_safety_test.sql
-- ============================================================================

BEGIN;

SELECT plan(8);

-- ----------------------------------------------------------------------------
-- SETUP: Seed Test Buyer, Store & Product
-- ----------------------------------------------------------------------------

INSERT INTO auth.users (id, email) VALUES
    ('11111111-1111-1111-1111-111111110001', 'buyer_t1@example.com'),
    ('11111111-1111-1111-1111-111111110002', 'seller_t1@example.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, full_name, email) VALUES
    ('11111111-1111-1111-1111-111111110001', 'Buyer T1', 'buyer_t1@example.com'),
    ('11111111-1111-1111-1111-111111110002', 'Seller T1', 'seller_t1@example.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_roles (user_id, role, granted_at) VALUES
    ('11111111-1111-1111-1111-111111110001', 'buyer'::public.app_role, NOW()),
    ('11111111-1111-1111-1111-111111110002', 'seller'::public.app_role, NOW())
ON CONFLICT (user_id, role) DO NOTHING;

INSERT INTO public.seller_stores (id, owner_id, shop_name, shop_slug, is_approved, is_suspended, commission_rate) VALUES
    ('22222222-2222-2222-2222-222222220001', '11111111-1111-1111-1111-111111110002', 'Safety Test Store', 'safety-test-store', TRUE, FALSE, 10.00)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.products (id, seller_store_id, name, price, stock_quantity, approval_status, is_active) VALUES
    ('33333333-3333-3333-3333-333333330001', '22222222-2222-2222-2222-222222220001', 'Safety Product', 500.00, 50, 'Approved', TRUE)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- Authenticate as Buyer
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "11111111-1111-1111-1111-111111110001", "role": "authenticated"}';

-- Test 1: JazzCash order creation must be rejected
SELECT throws_matching(
    $$
    SELECT public.create_atomic_order(
        '[{"product_id": "33333333-3333-3333-3333-333333330001", "quantity": 1}]'::jsonb,
        '{"recipient_name": "Buyer T1", "address_line": "123 Street"}'::jsonb,
        'JazzCash',
        'idemp_jc_001'
    );
    $$,
    'Online payments are not available yet',
    'create_atomic_order rejects JazzCash payment method'
);

-- Test 2: Easypaisa order creation must be rejected
SELECT throws_matching(
    $$
    SELECT public.create_atomic_order(
        '[{"product_id": "33333333-3333-3333-3333-333333330001", "quantity": 1}]'::jsonb,
        '{"recipient_name": "Buyer T1", "address_line": "123 Street"}'::jsonb,
        'Easypaisa',
        'idemp_ep_001'
    );
    $$,
    'Online payments are not available yet',
    'create_atomic_order rejects Easypaisa payment method'
);

-- Test 3: Debit/Credit Card order creation must be rejected
SELECT throws_matching(
    $$
    SELECT public.create_atomic_order(
        '[{"product_id": "33333333-3333-3333-3333-333333330001", "quantity": 1}]'::jsonb,
        '{"recipient_name": "Buyer T1", "address_line": "123 Street"}'::jsonb,
        'Debit/Credit Card',
        'idemp_card_001'
    );
    $$,
    'Online payments are not available yet',
    'create_atomic_order rejects Debit/Credit Card payment method'
);

-- Test 4: Card order creation must be rejected
SELECT throws_matching(
    $$
    SELECT public.create_atomic_order(
        '[{"product_id": "33333333-3333-3333-3333-333333330001", "quantity": 1}]'::jsonb,
        '{"recipient_name": "Buyer T1", "address_line": "123 Street"}'::jsonb,
        'Card',
        'idemp_card_002'
    );
    $$,
    'Online payments are not available yet',
    'create_atomic_order rejects generic Card payment method'
);

-- Test 5: NULL payment method must be rejected
SELECT throws_matching(
    $$
    SELECT public.create_atomic_order(
        '[{"product_id": "33333333-3333-3333-3333-333333330001", "quantity": 1}]'::jsonb,
        '{"recipient_name": "Buyer T1", "address_line": "123 Street"}'::jsonb,
        NULL,
        'idemp_null_001'
    );
    $$,
    'Online payments are not available yet',
    'create_atomic_order rejects NULL payment method'
);

-- Test 6: Cash on Delivery must succeed
PREPARE cod_order AS
    SELECT public.create_atomic_order(
        '[{"product_id": "33333333-3333-3333-3333-333333330001", "quantity": 1}]'::jsonb,
        '{"recipient_name": "Buyer T1", "address_line": "123 Street"}'::jsonb,
        'Cash on Delivery',
        'idemp_cod_001'
    );

SELECT lives_ok('cod_order', 'create_atomic_order succeeds for Cash on Delivery');

-- Test 7: COD order must have payment_status = Pending in database
SELECT is(
    (SELECT payment_status FROM public.buyer_orders WHERE idempotency_key = 'idemp_cod_001'),
    'Pending',
    'COD order is saved with payment_status = Pending'
);

-- Test 8: COD tracking event states order will be paid on delivery
SELECT is(
    (SELECT description FROM public.order_tracking_events WHERE order_id = (
        SELECT id FROM public.buyer_orders WHERE idempotency_key = 'idemp_cod_001'
    ) LIMIT 1),
    'Your order has been placed and will be paid on delivery via Cash on Delivery.',
    'Tracking event states payment on delivery for COD'
);

SELECT * FROM finish();
ROLLBACK;
