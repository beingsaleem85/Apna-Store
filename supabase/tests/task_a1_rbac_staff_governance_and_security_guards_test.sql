-- ============================================================================
-- SQL Test: Task A1 - RBAC Staff Governance, Security Definer & F3/F4/F5 Guards
-- ============================================================================

BEGIN;
SELECT plan(25);

-- ----------------------------------------------------------------------------
-- 0. SEED TEST FIXTURES & USERS
-- ----------------------------------------------------------------------------
INSERT INTO auth.users (id, email) VALUES
    ('90000000-0000-0000-0000-000000000001', 'buyer_guards_test@example.com'),
    ('90000000-0000-0000-0000-000000000002', 'seller_a_guards_test@example.com'),
    ('90000000-0000-0000-0000-000000000003', 'seller_b_guards_test@example.com'),
    ('90000000-0000-0000-0000-000000000010', 'owner_guards_test@example.com'),
    ('90000000-0000-0000-0000-000000000011', 'superadmin_1@test.com'),
    ('90000000-0000-0000-0000-000000000012', 'superadmin_2@test.com'),
    ('90000000-0000-0000-0000-000000000013', 'legacy_admin_no_staff@test.com')
ON CONFLICT (id) DO NOTHING;

-- Seed User Roles
INSERT INTO public.user_roles (user_id, role, staff_role) VALUES
    ('90000000-0000-0000-0000-000000000001', 'buyer'::public.app_role, NULL),
    ('90000000-0000-0000-0000-000000000002', 'seller'::public.app_role, NULL),
    ('90000000-0000-0000-0000-000000000003', 'seller'::public.app_role, NULL),
    ('90000000-0000-0000-0000-000000000010', 'owner'::public.app_role, 'owner'::public.admin_staff_role),
    ('90000000-0000-0000-0000-000000000011', 'super_admin'::public.app_role, 'superAdmin'::public.admin_staff_role),
    ('90000000-0000-0000-0000-000000000012', 'super_admin'::public.app_role, 'superAdmin'::public.admin_staff_role),
    ('90000000-0000-0000-0000-000000000013', 'admin'::public.app_role, NULL)
ON CONFLICT (user_id, role) DO UPDATE SET staff_role = EXCLUDED.staff_role;

-- Seed Profiles
INSERT INTO public.profiles (id, full_name, email, role) VALUES
    ('90000000-0000-0000-0000-000000000001', 'Buyer Guard', 'buyer_guards_test@example.com', 'buyer'::public.app_role),
    ('90000000-0000-0000-0000-000000000002', 'Seller A', 'seller_a_guards_test@example.com', 'seller'::public.app_role),
    ('90000000-0000-0000-0000-000000000003', 'Seller B', 'seller_b_guards_test@example.com', 'seller'::public.app_role)
ON CONFLICT (id) DO NOTHING;

-- Seed Seller Stores A & B
INSERT INTO public.seller_stores (id, owner_id, name, shop_slug, is_approved, is_suspended) VALUES
    ('91111111-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000002', 'Store A', 'store-a', TRUE, FALSE),
    ('91111111-0000-0000-0000-000000000002', '90000000-0000-0000-0000-000000000003', 'Store B', 'store-b', TRUE, FALSE)
ON CONFLICT (id) DO NOTHING;

-- Seed Wallet for Store B
INSERT INTO public.wallet_accounts (id, seller_store_id, currency, current_balance, available_balance)
VALUES ('97777777-0000-0000-0000-000000000001', '91111111-0000-0000-0000-000000000002', 'PKR', 5000.00, 5000.00)
ON CONFLICT (seller_store_id) DO NOTHING;

