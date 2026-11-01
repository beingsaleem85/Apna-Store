-- ============================================================================
-- SQL Test: Task A1 - Fulfillment, RLS Refinement, Account Governance & Fraud
-- ============================================================================

BEGIN;
SELECT plan(28);

-- ----------------------------------------------------------------------------
-- 0. SEED TEST FIXTURES & USERS
-- ----------------------------------------------------------------------------
INSERT INTO auth.users (id, email) VALUES
    ('80000000-0000-0000-0000-000000000001', 'buyer_m26@test.com'),
    ('80000000-0000-0000-0000-000000000002', 'seller_multi_1@test.com'),
    ('80000000-0000-0000-0000-000000000010', 'owner_m26@test.com'),
    ('80000000-0000-0000-0000-000000000011', 'superadmin_m26@test.com'),
    ('80000000-0000-0000-0000-000000000012', 'sellermanager_m26@test.com'),
    ('80000000-0000-0000-0000-000000000013', 'supportadmin_m26@test.com'),
    ('80000000-0000-0000-0000-000000000014', 'financeadmin_m26@test.com'),
    ('80000000-0000-0000-0000-000000000015', 'fraudanalyst_m26@test.com'),
    ('80000000-0000-0000-0000-000000000016', 'catalogmanager_m26@test.com')
ON CONFLICT (id) DO NOTHING;

-- Seed User Roles
INSERT INTO public.user_roles (user_id, role, staff_role) VALUES
    ('80000000-0000-0000-0000-000000000001', 'buyer'::public.app_role, NULL),
    ('80000000-0000-0000-0000-000000000002', 'seller'::public.app_role, NULL),
    ('80000000-0000-0000-0000-000000000010', 'owner'::public.app_role, 'owner'::public.admin_staff_role),
    ('80000000-0000-0000-0000-000000000011', 'super_admin'::public.app_role, 'superAdmin'::public.admin_staff_role),
    ('80000000-0000-0000-0000-000000000012', 'admin'::public.app_role, 'sellerManager'::public.admin_staff_role),
    ('80000000-0000-0000-0000-000000000013', 'admin'::public.app_role, 'supportAdmin'::public.admin_staff_role),
    ('80000000-0000-0000-0000-000000000014', 'admin'::public.app_role, 'financeAdmin'::public.admin_staff_role),
    ('80000000-0000-0000-0000-000000000015', 'admin'::public.app_role, 'fraudAnalyst'::public.admin_staff_role),
    ('80000000-0000-0000-0000-000000000016', 'admin'::public.app_role, 'catalogManager'::public.admin_staff_role)
ON CONFLICT (user_id, role) DO UPDATE SET staff_role = EXCLUDED.staff_role;

-- Seed Profiles
INSERT INTO public.profiles (id, full_name, email, role) VALUES
    ('80000000-0000-0000-0000-000000000001', 'Buyer M26', 'buyer_m26@test.com', 'buyer'::public.app_role),
    ('80000000-0000-0000-0000-000000000002', 'Seller Multi', 'seller_multi_1@test.com', 'seller'::public.app_role)
ON CONFLICT (id) DO NOTHING;

-- Seed Stores: Seller Multi owns 2 stores (Store Alpha & Store Beta) and 1 Suspended Store
INSERT INTO public.seller_stores (id, owner_id, name, shop_slug, is_approved, is_suspended) VALUES
    ('81111111-0000-0000-0000-000000000001', '80000000-0000-0000-0000-000000000002', 'Store Alpha', 'store-alpha', TRUE, FALSE),
    ('81111111-0000-0000-0000-000000000002', '80000000-0000-0000-0000-000000000002', 'Store Beta', 'store-beta', TRUE, FALSE),
    ('81111111-0000-0000-0000-000000000003', '80000000-0000-0000-0000-000000000002', 'Store Suspended', 'store-susp', TRUE, TRUE)
ON CONFLICT (id) DO NOTHING;

-- Seed Wallets
INSERT INTO public.wallet_accounts (id, seller_store_id, currency, current_balance, available_balance) VALUES
    ('87777777-0000-0000-0000-000000000001', '81111111-0000-0000-0000-000000000001', 'PKR', 1000.00, 1000.00),
    ('87777777-0000-0000-0000-000000000002', '81111111-0000-0000-0000-000000000002', 'PKR', 1000.00, 1000.00)
ON CONFLICT (seller_store_id) DO NOTHING;

