-- ============================================================================
-- SQL Test: Task A1 - Fulfillment Safety, Escrow Held Balances, Deactivated Gates & Strict RLS
-- ============================================================================

BEGIN;
SELECT plan(42);

-- ----------------------------------------------------------------------------
-- 0. SEED TEST FIXTURES & USERS
-- ----------------------------------------------------------------------------
INSERT INTO auth.users (id, email) VALUES
    ('90000000-0000-0000-0000-000000000001', 'buyer_m32@test.com'),
    ('90000000-0000-0000-0000-000000000002', 'seller_alpha_m32@test.com'),
    ('90000000-0000-0000-0000-000000000003', 'seller_beta_m32@test.com'),
    ('90000000-0000-0000-0000-000000000004', 'deactivated_user@test.com'),
    ('90000000-0000-0000-0000-000000000010', 'owner_m32@test.com'),
    ('90000000-0000-0000-0000-000000000011', 'superadmin_m32@test.com'),
    ('90000000-0000-0000-0000-000000000012', 'sellermanager_m32@test.com'),
    ('90000000-0000-0000-0000-000000000013', 'supportadmin_m32@test.com'),
    ('90000000-0000-0000-0000-000000000014', 'financeadmin_m32@test.com'),
    ('90000000-0000-0000-0000-000000000015', 'fraudanalyst_m32@test.com'),
    ('90000000-0000-0000-0000-000000000016', 'catalogmanager_m32@test.com'),
    ('90000000-0000-0000-0000-000000000017', 'ordermanager_m32@test.com'),
    ('90000000-0000-0000-0000-000000000018', 'marketingmanager_m32@test.com')
ON CONFLICT (id) DO NOTHING;

-- Seed User Roles & Staff Roles
INSERT INTO public.user_roles (user_id, role, staff_role) VALUES
    ('90000000-0000-0000-0000-000000000001', 'buyer'::public.app_role, NULL),
    ('90000000-0000-0000-0000-000000000002', 'seller'::public.app_role, NULL),
    ('90000000-0000-0000-0000-000000000003', 'seller'::public.app_role, NULL),
    ('90000000-0000-0000-0000-000000000004', 'buyer'::public.app_role, NULL),
    ('90000000-0000-0000-0000-000000000010', 'owner'::public.app_role, 'owner'::public.admin_staff_role),
    ('90000000-0000-0000-0000-000000000011', 'super_admin'::public.app_role, 'superAdmin'::public.admin_staff_role),
    ('90000000-0000-0000-0000-000000000012', 'admin'::public.app_role, 'sellerManager'::public.admin_staff_role),
    ('90000000-0000-0000-0000-000000000013', 'admin'::public.app_role, 'supportAdmin'::public.admin_staff_role),
    ('90000000-0000-0000-0000-000000000014', 'admin'::public.app_role, 'financeAdmin'::public.admin_staff_role),
    ('90000000-0000-0000-0000-000000000015', 'admin'::public.app_role, 'fraudAnalyst'::public.admin_staff_role),
    ('90000000-0000-0000-0000-000000000016', 'admin'::public.app_role, 'catalogManager'::public.admin_staff_role),
    ('90000000-0000-0000-0000-000000000017', 'admin'::public.app_role, 'orderManager'::public.admin_staff_role),
    ('90000000-0000-0000-0000-000000000018', 'admin'::public.app_role, 'marketingManager'::public.admin_staff_role)
ON CONFLICT (user_id, role) DO UPDATE SET staff_role = EXCLUDED.staff_role;

-- Seed Profiles
INSERT INTO public.profiles (id, full_name, email, role, phone, is_deactivated) VALUES
    ('90000000-0000-0000-0000-000000000001', 'Buyer M32', 'buyer_m32@test.com', 'buyer'::public.app_role, '+923001112233', FALSE),
    ('90000000-0000-0000-0000-000000000002', 'Seller Alpha', 'seller_alpha_m32@test.com', 'seller'::public.app_role, '+923002223344', FALSE),
    ('90000000-0000-0000-0000-000000000003', 'Seller Beta', 'seller_beta_m32@test.com', 'seller'::public.app_role, '+923003334455', FALSE),
    ('90000000-0000-0000-0000-000000000004', 'Deactivated Buyer', 'deactivated_user@test.com', 'buyer'::public.app_role, '+923004445566', TRUE)