-- Seed Order belonging to Store B
INSERT INTO public.buyer_orders (id, customer_user_id, customer_name, customer_email, amount, payment_method, payment_status, status, seller_store_id)
VALUES ('ORD-STORE-B-001', '90000000-0000-0000-0000-000000000001', 'Buyer Guard', 'buyer@test.com', 1200.00, 'Cash on Delivery', 'Paid', 'Processing', '91111111-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;

-- Seed Order Item & Return Request for Store B
INSERT INTO public.categories (id, name, slug) VALUES ('93333333-0000-0000-0000-000000000001', 'Guard Cat', 'guard-cat') ON CONFLICT (id) DO NOTHING;
INSERT INTO public.products (id, seller_store_id, category_id, name, slug, price, stock_quantity)
VALUES ('94444444-0000-0000-0000-000000000001', '91111111-0000-0000-0000-000000000002', '93333333-0000-0000-0000-000000000001', 'Item B', 'item-b', 1200.00, 5)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.order_items (id, order_id, product_id, seller_store_id, product_name, sku, unit_price, quantity, total_price, commission_rate)
VALUES ('95555555-0000-0000-0000-000000000001', 'ORD-STORE-B-001', '94444444-0000-0000-0000-000000000001', '91111111-0000-0000-0000-000000000002', 'Item B', 'SKU-B', 1200.00, 1, 1200.00, 10.00)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.return_requests (id, order_id, order_item_id, seller_store_id, customer_user_id, return_reason, quantity, status)
VALUES ('92000000-0000-0000-0000-000000000001', 'ORD-STORE-B-001', '95555555-0000-0000-0000-000000000001', '91111111-0000-0000-0000-000000000002', '90000000-0000-0000-0000-000000000001', 'Defective B', 1, 'Requested')
ON CONFLICT (id) DO NOTHING;

-- Seed Chat Room between Buyer & Store B
INSERT INTO public.chat_rooms (id, buyer_user_id, seller_store_id)
VALUES ('96666666-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000001', '91111111-0000-0000-0000-000000000002')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 1-5. ASSERTIONS: PART 1.1 - Staff Role Revocation Hardening
-- ----------------------------------------------------------------------------

-- 1. superAdmin cannot revoke owner
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000011', true);
    SELECT public.admin_revoke_staff_role('90000000-0000-0000-0000-000000000010'::uuid);
    $$,
    '%Revocation of the Owner role is prohibited%',
    '1. superAdmin cannot revoke owner staff role'
);

-- 2. superAdmin cannot revoke another superAdmin
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000011', true);
    SELECT public.admin_revoke_staff_role('90000000-0000-0000-0000-000000000012'::uuid);
    $$,
    '%Only Owner can revoke the superAdmin role%',
    '2. superAdmin cannot revoke another superAdmin'
);

-- 3. owner can revoke superAdmin
SELECT set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000010', true);
SELECT is(
    (public.admin_revoke_staff_role('90000000-0000-0000-0000-000000000012'::uuid) ->> 'success')::BOOLEAN,
    TRUE,
    '3. Owner can successfully revoke superAdmin role'
);

-- 4. Revoking a super_admin role row really clears staff_role
SELECT is(
    (SELECT staff_role FROM public.user_roles WHERE user_id = '90000000-0000-0000-0000-000000000012' AND role = 'super_admin'::public.app_role),
    NULL,
    '4. Revoking superAdmin really cleared staff_role to NULL'
);

-- 5. Audit row written for real revocation
SELECT is(
    (SELECT count(*)::INT FROM public.audit_logs WHERE target_id = '90000000-0000-0000-0000-000000000012' AND action = 'STAFF_ROLE_REVOKED'),
    1,
    '5. Audit row written for verified staff role revocation'
);

-- ----------------------------------------------------------------------------
-- 6-15. ASSERTIONS: PART 1.2 - Admin With No staff_role Is Denied on All Modules
-- ----------------------------------------------------------------------------

-- Set caller to legacy admin without staff role
SELECT set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000013', true);