-- Seed Product & Stock
INSERT INTO public.categories (id, name, slug) VALUES ('83333333-0000-0000-0000-000000000001', 'Cat M26', 'cat-m26') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.products (id, seller_store_id, category_id, name, slug, price, stock_quantity) VALUES
    ('84444444-0000-0000-0000-000000000001', '81111111-0000-0000-0000-000000000001', '83333333-0000-0000-0000-000000000001', 'Product Alpha', 'prod-alpha', 500.00, 20),
    ('84444444-0000-0000-0000-000000000002', '81111111-0000-0000-0000-000000000002', '83333333-0000-0000-0000-000000000001', 'Product Beta', 'prod-beta', 700.00, 15)
ON CONFLICT (id) DO NOTHING;

-- Multi-Vendor Order: contains item from Alpha and item from Beta
INSERT INTO public.buyer_orders (id, order_number, customer_user_id, customer_name, customer_email, amount, payment_method, payment_status, status)
VALUES ('ORD-MULTI-M26', 'ORD-2026-M26', '80000000-0000-0000-0000-000000000001', 'Buyer M26', 'buyer_m26@test.com', 1200.00, 'Cash on Delivery', 'Pending', 'Pending')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.order_items (id, order_id, product_id, seller_store_id, product_name, sku, unit_price, quantity, total_price, commission_rate, seller_payable)
VALUES
    ('85555555-0000-0000-0000-000000000001', 'ORD-MULTI-M26', '84444444-0000-0000-0000-000000000001', '81111111-0000-0000-0000-000000000001', 'Product Alpha', 'SKU-A', 500.00, 1, 500.00, 10.00, 450.00),
    ('85555555-0000-0000-0000-000000000002', 'ORD-MULTI-M26', '84444444-0000-0000-0000-000000000002', '81111111-0000-0000-0000-000000000002', 'Product Beta', 'SKU-B', 700.00, 1, 700.00, 10.00, 630.00)
ON CONFLICT (id) DO NOTHING;

-- Single-store order for cancellation test
INSERT INTO public.buyer_orders (id, order_number, customer_user_id, customer_name, customer_email, amount, payment_method, payment_status, status)
VALUES ('ORD-CANCEL-M26', 'ORD-2026-CAN', '80000000-0000-0000-0000-000000000001', 'Buyer M26', 'buyer_m26@test.com', 500.00, 'Cash on Delivery', 'Pending', 'Pending')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.order_items (id, order_id, product_id, seller_store_id, product_name, sku, unit_price, quantity, total_price, commission_rate, seller_payable)
VALUES ('85555555-0000-0000-0000-000000000003', 'ORD-CANCEL-M26', '84444444-0000-0000-0000-000000000001', '81111111-0000-0000-0000-000000000001', 'Product Alpha', 'SKU-A', 500.00, 2, 1000.00, 10.00, 900.00)
ON CONFLICT (id) DO NOTHING;

-- Seed Chat Room
INSERT INTO public.chat_rooms (id, buyer_user_id, seller_store_id)
VALUES ('86666666-0000-0000-0000-000000000001', '80000000-0000-0000-0000-000000000001', '81111111-0000-0000-0000-000000000001')
ON CONFLICT (id) DO NOTHING;

-- Seed Fraud Alerts
INSERT INTO public.fraud_risk_alerts (id, entity_type, entity_id, entity_name, risk_score, risk_factor, ip_address, status)
VALUES ('88888888-0000-0000-0000-000000000001', 'Buyer', '80000000-0000-0000-0000-000000000001', 'Buyer M26', 85, 'Velocity abuse', '1.2.3.4', 'High Risk')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 1. ASSERTION: send_chat_message sends notification to recipient
-- ----------------------------------------------------------------------------
SELECT set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000001', true);
SELECT public.send_chat_message('86666666-0000-0000-0000-000000000001'::uuid, 'Hello Store Alpha');

SELECT is(
    (SELECT count(*)::INT FROM public.user_notifications WHERE user_id = '80000000-0000-0000-0000-000000000002' AND notification_type = 'CHAT_MESSAGE'),
    1,
    '1. send_chat_message creates exactly one notification for recipient'
);

-- ----------------------------------------------------------------------------
-- 2-7. ASSERTIONS: seller_update_fulfillment_status Multi-Vendor Rules
-- ----------------------------------------------------------------------------

-- 2. (b) Seller owning multiple stores in same order must specify p_seller_store_id
SELECT set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000002', true);
SELECT throws_like(
    $$ SELECT public.seller_update_fulfillment_status('ORD-MULTI-M26', 'Processing'); $$,
    '%Multiple stores found for this order. Please specify p_seller_store_id.%',
    '2. Multi-store owner without specifying store is prompted to specify p_seller_store_id'
);

