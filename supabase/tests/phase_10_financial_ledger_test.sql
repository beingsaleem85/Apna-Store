-- ============================================================================
-- PGTAP TEST SUITE: PHASE 10 FINANCIAL LEDGER, WALLET, PAYOUTS & REFUNDS
-- File: supabase/tests/phase_10_financial_ledger_test.sql
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgtap;

BEGIN;

SELECT plan(36);

-- ----------------------------------------------------------------------------
-- SETUP: Seed Test Users, Stores, Products, Orders & Order Items
-- ----------------------------------------------------------------------------

-- Seed Auth Users
INSERT INTO auth.users (id, email) VALUES
    ('77777777-7777-7777-7777-777777770001', 'buyer_p10@example.com'),
    ('77777777-7777-7777-7777-777777770002', 'seller_a_p10@example.com'),
    ('77777777-7777-7777-7777-777777770003', 'seller_b_p10@example.com'),
    ('77777777-7777-7777-7777-777777770004', 'admin_p10@example.com'),
    ('77777777-7777-7777-7777-777777770005', 'subadmin_nofinance_p10@example.com'),
    ('77777777-7777-7777-7777-777777770099', 'seller_iso_p10@example.com')
ON CONFLICT (id) DO NOTHING;

-- Seed Profiles
INSERT INTO public.profiles (id, full_name, email) VALUES
    ('77777777-7777-7777-7777-777777770001', 'Buyer P10', 'buyer_p10@example.com'),
    ('77777777-7777-7777-7777-777777770002', 'Seller A P10', 'seller_a_p10@example.com'),
    ('77777777-7777-7777-7777-777777770003', 'Seller B P10', 'seller_b_p10@example.com'),
    ('77777777-7777-7777-7777-777777770004', 'Admin P10', 'admin_p10@example.com'),
    ('77777777-7777-7777-7777-777777770005', 'Subadmin NoFinance P10', 'subadmin_nofinance_p10@example.com'),
    ('77777777-7777-7777-7777-777777770099', 'Seller Iso P10', 'seller_iso_p10@example.com')
ON CONFLICT (id) DO NOTHING;

-- Seed Roles
INSERT INTO public.user_roles (user_id, role, granted_at) VALUES
    ('77777777-7777-7777-7777-777777770001', 'buyer'::public.app_role, NOW()),
    ('77777777-7777-7777-7777-777777770002', 'seller'::public.app_role, NOW() + INTERVAL '1 sec'),
    ('77777777-7777-7777-7777-777777770003', 'seller'::public.app_role, NOW() + INTERVAL '2 sec'),
    ('77777777-7777-7777-7777-777777770004', 'super_admin'::public.app_role, NOW() + INTERVAL '3 sec'),
    ('77777777-7777-7777-7777-777777770005', 'admin'::public.app_role, NOW() + INTERVAL '4 sec')
ON CONFLICT (user_id, role) DO UPDATE SET granted_at = EXCLUDED.granted_at;

-- Seed Seller Stores
INSERT INTO public.seller_stores (id, owner_id, shop_name, shop_slug, is_approved, is_suspended, commission_rate) VALUES
    ('cccc1111-1111-1111-1111-111111111111', '77777777-7777-7777-7777-777777770002', 'Store A P10', 'store-a-p10', TRUE, FALSE, 10.00),
    ('cccc2222-2222-2222-2222-222222222222', '77777777-7777-7777-7777-777777770003', 'Store B P10', 'store-b-p10', TRUE, FALSE, 15.00),
    ('cccc9999-9999-9999-9999-999999999999', '77777777-7777-7777-7777-777777770099', 'Store Isolation P10', 'store-iso-p10', TRUE, FALSE, 10.00)
ON CONFLICT (id) DO UPDATE SET is_approved = TRUE, is_suspended = FALSE, commission_rate = EXCLUDED.commission_rate;

-- Seed Products
INSERT INTO public.products (id, seller_store_id, name, price, stock_quantity, approval_status, is_active) VALUES
    ('dddd1111-1111-1111-1111-111111111111', 'cccc1111-1111-1111-1111-111111111111', 'Item A P10', 1000.00, 50, 'Approved', TRUE),
    ('dddd2222-2222-2222-2222-222222222222', 'cccc2222-2222-2222-2222-222222222222', 'Item B P10', 2000.00, 50, 'Approved', TRUE)
