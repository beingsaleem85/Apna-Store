-- ============================================================================
-- SQL Test: Task A1 - Shipping Governance, Store Refund Eligibility & Normalization
-- ============================================================================

BEGIN;
SELECT plan(14);

-- ----------------------------------------------------------------------------
-- 0. SEED TEST FIXTURES & USERS
-- ----------------------------------------------------------------------------
INSERT INTO auth.users (id, email) VALUES
    ('90000000-0000-0000-0000-000000000021', 'buyer_m33@test.com'),
    ('90000000-0000-0000-0000-000000000022', 'seller_alpha_m33@test.com'),
    ('90000000-0000-0000-0000-000000000023', 'seller_beta_m33@test.com'),
    ('90000000-0000-0000-0000-000000000030', 'ordermanager_m33@test.com'),
    ('90000000-0000-0000-0000-000000000031', 'disputemanager_m33@test.com'),
    ('90000000-0000-0000-0000-000000000032', 'supportadmin_m33@test.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.user_roles (user_id, role, staff_role) VALUES
    ('90000000-0000-0000-0000-000000000021', 'buyer'::public.app_role, NULL),
    ('90000000-0000-0000-0000-000000000022', 'seller'::public.app_role, NULL),
    ('90000000-0000-0000-0000-000000000023', 'seller'::public.app_role, NULL),
    ('90000000-0000-0000-0000-000000000030', 'admin'::public.app_role, 'orderManager'::public.admin_staff_role),
    ('90000000-0000-0000-0000-000000000031', 'admin'::public.app_role, 'disputeManager'::public.admin_staff_role),
    ('90000000-0000-0000-0000-000000000032', 'admin'::public.app_role, 'supportAdmin'::public.admin_staff_role)
ON CONFLICT (user_id, role) DO UPDATE SET staff_role = EXCLUDED.staff_role;

INSERT INTO public.profiles (id, full_name, email, role, phone, is_deactivated) VALUES
    ('90000000-0000-0000-0000-000000000021', 'Buyer M33', 'buyer_m33@test.com', 'buyer'::public.app_role, '+923007778899', FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.seller_stores (id, owner_id, name, shop_slug, is_approved, is_suspended, balance) VALUES
    ('91111111-0000-0000-0000-000000000021', '90000000-0000-0000-0000-000000000022', 'Store Alpha M33', 'store-alpha-m33', TRUE, FALSE, 0.00),
    ('91111111-0000-0000-0000-000000000022', '90000000-0000-0000-0000-000000000023', 'Store Beta M33', 'store-beta-m33', TRUE, FALSE, 0.00)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.products (id, seller_store_id, name, sku, regular_price, stock_quantity, is_active, approval_status) VALUES
    ('93333333-0000-0000-0000-000000000021', '91111111-0000-0000-0000-000000000021', 'Product Alpha M33', 'SKU-A-33', 1000.00, 50, TRUE, 'approved'),
    ('93333333-0000-0000-0000-000000000022', '91111111-0000-0000-0000-000000000022', 'Product Beta M33', 'SKU-B-33', 1500.00, 40, TRUE, 'approved')
ON CONFLICT (id) DO NOTHING;

-- Seed Multi-Vendor Order: contains Store Alpha & Store Beta items
INSERT INTO public.buyer_orders (id, customer_user_id, order_number, status, payment_status, payment_method, total_amount, shipping_fee, grand_total, idempotency_key) VALUES
    ('ORD-REFUND-SPLIT', '90000000-0000-0000-0000-000000000021', 'ORD-REF-33', 'Processing', 'Pending', 'Cash on Delivery', 2500.00, 150.00, 2650.00, 'IDEMP-REFUND-SPLIT')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.order_items (id, order_id, product_id, seller_store_id, product_name, sku, unit_price, quantity, total_price, commission_rate, commission_amount, seller_payable) VALUES
    ('94444444-0000-0000-0000-000000000021', 'ORD-REFUND-SPLIT', '93333333-0000-0000-0000-000000000021', '91111111-0000-0000-0000-000000000021', 'Product Alpha M33', 'SKU-A-33', 1000.00, 1, 1000.00, 10.00, 100.00, 900.00),
    ('94444444-0000-0000-0000-000000000022', 'ORD-REFUND-SPLIT', '93333333-0000-0000-0000-000000000022', '91111111-0000-0000-0000-000000000022', 'Product Beta M33', 'SKU-B-33', 1500.00, 1, 1500.00, 10.00, 150.00, 1350.00)
ON CONFLICT (id) DO NOTHING;

-- Store Alpha is Delivered, Store Beta is Shipped
INSERT INTO public.store_fulfillments (order_id, seller_store_id, fulfillment_status, stock_restored) VALUES
    ('ORD-REFUND-SPLIT', '91111111-0000-0000-0000-000000000021', 'Delivered', FALSE),
    ('ORD-REFUND-SPLIT', '91111111-0000-0000-0000-000000000022', 'Shipped', FALSE)
ON CONFLICT (order_id, seller_store_id) DO UPDATE SET fulfillment_status = EXCLUDED.fulfillment_status;

-- Seed return requests for both items
INSERT INTO public.return_requests (id, order_id, order_item_id, seller_store_id, customer_user_id, quantity, reason, status) VALUES
    ('95555555-0000-0000-0000-000000000021', 'ORD-REFUND-SPLIT', '94444444-0000-0000-0000-000000000021', '91111111-0000-0000-0000-000000000021', '90000000-0000-0000-0000-000000000021', 1, 'Store Alpha item defective', 'Pending'),
    ('95555555-0000-0000-0000-000000000022', 'ORD-REFUND-SPLIT', '94444444-0000-0000-0000-000000000022', '91111111-0000-0000-0000-000000000022', '90000000-0000-0000-0000-000000000021', 1, 'Store Beta item returned', 'Pending')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- PART 1: PER-STORE REFUND ELIGIBILITY (TESTS 1 & 2)
-- ----------------------------------------------------------------------------
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000031"}'; -- disputeManager (has returns:review)

-- Test 1: Store A (Delivered) return claim is eligible and approved
SELECT lives_ok(
    $$SELECT public.admin_arbitrate_return_claim('95555555-0000-0000-0000-000000000021', 'Approved', 'Valid claim for delivered item')$$,
    'Test 1: Store A item (Delivered) return claim succeeds'
);

-- Test 2: Store B (Shipped, not Delivered) return claim is rejected
SELECT throws_ok(
    $$SELECT public.admin_arbitrate_return_claim('95555555-0000-0000-0000-000000000022', 'Approved', 'Attempting refund for undelivered item')$$,
    '22023',
    'Order item is not refundable: Store fulfillment must be Delivered and payment collected.',
    'Test 2: Store B item (Undelivered) return claim is rejected'
);

-- ----------------------------------------------------------------------------
-- PART 2: LEDGER SINGLE SOURCE OF TRUTH BALANCE VERIFICATION (TEST 3)
-- ----------------------------------------------------------------------------
-- Seed wallet account for Store Alpha M33
INSERT INTO public.wallet_accounts (seller_store_id, owner_id)
VALUES ('91111111-0000-0000-0000-000000000021', '90000000-0000-0000-0000-000000000022')
ON CONFLICT (seller_store_id) DO NOTHING;

-- Sequence of transactions:
-- 1. HOLD (Escrow order credit): +500.00
INSERT INTO public.wallet_transactions (wallet_account_id, seller_store_id, transaction_type, amount, source_type, source_id, idempotency_key, description)
VALUES ((SELECT id FROM public.wallet_accounts WHERE seller_store_id = '91111111-0000-0000-0000-000000000021'), '91111111-0000-0000-0000-000000000021', 'HOLD', 500.00, 'ORDER_DELIVERED_HELD', 'ORD-TX-01', 'WT-01', 'Hold order');

-- 2. RELEASE (Escrow matures): 500.00 released to available
INSERT INTO public.wallet_transactions (wallet_account_id, seller_store_id, transaction_type, amount, source_type, source_id, idempotency_key, description)
VALUES ((SELECT id FROM public.wallet_accounts WHERE seller_store_id = '91111111-0000-0000-0000-000000000021'), '91111111-0000-0000-0000-000000000021', 'RELEASE', 500.00, 'ORDER_EARNINGS_RELEASE', 'ORD-TX-01', 'WT-02', 'Release order');

-- 3. HOLD (Payout reservation): -200.00 available, +200.00 held
INSERT INTO public.wallet_transactions (wallet_account_id, seller_store_id, transaction_type, amount, source_type, source_id, idempotency_key, description)
VALUES ((SELECT id FROM public.wallet_accounts WHERE seller_store_id = '91111111-0000-0000-0000-000000000021'), '91111111-0000-0000-0000-000000000021', 'HOLD', 200.00, 'PAYOUT_RESERVATION', 'PO-TX-01', 'WT-03', 'Payout hold');

-- 4. REFUND REVERSAL DEBIT: -50.00 available
INSERT INTO public.wallet_transactions (wallet_account_id, seller_store_id, transaction_type, amount, source_type, source_id, idempotency_key, description)
VALUES ((SELECT id FROM public.wallet_accounts WHERE seller_store_id = '91111111-0000-0000-0000-000000000021'), '91111111-0000-0000-0000-000000000021', 'DEBIT', 50.00, 'REFUND_REVERSAL', 'REF-TX-01', 'WT-04', 'Refund debit');

-- Test 3: get_seller_wallet_summary derives available = 250.00 (500 - 200 - 50) and held = 200.00
SELECT is(
    (SELECT available_balance FROM public.get_seller_wallet_summary('91111111-0000-0000-0000-000000000021')),
    250.00,
    'Test 3: Available balance derived strictly from ledger sum equals 250.00'
);

-- ----------------------------------------------------------------------------
-- PART 3: BLACKLIST NORMALIZATION (TESTS 4 - 7)
-- ----------------------------------------------------------------------------
-- Test 4, 5, 6: 3 Pakistani phone formats normalize to canonical '+923001234567'
SELECT is(public.normalize_phone_pk('03001234567'), '+923001234567', 'Test 4: Local format 03001234567 normalizes to +923001234567');
SELECT is(public.normalize_phone_pk('+92 300 1234567'), '+923001234567', 'Test 5: International spaced format normalizes to +923001234567');
SELECT is(public.normalize_phone_pk('923001234567'), '+923001234567', 'Test 6: Digits 923001234567 normalizes to +923001234567');

-- Test 7: Blacklist normalization in create_atomic_order
-- Blacklist phone with 0300-999-0000
INSERT INTO public.fraud_blacklisted_identifiers (identifier_type, identifier_value, normalized_value, reason, threat_level)
VALUES ('Phone Number', '0300-999-0000', '+923009990000', 'Fraud Syndicate Bot', 'Critical')
ON CONFLICT (identifier_type, identifier_value) DO NOTHING;

-- Buyer attempts checkout with spaced international variation '+92 300 9990000'
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000021"}';
SELECT throws_ok(
    $$SELECT public.create_atomic_order(
        '[{"product_id": "93333333-0000-0000-0000-000000000021", "quantity": 1}]'::jsonb,
        '{"phone": "+92 300 9990000", "address": "Karachi Hub"}'::jsonb,
        'Cash on Delivery',
        'IDEMP-NORM-PHONE-01'
    )$$,
    '42501',
    'Transaction rejected: Blacklisted contact details or identifier detected.',
    'Test 7: create_atomic_order catches blacklisted phone across distinct formatting variations'
);

-- ----------------------------------------------------------------------------
-- PART 4: SHIPPING GOVERNANCE & RATE VALIDATION (TESTS 8 - 14)
-- ----------------------------------------------------------------------------

-- Test 8: supportAdmin (lacks shipping:assign) rejected from admin_assign_order_shipment
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000032"}'; -- supportAdmin
SELECT throws_ok(
    $$SELECT public.admin_assign_order_shipment(
        'ORD-REFUND-SPLIT',
        '91111111-0000-0000-0000-000000000021',
        (SELECT id FROM public.shipping_courier_partners WHERE code = 'TCS'),
        'TCS-TRACK-001'
    )$$,
    '42501',
    'Access denied: Insufficient privileges to assign shipments.',
    'Test 8: Unprivileged staff role rejected from assigning shipments'
);

-- Test 9: orderManager (has shipping:assign) succeeds
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000030"}'; -- orderManager
SELECT lives_ok(
    $$SELECT public.admin_assign_order_shipment(
        'ORD-REFUND-SPLIT',
        '91111111-0000-0000-0000-000000000021',
        (SELECT id FROM public.shipping_courier_partners WHERE code = 'TCS'),
        'TCS-TRACK-001'
    )$$,
    'Test 9: orderManager assigns shipment to TCS courier partner'
);

-- Test 10: supportAdmin (lacks shipping:edit) rejected from admin_save_shipping_zone
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000032"}';
SELECT throws_ok(
    $$SELECT public.admin_save_shipping_zone(NULL, 'Khyber Zone', 'Peshawar', 0.0, 5.0, 250.0, '2-3 Days')$$,
    '42501',
    'Access denied: Insufficient privileges to manage shipping zones.',
    'Test 10: Unprivileged staff role rejected from saving shipping zones'
);

-- Test 11: Negative delivery fee is rejected
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000030"}'; -- orderManager (has shipping:edit)
SELECT throws_ok(
    $$SELECT public.admin_save_shipping_zone(NULL, 'Zone Negative', 'Lahore', 0.0, 5.0, -100.0, '2-3 Days')$$,
    '22023',
    'Delivery fee cannot be negative.',
    'Test 11: Negative delivery fee rejected'
);

-- Test 12: Invalid weight range (max <= min) is rejected
SELECT throws_ok(
    $$SELECT public.admin_save_shipping_zone(NULL, 'Zone Inverted Weight', 'Lahore', 5.0, 2.0, 150.0, '2-3 Days')$$,
    '22023',
    'Maximum weight must be strictly greater than minimum weight.',
    'Test 12: Inverted weight range rejected'
);

-- Test 13: Overlapping weight tier for identical zone name is rejected
SELECT lives_ok(
    $$SELECT public.admin_save_shipping_zone(NULL, 'Punjab Central Hub', 'Faisalabad', 0.0, 5.0, 200.0, '2-3 Days')$$,
    'Save first Punjab Central Hub tier (0 - 5 KG)'
);

SELECT throws_ok(
    $$SELECT public.admin_save_shipping_zone(NULL, 'Punjab Central Hub', 'Faisalabad', 3.0, 8.0, 300.0, '2-3 Days')$$,
    '22023',
    'Overlapping weight tier detected for zone Punjab Central Hub.',
    'Test 13: Overlapping weight tier for identical zone name rejected'
);

-- Test 14: Non-overlapping next weight tier (5.0 - 10.0 KG) succeeds
SELECT lives_ok(
    $$SELECT public.admin_save_shipping_zone(NULL, 'Punjab Central Hub', 'Faisalabad', 5.0, 10.0, 320.0, '2-3 Days')$$,
    'Test 14: Non-overlapping next weight tier succeeds'
);

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