ON CONFLICT (id) DO UPDATE SET is_deactivated = EXCLUDED.is_deactivated;

-- Seed Seller Stores
INSERT INTO public.seller_stores (id, owner_id, name, shop_slug, is_approved, is_suspended, balance) VALUES
    ('91111111-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000002', 'Store Alpha M32', 'store-alpha-m32', TRUE, FALSE, 0.00),
    ('91111111-0000-0000-0000-000000000002', '90000000-0000-0000-0000-000000000003', 'Store Beta M32', 'store-beta-m32', TRUE, FALSE, 0.00),
    ('91111111-0000-0000-0000-000000000003', '90000000-0000-0000-0000-000000000002', 'Store Unapproved M32', 'store-unapproved-m32', FALSE, FALSE, 0.00)
ON CONFLICT (id) DO NOTHING;

-- Seed Wallets
INSERT INTO public.wallet_accounts (id, seller_store_id, owner_id, currency, available_balance, held_balance) VALUES
    ('92222222-0000-0000-0000-000000000001', '91111111-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000002', 'PKR', 500.00, 0.00),
    ('92222222-0000-0000-0000-000000000002', '91111111-0000-0000-0000-000000000002', '90000000-0000-0000-0000-000000000003', 'PKR', 0.00, 0.00)
ON CONFLICT (seller_store_id) DO UPDATE SET available_balance = EXCLUDED.available_balance, held_balance = EXCLUDED.held_balance;

INSERT INTO public.wallet_transactions (wallet_account_id, seller_store_id, transaction_type, amount, source_type, source_id, idempotency_key, description, created_by) VALUES
    ('92222222-0000-0000-0000-000000000001', '91111111-0000-0000-0000-000000000001', 'CREDIT', 500.00, 'ORDER_FULFILLMENT', 'SEED-ORD-M32', 'SEED-WT-ALPHA-M32', 'Initial balance', '90000000-0000-0000-0000-000000000002')
ON CONFLICT DO NOTHING;

-- Seed Products
INSERT INTO public.products (id, seller_store_id, name, sku, regular_price, stock_quantity, is_active, approval_status) VALUES
    ('93333333-0000-0000-0000-000000000001', '91111111-0000-0000-0000-000000000001', 'Product Alpha', 'SKU-ALP-01', 1000.00, 50, TRUE, 'approved'),
    ('93333333-0000-0000-0000-000000000002', '91111111-0000-0000-0000-000000000002', 'Product Beta', 'SKU-BET-01', 2000.00, 30, TRUE, 'approved'),
    ('93333333-0000-0000-0000-000000000003', '91111111-0000-0000-0000-000000000001', 'Product Inactive', 'SKU-INA-01', 1500.00, 10, FALSE, 'pending')
ON CONFLICT (id) DO NOTHING;

-- Seed Multi-Vendor Order: contains items from Store Alpha AND Store Beta
INSERT INTO public.buyer_orders (id, customer_user_id, order_number, status, payment_status, payment_method, total_amount, shipping_fee, grand_total, idempotency_key) VALUES
    ('ORD-MULTI-M32', '90000000-0000-0000-0000-000000000001', 'ORD-MULTI-999', 'Processing', 'Pending', 'Cash on Delivery', 3000.00, 150.00, 3150.00, 'IDEMP-ORD-MULTI-M32')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.order_items (id, order_id, product_id, seller_store_id, product_name, sku, unit_price, quantity, total_price, commission_rate, commission_amount, seller_payable) VALUES
    ('94444444-0000-0000-0000-000000000001', 'ORD-MULTI-M32', '93333333-0000-0000-0000-000000000001', '91111111-0000-0000-0000-000000000001', 'Product Alpha', 'SKU-ALP-01', 1000.00, 1, 1000.00, 10.00, 100.00, 900.00),
    ('94444444-0000-0000-0000-000000000002', 'ORD-MULTI-M32', '93333333-0000-0000-0000-000000000002', '91111111-0000-0000-0000-000000000002', 'Product Beta', 'SKU-BET-01', 2000.00, 1, 2000.00, 10.00, 200.00, 1800.00)