ON CONFLICT (id) DO UPDATE SET approval_status = 'Approved', is_active = TRUE, price = EXCLUDED.price;

-- Create Multi-Seller Order via create_atomic_order
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770001", "role": "authenticated"}';

SELECT public.create_atomic_order(
    'p10-order-key-1',
    '[{"product_id": "dddd1111-1111-1111-1111-111111111111", "quantity": 1}, {"product_id": "dddd2222-2222-2222-2222-222222222222", "quantity": 1}]'::jsonb,
    '{"city": "Islamabad"}'::jsonb,
    'COD'
);

-- ----------------------------------------------------------------------------
-- 1, 2, 3, 4, 5. DIRECT CLIENT REVOKES ON FINANCIAL TABLES
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ INSERT INTO public.payments (order_id, customer_user_id, amount, idempotency_key) VALUES ('ORD-FAKE', '77777777-7777-7777-7777-777777770001', 100.00, 'KEY-FAKE') $$,
    '42501',
    NULL,
    '1. Direct client insert into payments is denied by table privileges'
);

SELECT throws_ok(
    $$ INSERT INTO public.wallet_accounts (seller_store_id, owner_id) VALUES ('cccc1111-1111-1111-1111-111111111111', '77777777-7777-7777-7777-777777770002') $$,
    '42501',
    NULL,
    '2. Direct client insert into wallet_accounts is denied by table privileges'
);

SELECT throws_ok(
    $$ INSERT INTO public.wallet_transactions (wallet_account_id, seller_store_id, transaction_type, amount, source_type, source_id, idempotency_key, description) VALUES ('00000000-0000-0000-0000-000000000000', 'cccc1111-1111-1111-1111-111111111111', 'CREDIT', 5000.00, 'ADMIN_ADJUSTMENT', 'FAKE', 'KEY-FAKE-TXN', 'Fake Credit') $$,
    '42501',
    NULL,
    '3. Direct client insert into wallet_transactions is denied by table privileges'
);

SELECT throws_ok(
    $$ INSERT INTO public.payout_requests (seller_store_id, requested_by, amount, idempotency_key) VALUES ('cccc1111-1111-1111-1111-111111111111', '77777777-7777-7777-7777-777777770002', 1000.00, 'KEY-FAKE-PAYOUT') $$,
    '42501',
    NULL,
    '4. Direct client insert into payout_requests is denied by table privileges'
);

SELECT throws_ok(
    $$ INSERT INTO public.refunds (order_id, seller_store_id, customer_user_id, amount, reason, idempotency_key) VALUES ('ORD-FAKE', 'cccc1111-1111-1111-1111-111111111111', '77777777-7777-7777-7777-777777770001', 500.00, 'Fake Refund', 'KEY-FAKE-REF') $$,
    '42501',
    NULL,
    '5. Direct client insert into refunds is denied by table privileges'
);

-- ----------------------------------------------------------------------------
-- 6 & 7. APPEND-ONLY TAMPER PROTECTION TRIGGER TEST
-- ----------------------------------------------------------------------------
SET LOCAL ROLE postgres;

INSERT INTO public.wallet_accounts (id, seller_store_id, owner_id) VALUES
    ('99999999-9999-9999-9999-999999999999', 'cccc9999-9999-9999-9999-999999999999', '77777777-7777-7777-7777-777777770099')
ON CONFLICT (seller_store_id) DO NOTHING;

INSERT INTO public.wallet_transactions (id, wallet_account_id, seller_store_id, transaction_type, amount, source_type, source_id, idempotency_key, description) VALUES
    ('88888888-8888-8888-8888-888888888888', '99999999-9999-9999-9999-999999999999', 'cccc9999-9999-9999-9999-999999999999', 'CREDIT', 100.00, 'ADMIN_ADJUSTMENT', 'SETUP', 'SETUP-TXN-ISO', 'Setup Txn')
ON CONFLICT (idempotency_key) DO NOTHING;

