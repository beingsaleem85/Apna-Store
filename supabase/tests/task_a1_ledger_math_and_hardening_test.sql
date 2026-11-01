-- ============================================================================
-- SQL Test: Task A1 - Ledger Math, Cron Privileges, Normalization & Shipment Hardening
-- ============================================================================

BEGIN;
SELECT plan(18);

-- ----------------------------------------------------------------------------
-- 0. SEED TEST FIXTURES & USERS
-- ----------------------------------------------------------------------------
INSERT INTO auth.users (id, email) VALUES
    ('90000000-0000-0000-0000-000000000041', 'buyer_m34@test.com'),
    ('90000000-0000-0000-0000-000000000042', 'seller_m34@test.com'),
    ('90000000-0000-0000-0000-000000000043', 'admin_finance_m34@test.com'),
    ('90000000-0000-0000-0000-000000000044', 'admin_shipping_m34@test.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_roles (user_id, role, staff_role) VALUES
    ('90000000-0000-0000-0000-000000000041', 'buyer'::public.app_role, NULL),
    ('90000000-0000-0000-0000-000000000042', 'seller'::public.app_role, NULL),
    ('90000000-0000-0000-0000-000000000043', 'admin'::public.app_role, 'financeAdmin'::public.admin_staff_role),
    ('90000000-0000-0000-0000-000000000044', 'admin'::public.app_role, 'shippingManager'::public.admin_staff_role)
ON CONFLICT (user_id, role) DO UPDATE SET staff_role = EXCLUDED.staff_role;

INSERT INTO public.profiles (id, full_name, email, role, is_deactivated) VALUES
    ('90000000-0000-0000-0000-000000000041', 'Buyer M34', 'buyer_m34@test.com', 'buyer'::public.app_role, FALSE),
    ('90000000-0000-0000-0000-000000000042', 'Seller M34', 'seller_m34@test.com', 'seller'::public.app_role, FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.seller_stores (id, owner_id, name, shop_slug, is_approved, is_suspended, balance) VALUES
    ('91111111-0000-0000-0000-000000000042', '90000000-0000-0000-0000-000000000042', 'Store M34', 'store-m34', TRUE, FALSE, 0.00),
    ('91111111-0000-0000-0000-000000000049', '90000000-0000-0000-0000-000000000042', 'Store Unrelated M34', 'store-unrelated-m34', TRUE, FALSE, 0.00)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.wallet_accounts (id, seller_store_id, owner_id, available_balance, held_balance) VALUES
    ('92222222-0000-0000-0000-000000000042', '91111111-0000-0000-0000-000000000042', '90000000-0000-0000-0000-000000000042', 0.00, 0.00)
ON CONFLICT (seller_store_id) DO NOTHING;

-- Clean any existing wallet_transactions for Store M34 in this transaction
DELETE FROM public.wallet_transactions WHERE seller_store_id = '91111111-0000-0000-0000-000000000042';

-- ----------------------------------------------------------------------------
-- PART 1.1: EXACT NUMERIC LEDGER MATH SEQUENCE
-- ----------------------------------------------------------------------------

-- Step 1: Delivery of Net 1000 -> HOLD 1000
INSERT INTO public.wallet_transactions (
    wallet_account_id, seller_store_id, transaction_type, amount,
    source_type, source_id, idempotency_key, description
) VALUES (
    '92222222-0000-0000-0000-000000000042', '91111111-0000-0000-0000-000000000042',
    'HOLD', 1000.00, 'ORDER_DELIVERED_HELD', 'ORD-TEST-1', 'TXN-STEP-1', 'Order 1 delivered hold'
);

-- Assert Step 1: available = 0.00, held = 1000.00
SELECT is(
    (SELECT available_balance FROM public.get_seller_wallet_summary('91111111-0000-0000-0000-000000000042')),
    0.00,
    'Ledger Step 1: Delivery of Net 1000 yields available_balance = 0.00'
);
SELECT is(
    (SELECT held_balance FROM public.get_seller_wallet_summary('91111111-0000-0000-0000-000000000042')),
    1000.00,
    'Ledger Step 1: Delivery of Net 1000 yields held_balance = 1000.00'
);

-- Step 2: Escrow Maturity -> RELEASE 1000
INSERT INTO public.wallet_transactions (
    wallet_account_id, seller_store_id, transaction_type, amount,
    source_type, source_id, idempotency_key, description
) VALUES (
    '92222222-0000-0000-0000-000000000042', '91111111-0000-0000-0000-000000000042',
    'RELEASE', 1000.00, 'ORDER_DELIVERED_HELD', 'ORD-TEST-1', 'TXN-STEP-2', 'Order 1 escrow release'
);

-- Assert Step 2: available = 1000.00, held = 0.00
SELECT is(
    (SELECT available_balance FROM public.get_seller_wallet_summary('91111111-0000-0000-0000-000000000042')),
    1000.00,
    'Ledger Step 2: Release yields available_balance = 1000.00'
);
SELECT is(
    (SELECT held_balance FROM public.get_seller_wallet_summary('91111111-0000-0000-0000-000000000042')),
    0.00,
    'Ledger Step 2: Release yields held_balance = 0.00'
);

-- Step 3: Payout Disbursed 400 -> DEBIT 400
INSERT INTO public.wallet_transactions (
    wallet_account_id, seller_store_id, transaction_type, amount,
    source_type, source_id, idempotency_key, description
) VALUES (
    '92222222-0000-0000-0000-000000000042', '91111111-0000-0000-0000-000000000042',
    'DEBIT', 400.00, 'PAYOUT_DISBURSEMENT', 'PAY-TEST-1', 'TXN-STEP-3', 'Payout disbursement 400'
);

-- Assert Step 3: available = 600.00, held = 0.00
SELECT is(
    (SELECT available_balance FROM public.get_seller_wallet_summary('91111111-0000-0000-0000-000000000042')),
    600.00,
    'Ledger Step 3: Payout 400 yields available_balance = 600.00'
);

-- Step 4: Refund 200 for a released earning -> DEBIT 200
INSERT INTO public.wallet_transactions (
    wallet_account_id, seller_store_id, transaction_type, amount,
    source_type, source_id, idempotency_key, description
) VALUES (
    '92222222-0000-0000-0000-000000000042', '91111111-0000-0000-0000-000000000042',
    'DEBIT', 200.00, 'REFUND_REVERSAL', 'ORD-TEST-1', 'TXN-STEP-4', 'Refund 200 released earning'
);

-- Assert Step 4: available = 400.00, held = 0.00
SELECT is(
    (SELECT available_balance FROM public.get_seller_wallet_summary('91111111-0000-0000-0000-000000000042')),
    400.00,
    'Ledger Step 4: Refund 200 of released earning yields available_balance = 400.00'
);

-- Step 5: Second order delivered with net 100 -> HOLD 100
INSERT INTO public.wallet_transactions (
    wallet_account_id, seller_store_id, transaction_type, amount,
    source_type, source_id, idempotency_key, description
) VALUES (
    '92222222-0000-0000-0000-000000000042', '91111111-0000-0000-0000-000000000042',
    'HOLD', 100.00, 'ORDER_DELIVERED_HELD', 'ORD-TEST-2', 'TXN-STEP-5', 'Order 2 delivered hold 100'
);

-- Step 6: Refund 100 on still-held earning -> HOLD_VOID 100
INSERT INTO public.wallet_transactions (
    wallet_account_id, seller_store_id, transaction_type, amount,
    source_type, source_id, idempotency_key, description
) VALUES (
    '92222222-0000-0000-0000-000000000042', '91111111-0000-0000-0000-000000000042',
    'HOLD_VOID', 100.00, 'HELD_REFUND_VOID', 'ORD-TEST-2', 'TXN-STEP-6', 'Order 2 held refund void 100'
);

-- Assert Step 6: available remains 400.00, held is reduced to 0.00
SELECT is(
    (SELECT available_balance FROM public.get_seller_wallet_summary('91111111-0000-0000-0000-000000000042')),
    400.00,
    'Ledger Step 6: Refund of still-held earning leaves available_balance unchanged at 400.00'
);
SELECT is(
    (SELECT held_balance FROM public.get_seller_wallet_summary('91111111-0000-0000-0000-000000000042')),
    0.00,
    'Ledger Step 6: Refund of still-held earning reduces held_balance by 100 to 0.00'
);

-- Step 7: Overdraft test - refund of 500 when available is 400 -> available balance becomes -100.00
INSERT INTO public.wallet_transactions (
    wallet_account_id, seller_store_id, transaction_type, amount,
    source_type, source_id, idempotency_key, description
) VALUES (
    '92222222-0000-0000-0000-000000000042', '91111111-0000-0000-0000-000000000042',
    'DEBIT', 500.00, 'REFUND_REVERSAL', 'ORD-OVERDRAFT', 'TXN-STEP-7', 'Post-payout refund driving ledger negative'
);

SELECT is(
    (SELECT available_balance FROM public.get_seller_wallet_summary('91111111-0000-0000-0000-000000000042')),
    -100.00,
    'Ledger Overdraft: Post-payout refund correctly drives available_balance to -100.00'
);

-- ----------------------------------------------------------------------------
-- PART 1.2: FRAUD BLACKLIST NORMALIZATION NOT NULL & ENFORCEMENT
-- ----------------------------------------------------------------------------

-- Verify normalized_value is NOT NULL in table schema
SELECT throws_ok(
    $$INSERT INTO public.fraud_blacklisted_identifiers (identifier_type, identifier_value, normalized_value, threat_level)
      VALUES ('Phone Number', '03001112233', NULL, 'High')$$,
    '23502',
    NULL,
    'Fraud blacklist rejects NULL normalized_value'
);

-- Verify pre-existing or newly inserted normalized phone enforces deduplication and lookup
SELECT is(
    public.normalize_phone_pk('0300-1234567'),
    '+923001234567',
    'Normalization helper produces canonical E.164 +92 format'
);

-- ----------------------------------------------------------------------------
-- PART 1.3: ESCROW RELEASE PRIVILEGES & SECURITY GATES
-- ----------------------------------------------------------------------------

-- Unprivileged buyer calling admin_release_held_seller_earnings is rejected (42501)
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "90000000-0000-0000-0000-000000000041", "role": "authenticated"}';

SELECT throws_ok(
    $$SELECT public.admin_release_held_seller_earnings('ORD-TEST-1', '91111111-0000-0000-0000-000000000042')$$,
    '42501',
    'Access denied: Insufficient privileges to release held earnings.',
    'Unprivileged buyer cannot call admin_release_held_seller_earnings'
);

-- Unprivileged buyer calling release_mature_held_seller_earnings directly is rejected (42501 permission denied)
SELECT throws_ok(
    $$SELECT public.release_mature_held_seller_earnings()$$,
    '42501',
    NULL,
    'Unprivileged caller has EXECUTE REVOKED on release_mature_held_seller_earnings'
);

RESET ROLE;

-- ----------------------------------------------------------------------------
-- PART 1.4: SHIPMENT ASSIGNMENT HARDENING & VALIDATIONS
-- ----------------------------------------------------------------------------

-- Seed test order & courier
INSERT INTO public.shipping_courier_partners (id, code, name, base_rate, extra_kg_rate, tracking_url_template, is_active) VALUES
    ('98888888-0000-0000-0000-000000000001', 'TEST_ACTIVE', 'Test Active Express', 150.00, 50.00, 'https://test.com/{TRACKING}', TRUE),
    ('98888888-0000-0000-0000-000000000002', 'TEST_INACTIVE', 'Test Inactive Cargo', 150.00, 50.00, 'https://test.com/{TRACKING}', FALSE)
ON CONFLICT (code) DO NOTHING;

INSERT INTO public.products (id, seller_store_id, name, sku, regular_price, stock_quantity, is_active, approval_status) VALUES
    ('93333333-0000-0000-0000-000000000042', '91111111-0000-0000-0000-000000000042', 'Shipment Product M34', 'SKU-SHIP-34', 500.00, 20, TRUE, 'approved')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.buyer_orders (id, customer_user_id, order_number, status, payment_status, payment_method, total_amount, shipping_fee, grand_total, idempotency_key) VALUES
    ('ORD-SHIP-PENDING', '90000000-0000-0000-0000-000000000041', 'ORD-SH-1', 'Pending', 'Pending', 'Cash on Delivery', 500.00, 150.00, 650.00, 'IDEMP-SH-1'),
    ('ORD-SHIP-PROCESSING', '90000000-0000-0000-0000-000000000041', 'ORD-SH-2', 'Processing', 'Pending', 'Cash on Delivery', 500.00, 150.00, 650.00, 'IDEMP-SH-2')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.order_items (id, order_id, product_id, seller_store_id, product_name, sku, unit_price, quantity, total_price, commission_rate, commission_amount, seller_payable) VALUES
    ('94444444-0000-0000-0000-000000000042', 'ORD-SHIP-PROCESSING', '93333333-0000-0000-0000-000000000042', '91111111-0000-0000-0000-000000000042', 'Shipment Product M34', 'SKU-SHIP-34', 500.00, 1, 500.00, 10.00, 50.00, 450.00)
ON CONFLICT (id) DO NOTHING;

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "90000000-0000-0000-0000-000000000044", "role": "authenticated"}';