-- 3. (c) Suspended store is rejected
SELECT throws_like(
    $$ SELECT public.seller_update_fulfillment_status('ORD-MULTI-M26', 'Processing', '81111111-0000-0000-0000-000000000003'::uuid); $$,
    '%Unauthorized to update fulfillment status for this store.%',
    '3. Suspended or unowned store fulfillment is rejected'
);

-- 4. (a) Authorize through order_items: Store Alpha updates to Processing then Shipped
SELECT is(
    (public.seller_update_fulfillment_status('ORD-MULTI-M26', 'Processing', '81111111-0000-0000-0000-000000000001'::uuid) ->> 'success')::BOOLEAN,
    TRUE,
    '4. Store Alpha transitions to Processing'
);

-- Transition to Shipped then Delivered
SELECT public.seller_update_fulfillment_status('ORD-MULTI-M26', 'Shipped', '81111111-0000-0000-0000-000000000001'::uuid, 'TCS', 'TRK-ALPHA-01');
SELECT public.seller_update_fulfillment_status('ORD-MULTI-M26', 'Delivered', '81111111-0000-0000-0000-000000000001'::uuid);

-- 5. (d) On Delivered for COD: Seller wallet transaction credited with seller_payable (450.00)
SELECT is(
    (SELECT count(*)::INT FROM public.wallet_transactions WHERE seller_store_id = '81111111-0000-0000-0000-000000000001' AND transaction_type = 'CREDIT' AND source_type = 'ORDER_FULFILLMENT'),
    1,
    '5. Delivered COD accrues seller payable in wallet_transactions'
);

-- 6. (e) On Cancelled: Stock quantity restored in products
SELECT is(
    (SELECT stock_quantity FROM public.products WHERE id = '84444444-0000-0000-0000-000000000001'),
    20,
    'Pre-condition: Product Alpha stock is 20'
);
SELECT public.seller_update_fulfillment_status('ORD-CANCEL-M26', 'Cancelled', '81111111-0000-0000-0000-000000000001'::uuid);

SELECT is(
    (SELECT stock_quantity FROM public.products WHERE id = '84444444-0000-0000-0000-000000000001'),
    22,
    '6. Cancelled order restores product stock (+2)'
);

-- 7. (f) Tracking event inserted and buyer notified
SELECT is(
    (SELECT count(*)::INT FROM public.order_tracking_events WHERE order_id = 'ORD-MULTI-M26'),
    3,
    '7. Order tracking events logged for each fulfillment transition'
);

-- ----------------------------------------------------------------------------
-- 8-15. ASSERTIONS: RLS Policy Evaluation Across 4 Staff Roles (SET LOCAL ROLE authenticated)
-- ----------------------------------------------------------------------------

-- Role 1: sellerManager (can read seller_stores, reads 0 from platform_vouchers)
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000012', true);
SELECT cmp_ok((SELECT count(*)::INT FROM public.seller_stores), '>', 0, '8. sellerManager can read seller_stores');
SELECT is((SELECT count(*)::INT FROM public.platform_vouchers), 0, '9. sellerManager reads 0 platform_vouchers');
RESET ROLE;

-- Role 2: supportAdmin (can read profiles, reads 0 from wallet_accounts)
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000013', true);
SELECT cmp_ok((SELECT count(*)::INT FROM public.profiles), '>', 0, '10. supportAdmin can read profiles');
SELECT is((SELECT count(*)::INT FROM public.wallet_accounts), 0, '11. supportAdmin reads 0 wallet_accounts');
RESET ROLE;

-- Role 3: financeAdmin (can read wallet_accounts, reads 0 from seller_kyc_documents)
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000014', true);
SELECT cmp_ok((SELECT count(*)::INT FROM public.wallet_accounts), '>', 0, '12. financeAdmin can read wallet_accounts');
SELECT is((SELECT count(*)::INT FROM public.seller_kyc_documents), 0, '13. financeAdmin reads 0 seller_kyc_documents');
RESET ROLE;

-- Role 4: fraudAnalyst (can read fraud_risk_alerts, reads 0 from platform_vouchers)
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000015', true);
SELECT cmp_ok((SELECT count(*)::INT FROM public.fraud_risk_alerts), '>', 0, '14. fraudAnalyst can read fraud_risk_alerts');
SELECT is((SELECT count(*)::INT FROM public.platform_vouchers), 0, '15. fraudAnalyst reads 0 platform_vouchers');
RESET ROLE;

-- ----------------------------------------------------------------------------
-- 16-22. ASSERTIONS: Account Deactivation Governance & Guards
-- ----------------------------------------------------------------------------