-- 6. admin_review_seller_store denied
SELECT throws_like(
    $$ SELECT public.admin_review_seller_store('91111111-0000-0000-0000-000000000001'::uuid, TRUE); $$,
    '%Access denied%Insufficient privileges%',
    '6. Legacy admin without staff_role is denied on admin_review_seller_store'
);

-- 7. admin_review_kyc_document denied
SELECT throws_like(
    $$ SELECT public.admin_review_kyc_document('00000000-0000-0000-0000-000000000001'::uuid, 'Approved'); $$,
    '%Access denied%Insufficient privileges%',
    '7. Legacy admin without staff_role is denied on admin_review_kyc_document'
);

-- 8. admin_review_product denied
SELECT throws_like(
    $$ SELECT public.admin_review_product('94444444-0000-0000-0000-000000000001'::uuid, TRUE); $$,
    '%Access denied%Insufficient privileges%',
    '8. Legacy admin without staff_role is denied on admin_review_product'
);

-- 9. admin_adjust_seller_wallet denied
SELECT throws_like(
    $$ SELECT public.admin_adjust_seller_wallet('91111111-0000-0000-0000-000000000001'::uuid, 100.00, 'Test adj'); $$,
    '%Access denied%Insufficient privileges%',
    '9. Legacy admin without staff_role is denied on admin_adjust_seller_wallet'
);

-- 10. admin_toggle_seller_suspension denied
SELECT throws_like(
    $$ SELECT public.admin_toggle_seller_suspension('91111111-0000-0000-0000-000000000001'::uuid, TRUE); $$,
    '%Access denied%Insufficient privileges%',
    '10. Legacy admin without staff_role is denied on admin_toggle_seller_suspension'
);

-- 11. admin_toggle_payout_lock denied
SELECT throws_like(
    $$ SELECT public.admin_toggle_payout_lock('91111111-0000-0000-0000-000000000001'::uuid, TRUE); $$,
    '%Access denied%Insufficient privileges%',
    '11. Legacy admin without staff_role is denied on admin_toggle_payout_lock'
);

-- 12. admin_process_payout denied
SELECT throws_like(
    $$ SELECT public.admin_process_payout('00000000-0000-0000-0000-000000000001'::uuid, 'Approved'); $$,
    '%Access denied%Insufficient privileges%',
    '12. Legacy admin without staff_role is denied on admin_process_payout'
);

-- 13. admin_create_voucher denied
SELECT throws_like(
    $$ SELECT public.admin_create_voucher('TESTCODE', 'percentage', 10.00); $$,
    '%Access denied%Insufficient privileges%',
    '13. Legacy admin without staff_role is denied on admin_create_voucher'
);

-- 14. admin_update_commission_rule denied
SELECT throws_like(
    $$ SELECT public.admin_update_commission_rule('00000000-0000-0000-0000-000000000001'::uuid, 12.50); $$,
    '%Access denied%Insufficient privileges%',
    '14. Legacy admin without staff_role is denied on admin_update_commission_rule'
);

-- 15. admin_broadcast_notification denied
SELECT throws_like(
    $$ SELECT public.admin_broadcast_notification('Title', 'Body'); $$,
    '%Access denied%Insufficient privileges%',
    '15. Legacy admin without staff_role is denied on admin_broadcast_notification'
);

-- ----------------------------------------------------------------------------
-- 16-18. ASSERTIONS: PART 1.4 - Account Soft Deactivation Lifecycle
-- ----------------------------------------------------------------------------

-- 16. User deactivates own account
SELECT set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000001', true);
SELECT is(
    (public.deactivate_user_account('90000000-0000-0000-0000-000000000001'::uuid, 'Closing account') ->> 'success')::BOOLEAN,
    TRUE,
    '16. Normal user can deactivate their own account'
);

-- 17. User cannot deactivate someone else's account
SELECT throws_like(
    $$
    SELECT public.deactivate_user_account('90000000-0000-0000-0000-000000000002'::uuid, 'Malicious deactivation');
    $$,
    '%Access denied%Cannot deactivate other user accounts%',
    '17. Normal user cannot deactivate another user account'
);