ON CONFLICT (id) DO NOTHING;

-- Seed store fulfillments
INSERT INTO public.store_fulfillments (order_id, seller_store_id, fulfillment_status, stock_restored) VALUES
    ('ORD-MULTI-M32', '91111111-0000-0000-0000-000000000001', 'Processing', FALSE),
    ('ORD-MULTI-M32', '91111111-0000-0000-0000-000000000002', 'Processing', FALSE)
ON CONFLICT (order_id, seller_store_id) DO UPDATE SET fulfillment_status = EXCLUDED.fulfillment_status;

-- Seed KYC Documents, Categories, Vouchers for RLS tests
INSERT INTO public.seller_kyc_documents (id, seller_store_id, document_type, document_url, cnic_number, status) VALUES
    ('96666666-0000-0000-0000-000000000001', '91111111-0000-0000-0000-000000000001', 'CNIC_FRONT', 'https://example.com/kyc/cnic_front.pdf', '35201-1111111-1', 'Pending')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.categories (id, name, slug, is_active) VALUES
    ('97777777-0000-0000-0000-000000000001', 'Inactive Category M32', 'inactive-cat-m32', FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.platform_vouchers (id, code, discount_type, discount_value, min_order_amount, is_active, start_date, end_date) VALUES
    ('98888888-0000-0000-0000-000000000001', 'VOUCHER-M32', 'percentage', 10.00, 500.00, TRUE, NOW() - INTERVAL '1 day', NOW() + INTERVAL '10 days')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- PART 1: FULFILLMENT MONEY SAFETY & ESCROW HELD BALANCES (TESTS 1 - 12)
-- ----------------------------------------------------------------------------

-- Test 1: Seller cannot set Delivered
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000002"}';
SELECT throws_ok(
    $$SELECT public.seller_update_fulfillment_status('ORD-MULTI-M32', 'Delivered', '91111111-0000-0000-0000-000000000001')$$,
    '42501',
    'Access denied: Sellers cannot mark orders as Delivered. Delivery must be verified by admin or courier.',
    'Test 1: Seller cannot set fulfillment to Delivered'
);

-- Move to Shipped as seller
SELECT lives_ok(
    $$SELECT public.seller_update_fulfillment_status('ORD-MULTI-M32', 'Shipped', '91111111-0000-0000-0000-000000000001')$$,
    'Seller can transition own store fulfillment to Shipped'
);

-- Test 2: Seller cannot cancel after shipped
SELECT throws_ok(
    $$SELECT public.seller_update_fulfillment_status('ORD-MULTI-M32', 'Cancelled', '91111111-0000-0000-0000-000000000001')$$,
    '22023',
    'Cannot cancel an order that has already shipped.',
    'Test 2: Seller cannot cancel after order has shipped'
);

-- Test 3 & 4: Two stores credit separately and into HELD balance
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000017"}'; -- orderManager (has orders:release)
SELECT lives_ok(
    $$SELECT public.admin_mark_order_delivered('ORD-MULTI-M32', '91111111-0000-0000-0000-000000000001')$$,
    'Test 3: Admin marks Store Alpha Delivered -> credits Store Alpha held balance'
);

SELECT is(
    (SELECT held_balance FROM public.wallet_accounts WHERE seller_store_id = '91111111-0000-0000-0000-000000000001'),
    900.00,
    'Test 4: Store Alpha held balance credited exactly 900.00'
);

-- Test 5: Double call of admin_mark_order_delivered does not double credit
SELECT lives_ok(
    $$SELECT public.admin_mark_order_delivered('ORD-MULTI-M32', '91111111-0000-0000-0000-000000000001')$$,
    'Double call of admin_mark_order_delivered succeeds idempotently'
);

SELECT is(
    (SELECT held_balance FROM public.wallet_accounts WHERE seller_store_id = '91111111-0000-0000-0000-000000000001'),
    900.00,
    'Test 5: Double call did not double-credit held balance'
);

-- Test 6: COD order payment_status remains Pending when only 1 of 2 stores is Delivered
SELECT is(
    (SELECT payment_status FROM public.buyer_orders WHERE id = 'ORD-MULTI-M32'),
    'Pending',
    'Test 6: Order payment_status remains Pending while Store Beta is not yet Delivered'
);

-- Admin marks Store Beta Delivered -> All stores now Delivered
SELECT lives_ok(
    $$SELECT public.admin_mark_order_delivered('ORD-MULTI-M32', '91111111-0000-0000-0000-000000000002')$$,
    'Admin marks Store Beta Delivered'
);

-- Test 7: COD order payment_status becomes Paid ONLY when ALL stores are Delivered
SELECT is(
    (SELECT payment_status FROM public.buyer_orders WHERE id = 'ORD-MULTI-M32'),
    'Paid',
    'Test 7: Order payment_status becomes Paid once ALL store fulfillments are Delivered'
);

-- Test 8 & 9: Cancelled restores stock only once (idempotent)
INSERT INTO public.buyer_orders (id, customer_user_id, order_number, status, payment_status, payment_method, total_amount, shipping_fee, grand_total, idempotency_key) VALUES
    ('ORD-CANCEL-TEST', '90000000-0000-0000-0000-000000000001', 'ORD-CAN-01', 'Processing', 'Pending', 'Cash on Delivery', 1000.00, 150.00, 1150.00, 'IDEMP-CAN-01')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.order_items (id, order_id, product_id, seller_store_id, product_name, sku, unit_price, quantity, total_price, commission_rate, commission_amount, seller_payable) VALUES
    ('94444444-0000-0000-0000-000000000099', 'ORD-CANCEL-TEST', '93333333-0000-0000-0000-000000000001', '91111111-0000-0000-0000-000000000001', 'Product Alpha', 'SKU-ALP-01', 1000.00, 2, 2000.00, 10.00, 200.00, 1800.00)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.store_fulfillments (order_id, seller_store_id, fulfillment_status, stock_restored) VALUES
    ('ORD-CANCEL-TEST', '91111111-0000-0000-0000-000000000001', 'Processing', FALSE)
ON CONFLICT (order_id, seller_store_id) DO NOTHING;

SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000002"}';
-- Initial stock: 50
SELECT lives_ok(
    $$SELECT public.seller_update_fulfillment_status('ORD-CANCEL-TEST', 'Cancelled', '91111111-0000-0000-0000-000000000001')$$,
    'Seller cancels processing fulfillment'
);

SELECT is(
    (SELECT stock_quantity FROM public.products WHERE id = '93333333-0000-0000-0000-000000000001'),
    52,
    'Test 8: First cancellation restores stock by 2 (50 -> 52)'
);

-- Second call attempts to cancel again (rejected or idempotent stock restore)
SELECT throws_ok(
    $$SELECT public.seller_update_fulfillment_status('ORD-CANCEL-TEST', 'Cancelled', '91111111-0000-0000-0000-000000000001')$$,
    '22023',
    'Finalized fulfillments cannot change status.',
    'Test 9: Cannot re-cancel already cancelled fulfillment; stock remains 52'
);

-- Test 10: Payout cannot exceed available balance
-- Store Alpha has available_balance = 500.00 (and held_balance = 900.00). Attempting 700.00 payout fails!
SELECT throws_ok(
    $$SELECT public.seller_request_payout(700.00, 'PAYOUT-FAIL-EXCEED-AVAILABLE')$$,
    '22023',
    'Insufficient available balance. Requested: 700.00, Available: 500.00 (Held balance cannot be withdrawn).',
    'Test 10: Payout request cannot exceed available balance (held balance cannot be withdrawn)'
);

-- Test 11 & 12: Escrow release checks return window & open return disputes
-- Force maturity date of Store Alpha held earnings to NOW() - INTERVAL '1 hour'
UPDATE public.order_held_earnings
SET mature_at = NOW() - INTERVAL '1 hour'
WHERE order_id = 'ORD-MULTI-M32' AND seller_store_id = '91111111-0000-0000-0000-000000000001';

-- Insert open return dispute for this order & store
INSERT INTO public.return_requests (id, order_id, order_item_id, seller_store_id, customer_user_id, quantity, reason, status) VALUES
    ('95555555-0000-0000-0000-000000000001', 'ORD-MULTI-M32', '94444444-0000-0000-0000-000000000001', '91111111-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000001', 1, 'Defective item', 'Pending')
ON CONFLICT (id) DO NOTHING;

SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000014"}'; -- financeAdmin (has finance:adjust)
SELECT throws_ok(
    $$SELECT public.admin_release_held_seller_earnings('ORD-MULTI-M32', '91111111-0000-0000-0000-000000000001')$$,
    '22023',
    'Cannot release earnings: Open dispute or return claim exists for this order.',
    'Test 11: Release of mature held balance blocked while open return dispute exists'
);

-- Resolve return claim as Rejected
UPDATE public.return_requests SET status = 'Rejected' WHERE id = '95555555-0000-0000-0000-000000000001';

SELECT lives_ok(
    $$SELECT public.admin_release_held_seller_earnings('ORD-MULTI-M32', '91111111-0000-0000-0000-000000000001')$$,
    'Test 12: Mature held balance releases to available balance once open return dispute is closed'
);

SELECT is(
    (SELECT available_balance FROM public.wallet_accounts WHERE seller_store_id = '91111111-0000-0000-0000-000000000001'),
    1400.00,
    'Available balance increased from 500.00 to 1400.00 following escrow release'
);

-- ----------------------------------------------------------------------------
-- PART 2: DEACTIVATED USER GATES (TESTS 13 - 18)
-- ----------------------------------------------------------------------------
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000004"}'; -- Deactivated User

-- Test 13: create_atomic_order
SELECT throws_ok(
    $$SELECT public.create_atomic_order(
        '[{"product_id": "93333333-0000-0000-0000-000000000001", "quantity": 1}]'::jsonb,
        '{"phone": "+923004445566", "address": "Test St"}'::jsonb,
        'Cash on Delivery',
        'IDEMP-DEACT-01'
    )$$,
    '42501',
    'Account is deactivated. Please contact support.',
    'Test 13: Deactivated user rejected from create_atomic_order'
);

-- Test 14: seller_update_product_stock
SELECT throws_ok(
    $$SELECT public.seller_update_product_stock('93333333-0000-0000-0000-000000000001', 100)$$,
    '42501',
    'Account is deactivated. Please contact support.',
    'Test 14: Deactivated user rejected from seller_update_product_stock'
);

-- Test 15: seller_update_fulfillment_status
SELECT throws_ok(
    $$SELECT public.seller_update_fulfillment_status('ORD-MULTI-M32', 'Processing', '91111111-0000-0000-0000-000000000001')$$,
    '42501',
    'Account is deactivated. Please contact support.',
    'Test 15: Deactivated user rejected from seller_update_fulfillment_status'
);

-- Test 16: seller_request_payout
SELECT throws_ok(
    $$SELECT public.seller_request_payout(100.00, 'IDEMP-DEACT-PAYOUT')$$,
    '42501',
    'Account is deactivated. Please contact support.',
    'Test 16: Deactivated user rejected from seller_request_payout'
);

-- Test 17: submit_product_review
SELECT throws_ok(
    $$SELECT public.submit_product_review('ORD-MULTI-M32', '93333333-0000-0000-0000-000000000001'::uuid, 5, 'Great!')$$,
    '42501',
    'Account is deactivated. Please contact support.',
    'Test 17: Deactivated user rejected from submit_product_review'
);

-- Test 18: submit_return_request
SELECT throws_ok(
    $$SELECT public.submit_return_request('ORD-MULTI-M32', '94444444-0000-0000-0000-000000000001', 1, 'Wrong item')$$,
    '42501',
    'Account is deactivated. Please contact support.',
    'Test 18: Deactivated user rejected from submit_return_request'
);

-- ----------------------------------------------------------------------------
-- PART 3: FRAUD CHECKOUT ENFORCEMENT (TEST 19)
-- ----------------------------------------------------------------------------
-- Blacklist phone +923009998877
INSERT INTO public.fraud_blacklisted_identifiers (identifier_type, identifier_value, reason, threat_level) VALUES
    ('Phone Number', '+923009998877', 'Payment Syndicate Chargeback Bot', 'Critical')
ON CONFLICT (identifier_type, identifier_value) DO NOTHING;

-- Normal active buyer attempts checkout using blacklisted phone in shipping address
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000001"}';
SELECT throws_ok(
    $$SELECT public.create_atomic_order(
        '[{"product_id": "93333333-0000-0000-0000-000000000001", "quantity": 1}]'::jsonb,
        '{"phone": "+923009998877", "address": "Mall Road Lahore"}'::jsonb,
        'Cash on Delivery',
        'IDEMP-FRAUD-PHONE-01'
    )$$,
    '42501',
    'Transaction rejected: Blacklisted contact details or identifier detected.',
    'Test 19: create_atomic_order rejects blacklisted phone number in shipping address'
);

-- ----------------------------------------------------------------------------
-- PART 4: RLS TESTS FOR 9 CONVERTED TABLES (TESTS 20 - 37)
-- (ONE POSITIVE AND ONE NEGATIVE PER TABLE UNDER SET LOCAL ROLE authenticated)
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;

-- Table 1: user_roles
-- Positive: superAdmin (has roles:view) views foreign user_roles
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000011"}';
SELECT is(
    (SELECT count(*)::int FROM public.user_roles WHERE user_id = '90000000-0000-0000-0000-000000000001'),
    1,
    'Test 20 (Positive): superAdmin views foreign user_roles'
);

-- Negative: supportAdmin (lacks roles:view) sees 0 foreign user_roles
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000013"}';
SELECT is(
    (SELECT count(*)::int FROM public.user_roles WHERE user_id = '90000000-0000-0000-0000-000000000001'),
    0,
    'Test 21 (Negative): supportAdmin sees 0 foreign user_roles'
);

-- Table 2: profiles
-- Positive: supportAdmin (has customers:view) views foreign profiles
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000013"}';
SELECT is(
    (SELECT count(*)::int FROM public.profiles WHERE id = '90000000-0000-0000-0000-000000000001'),
    1,
    'Test 22 (Positive): supportAdmin views foreign customer profile'
);

-- Negative: catalogManager (lacks customers:view) sees 0 foreign profiles
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000016"}';
SELECT is(
    (SELECT count(*)::int FROM public.profiles WHERE id = '90000000-0000-0000-0000-000000000001'),
    0,
    'Test 23 (Negative): catalogManager sees 0 foreign profiles'
);

-- Table 3: seller_stores
-- Positive: sellerManager (has sellers:view) views unapproved store
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000012"}';
SELECT is(
    (SELECT count(*)::int FROM public.seller_stores WHERE id = '91111111-0000-0000-0000-000000000003'),
    1,
    'Test 24 (Positive): sellerManager views unapproved store'
);

-- Negative: marketingManager (lacks sellers:view) sees 0 unapproved foreign stores
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000018"}';
SELECT is(
    (SELECT count(*)::int FROM public.seller_stores WHERE id = '91111111-0000-0000-0000-000000000003'),
    0,
    'Test 25 (Negative): marketingManager sees 0 unapproved foreign stores'
);

-- Table 4: seller_kyc_documents
-- Positive: sellerManager (has kyc:view) views KYC documents
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000012"}';
SELECT is(
    (SELECT count(*)::int FROM public.seller_kyc_documents WHERE id = '96666666-0000-0000-0000-000000000001'),
    1,
    'Test 26 (Positive): sellerManager views KYC document'
);

-- Negative: orderManager (lacks kyc:view) sees 0 foreign KYC documents
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000017"}';
SELECT is(
    (SELECT count(*)::int FROM public.seller_kyc_documents WHERE id = '96666666-0000-0000-0000-000000000001'),
    0,
    'Test 27 (Negative): orderManager sees 0 foreign KYC documents'
);

-- Table 5: categories
-- Positive: catalogManager (has categories:view) views inactive categories
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000016"}';
SELECT is(
    (SELECT count(*)::int FROM public.categories WHERE id = '97777777-0000-0000-0000-000000000001'),
    1,
    'Test 28 (Positive): catalogManager views inactive category'
);

-- Negative: supportAdmin (lacks categories:view) sees 0 inactive categories
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000013"}';
SELECT is(
    (SELECT count(*)::int FROM public.categories WHERE id = '97777777-0000-0000-0000-000000000001'),
    0,
    'Test 29 (Negative): supportAdmin sees 0 inactive categories'
);

-- Table 6: products
-- Positive: catalogManager (has products:view) views unapproved/inactive product
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000016"}';
SELECT is(
    (SELECT count(*)::int FROM public.products WHERE id = '93333333-0000-0000-0000-000000000003'),
    1,
    'Test 30 (Positive): catalogManager views unapproved product'
);

-- Negative: marketingManager (lacks products:view) sees 0 unapproved foreign products
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000018"}';
SELECT is(
    (SELECT count(*)::int FROM public.products WHERE id = '93333333-0000-0000-0000-000000000003'),
    0,
    'Test 31 (Negative): marketingManager sees 0 unapproved foreign products'
);

-- Table 7: buyer_orders
-- Positive: orderManager (has orders:view) views all buyer orders
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000017"}';
SELECT is(
    (SELECT count(*)::int FROM public.buyer_orders WHERE id = 'ORD-MULTI-M32'),
    1,
    'Test 32 (Positive): orderManager views foreign buyer order'
);

-- Negative: marketingManager (lacks orders:view) sees 0 foreign buyer orders
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000018"}';
SELECT is(
    (SELECT count(*)::int FROM public.buyer_orders WHERE id = 'ORD-MULTI-M32'),
    0,
    'Test 33 (Negative): marketingManager sees 0 foreign buyer orders'
);

-- Table 8: platform_vouchers
-- Positive: marketingManager (has promotions:view) views platform vouchers
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000018"}';
SELECT is(
    (SELECT count(*)::int FROM public.platform_vouchers WHERE id = '98888888-0000-0000-0000-000000000001'),
    1,
    'Test 34 (Positive): marketingManager views platform vouchers'
);

-- Negative: supportAdmin (lacks promotions:view) sees 0 platform vouchers
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000013"}';
SELECT is(
    (SELECT count(*)::int FROM public.platform_vouchers WHERE id = '98888888-0000-0000-0000-000000000001'),
    0,
    'Test 35 (Negative): supportAdmin sees 0 platform vouchers'
);

-- Table 9: wallet_accounts
-- Positive: financeAdmin (has finance:view) views foreign wallet accounts
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000014"}';
SELECT is(
    (SELECT count(*)::int FROM public.wallet_accounts WHERE id = '92222222-0000-0000-0000-000000000001'),
    1,
    'Test 36 (Positive): financeAdmin views foreign wallet accounts'
);

-- Negative: supportAdmin (lacks finance:view) sees 0 foreign wallet accounts
SET LOCAL request.jwt.claims = '{"sub": "90000000-0000-0000-0000-000000000013"}';
SELECT is(
    (SELECT count(*)::int FROM public.wallet_accounts WHERE id = '92222222-0000-0000-0000-000000000001'),
    0,
    'Test 37 (Negative): supportAdmin sees 0 foreign wallet accounts'
);

RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