-- Validation 1: Inactive courier rejected
SELECT throws_ok(
    $$SELECT public.admin_assign_order_shipment('ORD-SHIP-PROCESSING', '91111111-0000-0000-0000-000000000042', '98888888-0000-0000-0000-000000000002', 'TRACK-12345')$$,
    '22023',
    'Courier partner not found or inactive.',
    'Shipment assignment rejects inactive courier'
);

-- Validation 2: Invalid tracking format rejected
SELECT throws_ok(
    $$SELECT public.admin_assign_order_shipment('ORD-SHIP-PROCESSING', '91111111-0000-0000-0000-000000000042', '98888888-0000-0000-0000-000000000001', 'TR@CK!$#*')$$,
    '22023',
    'Invalid tracking number format: Must be 4-64 alphanumeric characters.',
    'Shipment assignment rejects invalid tracking number format'
);

-- Validation 3: Order not in Processing/Shipped state (e.g. Pending) rejected
SELECT throws_ok(
    $$SELECT public.admin_assign_order_shipment('ORD-SHIP-PENDING', '91111111-0000-0000-0000-000000000042', '98888888-0000-0000-0000-000000000001', 'TRACK-12345')$$,
    '22023',
    'Order ORD-SHIP-PENDING is in "Pending" status. Shipments can only be assigned to orders in Processing or Shipped status.',
    'Shipment assignment rejects order not in Processing or Shipped state'
);

-- Validation 4: Store has no items in order rejected
SELECT throws_ok(
    $$SELECT public.admin_assign_order_shipment('ORD-SHIP-PROCESSING', '91111111-0000-0000-0000-000000000049', '98888888-0000-0000-0000-000000000001', 'TRACK-12345')$$,
    '22023',
    'Store 91111111-0000-0000-0000-000000000049 has no items in order ORD-SHIP-PROCESSING.',
    'Shipment assignment rejects store with no items in target order'
);

-- Validation 5: Valid assignment succeeds
SELECT lives_ok(
    $$SELECT public.admin_assign_order_shipment('ORD-SHIP-PROCESSING', '91111111-0000-0000-0000-000000000042', '98888888-0000-0000-0000-000000000001', 'TRACK-12345')$$,
    'Valid shipment assignment succeeds'
);

RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