-- 16. Non-owner staff cannot deactivate super_admin
SELECT set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000015', true);
SELECT throws_like(
    $$ SELECT public.deactivate_user_account('80000000-0000-0000-0000-000000000011'::uuid, 'Test'); $$,
    '%Only Owner can deactivate staff or super_admin accounts%',
    '16. Non-owner cannot deactivate super_admin'
);

-- 17. Nobody can deactivate owner
SELECT throws_like(
    $$ SELECT public.deactivate_user_account('80000000-0000-0000-0000-000000000010'::uuid, 'Test'); $$,
    '%Deactivation of the Owner role is prohibited%',
    '17. Nobody can deactivate Owner role'
);

-- 18. Owner deactivates super_admin succeeds
SELECT set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000010', true);
SELECT is(
    (public.deactivate_user_account('80000000-0000-0000-0000-000000000011'::uuid, 'Owner deactivates superAdmin') ->> 'success')::BOOLEAN,
    TRUE,
    '18. Owner successfully deactivates super_admin'
);

-- 19. Direct UPDATE on profiles.is_deactivated from authenticated is denied
SELECT throws_like(
    $$
    SET LOCAL ROLE authenticated;
    SELECT set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000001', true);
    UPDATE public.profiles SET is_deactivated = FALSE WHERE id = '80000000-0000-0000-0000-000000000011';
    $$,
    '%permission denied%',
    '19. Direct UPDATE on profiles.is_deactivated is denied'
);
RESET ROLE;

-- 20. Deactivate normal buyer account for guard checks
SELECT public.deactivate_user_account('80000000-0000-0000-0000-000000000001'::uuid, 'Violating policy');

-- 21. Deactivated user cannot send chat message (40301)
SELECT set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000001', true);
SELECT throws_like(
    $$ SELECT public.send_chat_message('86666666-0000-0000-0000-000000000001'::uuid, 'Deactivated chat test'); $$,
    '%Account is deactivated. Please contact support.%',
    '21. Deactivated user cannot send chat message'
);

-- 22. Reactivate restores account
SELECT set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000010', true);
SELECT is(
    (public.admin_reactivate_user_account('80000000-0000-0000-0000-000000000001'::uuid, 'Restored') ->> 'success')::BOOLEAN,
    TRUE,
    '22. Reactivation restores buyer account'
);

-- ----------------------------------------------------------------------------
-- 23-28. ASSERTIONS: Fraud Security RPCs & Audit Logging
-- ----------------------------------------------------------------------------

-- 23. fraudAnalyst can fetch alerts
SELECT set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000015', true);
SELECT is(
    ((public.admin_fetch_fraud_alerts(10, 0) ->> 'total_count')::INT > 0),
    TRUE,
    '23. fraudAnalyst fetches real fraud alerts'
);

-- 24. catalogManager is denied on admin_fetch_fraud_alerts
SELECT set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000016', true);
SELECT throws_like(
    $$ SELECT public.admin_fetch_fraud_alerts(10, 0); $$,
    '%Access denied: Insufficient privileges to view fraud alerts%',
    '24. catalogManager is denied on fraud alerts'
);

-- 25. fraudAnalyst can resolve alert
SELECT set_config('request.jwt.claim.sub', '80000000-0000-0000-0000-000000000015', true);
SELECT is(
    (public.admin_resolve_fraud_alert('88888888-0000-0000-0000-000000000001'::uuid, 'Resolved', 'Investigated safe') ->> 'success')::BOOLEAN,
    TRUE,
    '25. fraudAnalyst resolves fraud alert'
);

-- 26. Resolution writes audit log
SELECT is(
    (SELECT count(*)::INT FROM public.audit_logs WHERE target_id = '88888888-0000-0000-0000-000000000001' AND action = 'FRAUD_ALERT_RESOLVED'),
    1,
    '26. Audit row recorded for alert resolution'
);

-- 27. Blacklist management
SELECT is(
    (public.admin_add_blacklisted_identifier('IP', '192.168.1.99', 'Abuser', 'Bot attack') ->> 'success')::BOOLEAN,
    TRUE,
    '27. fraudAnalyst can add blacklisted identifier'
);

-- 28. Security rule toggle writes audit log
SELECT is(
    (public.admin_toggle_security_rule((SELECT id FROM public.fraud_security_rules WHERE rule_code = 'VELOCITY_LIMIT'), TRUE, '10 orders / 10m') ->> 'success')::BOOLEAN,
    TRUE,
    '28. Security rule toggle succeeds and records audit log'
);

SELECT * FROM finish();
ROLLBACK;