SELECT throws_ok(
    $$ UPDATE public.wallet_transactions SET amount = 999999.00 WHERE id = '88888888-8888-8888-8888-888888888888' $$,
    'P0001',
    'Wallet ledger entries are append-only and immutable.',
    '6. Update attempt on wallet_transactions raises append-only immutable exception'
);

SELECT throws_ok(
    $$ DELETE FROM public.wallet_transactions WHERE id = '88888888-8888-8888-8888-888888888888' $$,
    'P0001',
    'Wallet ledger entries are append-only and immutable.',
    '7. Delete attempt on wallet_transactions raises append-only immutable exception'
);

-- ----------------------------------------------------------------------------
-- 8 & 9. COD SETTLEMENT LOGISTICS BOUNDARY TEST
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770004", "role": "authenticated"}';

-- 8a. Settle fails on non-delivered order (status = Processing)
SELECT throws_ok(
    $$ SELECT public.admin_process_cod_settlement((SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p10-order-key-1'), 'Settle') $$,
    'P0001',
    'Cannot settle COD order ' || (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p10-order-key-1') || ': Order must be in Delivered status (Current: Pending).',
    '8a. COD settlement on non-delivered order raises exception'
);

-- Advance order to Delivered via logistics workflow (simulated)
SET LOCAL ROLE postgres;
UPDATE public.buyer_orders SET status = 'Delivered' WHERE idempotency_key = 'p10-order-key-1';

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770004", "role": "authenticated"}';

-- 8b. Settle succeeds on Delivered order
SELECT ok(
    (public.admin_process_cod_settlement(
        (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p10-order-key-1'),
        'Settle'
    ))->>'success' = 'true',
    '8b. Multi-seller COD settlement RPC execution succeeds on Delivered order'
);

-- 8c. Physical order status remains Delivered and was not fabricated by settlement RPC
SELECT is(
    (SELECT status FROM public.buyer_orders WHERE idempotency_key = 'p10-order-key-1'),
    'Delivered',
    '8c. Order logistics status remains Delivered and is not fabricated by settlement RPC'
);

-- ----------------------------------------------------------------------------
-- 10 & 11. MULTI-SELLER WALLET CREDITS & SELLER ISOLATION RLS
-- ----------------------------------------------------------------------------
-- Seller A Payable: Item A1 price 1000.00 - 10% comm (100.00) = 900.00
SELECT is(
    (SELECT available_balance FROM public.get_seller_wallet_summary('cccc1111-1111-1111-1111-111111111111'))::NUMERIC(12,2),
    900.00::NUMERIC(12,2),
    '10. Seller A wallet correctly credited with 900.00 (1000 total - 10% commission)'
);

-- Seller B Payable: Item B1 price 2000.00 - 15% comm (300.00) = 1700.00
SELECT is(
    (SELECT available_balance FROM public.get_seller_wallet_summary('cccc2222-2222-2222-2222-222222222222'))::NUMERIC(12,2),
    1700.00::NUMERIC(12,2),
    '11. Seller B wallet correctly credited with 1700.00 (2000 total - 15% commission)'
);

-- ----------------------------------------------------------------------------
-- 12. SELLER ISOLATION RLS QUERY TEST
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770002", "role": "authenticated"}';

SELECT is(
    (SELECT COUNT(*)::INT FROM public.wallet_transactions WHERE seller_store_id = 'cccc2222-2222-2222-2222-222222222222'),
    0,
    '12. Seller A RLS query returns ZERO wallet transactions for Seller B'
);

-- ----------------------------------------------------------------------------
-- 13 & 14. SELLER PAYOUT REQUEST RPC & HOLD TRANSACTION
-- ----------------------------------------------------------------------------
SELECT ok(
    (public.seller_request_payout(500.00, 'key-payout-req-a1'))->>'success' = 'true',
    '13. Seller A payout request for 500.00 succeeds and creates HOLD entry'
);

SELECT is(
    (SELECT available_balance FROM public.get_seller_wallet_summary('cccc1111-1111-1111-1111-111111111111'))::NUMERIC(12,2),
    400.00::NUMERIC(12,2),
    '14. Seller A available balance correctly reduced to 400.00 after HOLD'
);

-- ----------------------------------------------------------------------------
-- 15. EXCESSIVE PAYOUT REQUEST FAILS
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$ SELECT public.seller_request_payout(1000.00, 'key-payout-req-excess') $$,
    '%Insufficient available balance. Requested: 1000.00, Available: 400.00%',
    '15. Excessive payout request exceeding available balance raises exception'
);

-- ----------------------------------------------------------------------------
-- 16, 17, 18. ADMIN PAYOUT APPROVAL & DISBURSEMENT RPC
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770004", "role": "authenticated"}';

SELECT ok(
    (public.admin_process_payout(
        (SELECT id FROM public.payout_requests WHERE idempotency_key = 'key-payout-req-a1'),
        'Pay',
        'Batch 101 Disbursed to Bank'
    ))->>'success' = 'true',
    '16. Admin payout disbursement RPC succeeds and sets status to Paid'
);

SELECT is(
    (SELECT status FROM public.payout_requests WHERE idempotency_key = 'key-payout-req-a1'),
    'Paid',
    '17. Payout status updated to Paid'
);

SELECT is(
    (public.admin_process_payout(
        (SELECT id FROM public.payout_requests WHERE idempotency_key = 'key-payout-req-a1'),
        'Pay',
        'Batch 101 Retry'
    ))->>'already_processed',
    'true',
    '18. Duplicate payout processing call is idempotent'
);

-- ----------------------------------------------------------------------------
-- 19. PAYOUT REJECTION RELEASES RESERVED HOLD ENTRY
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770003", "role": "authenticated"}';

SELECT ok(
    (public.seller_request_payout(500.00, 'key-payout-req-b1'))->>'success' = 'true',
    'Seller B payout request created'
);

SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770004", "role": "authenticated"}';

SELECT ok(
    (public.admin_process_payout(
        (SELECT id FROM public.payout_requests WHERE idempotency_key = 'key-payout-req-b1'),
        'Reject',
        'Invalid Bank Details'
    ))->>'status' = 'Rejected',
    '19. Admin payout rejection succeeds and releases reserved HOLD entry back to available balance'
);

SELECT is(
    (SELECT available_balance FROM public.get_seller_wallet_summary('cccc2222-2222-2222-2222-222222222222'))::NUMERIC(12,2),
    1700.00::NUMERIC(12,2),
    'Seller B available balance correctly restored to 1700.00 after payout rejection'
);

-- ----------------------------------------------------------------------------
-- 20, 21, 22, 23, 24, 25. ADMIN REFUND RPC & MULTI-SELLER ISOLATION
-- ----------------------------------------------------------------------------
SELECT ok(
    (public.admin_process_refund(
        (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p10-order-key-1'),
        (SELECT id FROM public.order_items WHERE product_name = 'Item A P10'),
        500.00,
        'Item Damaged in Transit',
        'key-refund-item-a1'
    ))->>'success' = 'true',
    '20. Admin refund processing RPC succeeds'
);

SELECT is(
    (SELECT seller_payable_reversed FROM public.refunds WHERE idempotency_key = 'key-refund-item-a1')::NUMERIC(12,2),
    450.00::NUMERIC(12,2),
    '21. Refund correctly calculated 450.00 seller payable reversal'
);

SELECT is(
    (SELECT available_balance FROM public.get_seller_wallet_summary('cccc2222-2222-2222-2222-222222222222'))::NUMERIC(12,2),
    1700.00::NUMERIC(12,2),
    '22. Multi-seller refund isolation: Seller B wallet remains completely unchanged at 1700.00'
);

SELECT is(
    (public.admin_process_refund(
        (SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p10-order-key-1'),
        (SELECT id FROM public.order_items WHERE product_name = 'Item A P10'),
        500.00,
        'Item Damaged in Transit',
        'key-refund-item-a1'
    ))->>'already_processed',
    'true',
    '23. Refund idempotency: Replayed refund request returns already_processed = true'
);

SELECT throws_ok(
    $$ SELECT public.admin_process_refund((SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p10-order-key-1'), (SELECT id FROM public.order_items WHERE product_name = 'Item A P10'), 200.00, 'Different amount', 'key-refund-item-a1') $$,
    'P0001',
    'Idempotency conflict: Existing refund key-refund-item-a1 has different request parameters.',
    '24. Refund idempotency conflict: Same reference with different amount raises exception'
);

SELECT throws_ok(
    $$ SELECT public.admin_process_refund((SELECT id FROM public.buyer_orders WHERE idempotency_key = 'p10-order-key-1'), (SELECT id FROM public.order_items WHERE product_name = 'Item A P10'), 800.00, 'Excessive', 'key-refund-excess') $$,
    'P0001',
    'Refund amount exceeds eligible paid item amount. Eligible: 500.00, Requested: 800.00',
    '25. Excessive refund exceeding eligible item price raises exception'
);

-- ----------------------------------------------------------------------------
-- 26 & 27. ADMIN WALLET ADJUSTMENT RPC
-- ----------------------------------------------------------------------------
SELECT ok(
    (public.admin_adjust_seller_wallet('cccc1111-1111-1111-1111-111111111111', 100.00, 'Goodwill credit', 'key-adj-a1'))->>'success' = 'true',
    '26. Admin wallet adjustment RPC succeeds and creates append-only ledger transaction'
);

SELECT is(
    (public.admin_adjust_seller_wallet('cccc1111-1111-1111-1111-111111111111', 100.00, 'Goodwill credit', 'key-adj-a1'))->>'success',
    'true',
    '27. Duplicate admin wallet adjustment idempotency key returns idempotent success'
);

-- ----------------------------------------------------------------------------
-- 28. WALLET SUMMARY AUTHORIZATION
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770002", "role": "authenticated"}';

SELECT throws_ok(
    $$ SELECT * FROM public.get_seller_wallet_summary('cccc2222-2222-2222-2222-222222222222') $$,
    'P0001',
    'Access denied: You do not own store cccc2222-2222-2222-2222-222222222222.',
    '28. Unauthorized seller calling get_seller_wallet_summary for another store raises access denied'
);

-- ----------------------------------------------------------------------------
-- 29. BUYER USER WITHOUT FINANCE PERMISSION IS DENIED SENSITIVE FINANCE ACCESS
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770001", "role": "authenticated"}';

SELECT is(
    (SELECT COUNT(*)::INT FROM public.wallet_transactions),
    0,
    '29a. Buyer user without finance:view permission receives 0 wallet transactions via RLS'
);

SELECT throws_ok(
    $$ SELECT * FROM public.reconcile_financial_ledger() $$,
    'P0001',
    'Access denied: Insufficient privileges for ledger reconciliation.',
    '29b. Buyer user without finance:view calling reconcile_financial_ledger raises access denied'
);

-- ----------------------------------------------------------------------------
-- 30. DIGITAL GATEWAYS REMAIN SERVER-REJECTED
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770001", "role": "authenticated"}';

SELECT throws_ok(
    $$ SELECT public.create_atomic_order('p10-jc-gate-key', '[{"product_id": "dddd1111-1111-1111-1111-111111111111", "quantity": 1}]'::jsonb, '{}'::jsonb, 'JazzCash') $$,
    'P0001',
    'Payment method JazzCash is not currently available.',
    '30. Digital payment method JazzCash direct RPC checkout remains server-rejected'
);

-- ----------------------------------------------------------------------------
-- 31, 32, 33, 34. FINANCIAL RECONCILIATION RPC TEST & PROJECTION DRIFT
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770004", "role": "authenticated"}';

SELECT ok(
    (SELECT COUNT(*)::INT FROM public.reconcile_financial_ledger()) > 0,
    '31. Financial reconciliation RPC returns check results for super admin'
);

SET LOCAL ROLE postgres;
UPDATE public.seller_stores SET pending_payout = 999999.00 WHERE id = 'cccc1111-1111-1111-1111-111111111111';

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "77777777-7777-7777-7777-777777770004", "role": "authenticated"}';

SELECT ok(
    EXISTS (
        SELECT 1 FROM public.reconcile_financial_ledger()
        WHERE check_name = 'Seller Stores Pending Payout Projection Mismatch'
          AND status = 'DISCREPANCY_DETECTED'
    ),
    '32. Financial reconciliation RPC detects intentional test projection mismatch'
);

SELECT * FROM finish();
ROLLBACK;