-- 18. Profile reflects soft deactivation
SELECT is(
    (SELECT is_deactivated FROM public.profiles WHERE id = '90000000-0000-0000-0000-000000000001'),
    TRUE,
    '18. Profile row is_deactivated updated to TRUE'
);

-- ----------------------------------------------------------------------------
-- 19-21. ASSERTIONS: PART 2 - F3 & F4 Security Guards
-- ----------------------------------------------------------------------------

-- 19. F3: Seller A updating Seller B's order fails with exact message
SELECT set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000002', true);
SELECT throws_like(
    $$
    SELECT public.seller_update_fulfillment_status('ORD-STORE-B-001', 'Shipped', 'Notes');
    $$,
    '%Unauthorized to update fulfillment status for this store.%',
    '19. F3: Seller A updating Seller B order throws exact unauthorized message'
);

-- 20. F4: Authenticated direct call to admin_process_refund is denied
SELECT throws_like(
    $$
    SET LOCAL ROLE authenticated;
    SELECT set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000002', true);
    SELECT public.admin_process_refund('ORD-STORE-B-001', '95555555-0000-0000-0000-000000000001'::uuid, 1200.00, 'Direct call', 'DIR-REF-001');
    $$,
    '%permission denied%',
    '20. F4: Authenticated direct EXECUTE on admin_process_refund is denied'
);
RESET ROLE;

-- 21. F4: Store B owner reviewing return request invokes refund without error
SELECT set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000003', true);
SELECT is(
    (public.review_return_request('92000000-0000-0000-0000-000000000001'::uuid, 'Approved', 'Store B approves return') ->> 'success')::BOOLEAN,
    TRUE,
    '21. F4: Store B owner review_return_request successfully executes refund'
);

-- ----------------------------------------------------------------------------
-- 22-25. ASSERTIONS: PART 2 - F5 Chat Guards
-- ----------------------------------------------------------------------------

-- 22. F5: Chat message < 1 char rejected
SELECT set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000001', true);
SELECT throws_like(
    $$
    SELECT public.send_chat_message('96666666-0000-0000-0000-000000000001'::uuid, '   ');
    $$,
    '%Message text cannot be empty%',
    '22. F5: Whitespace-only chat message is rejected'
);

-- 23. F5: Chat message > 2000 chars rejected
SELECT throws_like(
    $$
    SELECT public.send_chat_message('96666666-0000-0000-0000-000000000001'::uuid, repeat('A', 2001));
    $$,
    '%Message exceeds maximum length of 2000 characters%',
    '23. F5: Message > 2000 characters is rejected'
);

-- 24. F5: Direct INSERT into chat_messages is denied
SELECT throws_like(
    $$
    SET LOCAL ROLE authenticated;
    SELECT set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000001', true);
    INSERT INTO public.chat_messages (room_id, sender_id, message_text)
    VALUES ('96666666-0000-0000-0000-000000000001'::uuid, '90000000-0000-0000-0000-000000000001'::uuid, 'Direct insert');
    $$,
    '%permission denied%',
    '24. F5: Direct INSERT into chat_messages is denied for authenticated'
);
RESET ROLE;

-- 25. F5: Direct INSERT into chat_rooms is denied
SELECT throws_like(
    $$
    SET LOCAL ROLE authenticated;
    SELECT set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000001', true);
    INSERT INTO public.chat_rooms (buyer_user_id, seller_store_id)
    VALUES ('90000000-0000-0000-0000-000000000001'::uuid, '91111111-0000-0000-0000-000000000001'::uuid);
    $$,
    '%permission denied%',
    '25. F5: Direct INSERT into chat_rooms is denied for authenticated'
);
RESET ROLE;

SELECT * FROM finish();
ROLLBACK;
