-- ============================================================================
-- SQL Test: Task A1 - Dispute Arbitration Server RBAC & Audit Logging Tests
-- ============================================================================

BEGIN;
SELECT plan(39);

-- ----------------------------------------------------------------------------
-- 0. SEED TEST FIXTURES & USERS IN auth.users
-- ----------------------------------------------------------------------------
INSERT INTO auth.users (id, email) VALUES
    ('10000000-0000-0000-0000-000000000001', 'buyer_dispute_test@example.com'),
    ('10000000-0000-0000-0000-000000000002', 'seller_dispute_test@example.com'),
    -- 12 Staff Users
    ('10000000-0000-0000-0000-000000000010', 'staff_owner@test.com'),
    ('10000000-0000-0000-0000-000000000011', 'staff_superAdmin@test.com'),
    ('10000000-0000-0000-0000-000000000012', 'staff_disputeManager@test.com'),
    ('10000000-0000-0000-0000-000000000013', 'staff_financeAdmin@test.com'),
    ('10000000-0000-0000-0000-000000000014', 'staff_sellerManager@test.com'),
    ('10000000-0000-0000-0000-000000000015', 'staff_supportAdmin@test.com'),
    ('10000000-0000-0000-0000-000000000016', 'staff_catalogManager@test.com'),
    ('10000000-0000-0000-0000-000000000017', 'staff_orderManager@test.com'),
    ('10000000-0000-0000-0000-000000000018', 'staff_marketingManager@test.com'),
    ('10000000-0000-0000-0000-000000000019', 'staff_fraudAnalyst@test.com'),
    ('10000000-0000-0000-0000-000000000020', 'staff_reportingAnalyst@test.com'),
    ('10000000-0000-0000-0000-000000000021', 'staff_auditor@test.com'),
    -- Role assignment target user
    ('10000000-0000-0000-0000-000000000099', 'staff_assign_target@test.com')
ON CONFLICT (id) DO NOTHING;

-- Seed Staff Roles in user_roles
INSERT INTO public.user_roles (user_id, role, staff_role) VALUES
    ('10000000-0000-0000-0000-000000000001', 'buyer'::public.app_role, NULL),
    ('10000000-0000-0000-0000-000000000002', 'seller'::public.app_role, NULL),
    ('10000000-0000-0000-0000-000000000010', 'owner'::public.app_role, 'owner'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000011', 'super_admin'::public.app_role, 'superAdmin'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000012', 'admin'::public.app_role, 'disputeManager'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000013', 'admin'::public.app_role, 'financeAdmin'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000014', 'admin'::public.app_role, 'sellerManager'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000015', 'admin'::public.app_role, 'supportAdmin'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000016', 'admin'::public.app_role, 'catalogManager'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000017', 'admin'::public.app_role, 'orderManager'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000018', 'admin'::public.app_role, 'marketingManager'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000019', 'admin'::public.app_role, 'fraudAnalyst'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000020', 'admin'::public.app_role, 'reportingAnalyst'::public.admin_staff_role),
    ('10000000-0000-0000-0000-000000000021', 'admin'::public.app_role, 'auditor'::public.admin_staff_role)
ON CONFLICT (user_id, role) DO UPDATE SET staff_role = EXCLUDED.staff_role;

-- Seed Seller Store & Wallet
INSERT INTO public.seller_stores (id, owner_id, name, shop_slug, is_approved, is_suspended)
VALUES ('11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002', 'Arbitration Store', 'arb-store-test', TRUE, FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.wallet_accounts (id, seller_store_id, currency, current_balance, available_balance)
VALUES ('77777777-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'PKR', 10000.00, 10000.00)
ON CONFLICT (seller_store_id) DO NOTHING;

-- Seed Orders: Delivered/Collected vs Shipped/Uncollected
INSERT INTO public.buyer_orders (id, customer_user_id, customer_name, customer_email, amount, payment_method, payment_status, status)
VALUES
    ('ORD-COD-DELIVERED', '10000000-0000-0000-0000-000000000001', 'Test Buyer', 'buyer@test.com', 2500.00, 'Cash on Delivery', 'Pending', 'Delivered'),
    ('ORD-COD-SHIPPED', '10000000-0000-0000-0000-000000000001', 'Test Buyer', 'buyer@test.com', 2500.00, 'Cash on Delivery', 'Pending', 'Shipped')
ON CONFLICT (id) DO NOTHING;

-- Seed Category & Product
INSERT INTO public.categories (id, name, slug)
VALUES ('33333333-0000-0000-0000-000000000001', 'Arb Cat', 'arb-cat')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.products (id, seller_store_id, category_id, name, slug, price, stock_quantity)
VALUES ('44444444-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '33333333-0000-0000-0000-000000000001', 'Arb Item', 'arb-item', 2500.00, 10)
ON CONFLICT (id) DO NOTHING;

-- Seed Order Items
INSERT INTO public.order_items (id, order_id, product_id, seller_store_id, product_name, sku, unit_price, quantity, total_price, commission_rate)
VALUES
    ('55555555-0000-0000-0000-000000000001', 'ORD-COD-DELIVERED', '44444444-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'Item 1', 'SKU-1', 2500.00, 1, 2500.00, 10.00),
    ('55555555-0000-0000-0000-000000000002', 'ORD-COD-SHIPPED', '44444444-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', 'Item 2', 'SKU-2', 2500.00, 1, 2500.00, 10.00)
ON CONFLICT (id) DO NOTHING;

-- Seed Separate Return Claims for each scenario
INSERT INTO public.return_requests (id, order_id, order_item_id, seller_store_id, customer_user_id, return_reason, quantity, status)
VALUES
    ('20000000-0000-0000-0000-000000000001', 'ORD-COD-DELIVERED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Claim 1 for Owner', 1, 'Requested'),
    ('20000000-0000-0000-0000-000000000002', 'ORD-COD-DELIVERED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Claim 2 for SuperAdmin', 1, 'Requested'),
    ('20000000-0000-0000-0000-000000000003', 'ORD-COD-DELIVERED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Claim 3 for DisputeManager', 1, 'Requested'),
    ('20000000-0000-0000-0000-000000000004', 'ORD-COD-DELIVERED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Claim 4 for Denied Roles', 1, 'Requested'),
    ('20000000-0000-0000-0000-000000000005', 'ORD-COD-DELIVERED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Claim 5 for Notes validation', 1, 'Requested'),
    ('20000000-0000-0000-0000-000000000006', 'ORD-COD-DELIVERED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Claim 6 Already completed', 1, 'Completed'),
    ('20000000-0000-0000-0000-000000000007', 'ORD-COD-SHIPPED', '55555555-0000-0000-0000-000000000002', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Claim 7 Shipped COD uncollected', 1, 'Requested'),
    ('20000000-0000-0000-0000-000000000008', 'ORD-COD-DELIVERED', '55555555-0000-0000-0000-000000000001', '11111111-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Claim 8 Approval test', 1, 'Requested')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 1. ASSERTION: Unauthenticated caller is rejected
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'Reason');
    $$,
    '%Access denied%Unauthenticated%',
    '1. Unauthenticated caller is rejected'
);

-- ----------------------------------------------------------------------------
-- 2-4. ASSERTIONS: Allowed Roles Succeed on Separate Dedicated Claims
-- ----------------------------------------------------------------------------

-- Role: owner on Claim 1
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000010', true);
SELECT is(
    (public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000001'::uuid, 'Rejected', 'Owner reject on claim 1') ->> 'success')::BOOLEAN,
    TRUE,
    '2. Staff role: owner succeeds on separate claim 1'
);

-- Role: superAdmin on Claim 2
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
SELECT is(
    (public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000002'::uuid, 'Rejected', 'SuperAdmin reject on claim 2') ->> 'success')::BOOLEAN,
    TRUE,
    '3. Staff role: superAdmin succeeds on separate claim 2'
);

-- Role: disputeManager on Claim 3
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000012', true);
SELECT is(
    (public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000003'::uuid, 'Rejected', 'DisputeManager reject on claim 3') ->> 'success')::BOOLEAN,
    TRUE,
    '4. Staff role: disputeManager succeeds on separate claim 3'
);

-- ----------------------------------------------------------------------------
-- 5-13. ASSERTIONS: 9 Denied Staff Roles Rejected with 42501 on Claim 4
-- ----------------------------------------------------------------------------

-- Role 4: financeAdmin (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000013', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Rejected', 'Finance reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '5. Staff role: financeAdmin is rejected with 42501'
);

-- Role 5: sellerManager (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000014', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Rejected', 'SellerManager reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '6. Staff role: sellerManager is rejected with 42501'
);

-- Role 6: supportAdmin (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000015', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Rejected', 'Support reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '7. Staff role: supportAdmin is rejected with 42501'
);

-- Role 7: catalogManager (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000016', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Rejected', 'Catalog reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '8. Staff role: catalogManager is rejected with 42501'
);

-- Role 8: orderManager (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000017', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Order reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '9. Staff role: orderManager is rejected with 42501'
);

-- Role 9: marketingManager (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000018', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Rejected', 'Marketing reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '10. Staff role: marketingManager is rejected with 42501'
);

-- Role 10: fraudAnalyst (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000019', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Rejected', 'Fraud reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '11. Staff role: fraudAnalyst is rejected with 42501'
);

-- Role 11: reportingAnalyst (Denied)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000020', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Rejected', 'Report reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '12. Staff role: reportingAnalyst is rejected with 42501'
);

-- Role 12: auditor (Denied for returns/review)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000021', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000004'::uuid, 'Rejected', 'Auditor reject');
    $$,
    '%Access denied: Insufficient administrative privileges%',
    '13. Staff role: auditor is rejected with 42501'
);

-- ----------------------------------------------------------------------------
-- 14. ASSERTION: Rejection without notes is rejected (P0005)
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000005'::uuid, 'Rejected', '');
    $$,
    '%Rejection notes are mandatory%',
    '14. Rejection without notes is rejected with code P0005'
);

-- ----------------------------------------------------------------------------
-- 15. ASSERTION: Already finalized claim is rejected (P0003)
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000006'::uuid, 'Rejected', 'Completed claim reject');
    $$,
    '%already finalized%',
    '15. Attempt to arbitrate already completed claim throws P0003 error'
);

-- ----------------------------------------------------------------------------
-- 16. ASSERTION: COD + Shipped (uncollected) order is rejected (P0006)
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
    SELECT public.admin_arbitrate_return_claim('20000000-0000-0000-0000-000000000007'::uuid, 'Approved', 'Shipped COD approve');
    $$,
    '%has not been collected/delivered%',
    '16. Approval of COD claim in Shipped status throws P0006'
);

-- ----------------------------------------------------------------------------
-- 17-20. ASSERTIONS: Approved Arbitration Execution & Ledger / Audit Effects
-- ----------------------------------------------------------------------------

-- Execute Approved arbitration in its own separate statement
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
SELECT public.admin_arbitrate_return_claim(
    '20000000-0000-0000-0000-000000000008'::uuid,
    'Approved',
    'Valid approval for collected COD order item'
);

-- 17. Status becomes 'Completed' in return_requests
SELECT is(
    (SELECT status FROM public.return_requests WHERE id = '20000000-0000-0000-0000-000000000008'),
    'Completed',
    '17. Approved arbitration succeeds on Delivered COD order and writes status Completed'
);

-- 18. Exactly one refund row created
SELECT is(
    (SELECT count(*)::INT FROM public.refunds WHERE order_id = 'ORD-COD-DELIVERED' AND order_item_id = '55555555-0000-0000-0000-000000000001'),
    1,
    '18. Exactly one refund record is created in public.refunds'
);

-- 19. Seller wallet debit transaction created with reversed amount
SELECT is(
    (SELECT count(*)::INT FROM public.wallet_transactions WHERE seller_store_id = '11111111-0000-0000-0000-000000000001' AND transaction_type = 'DEBIT' AND source_type = 'REFUND_REVERSAL'),
    1,
    '19. Seller wallet receives debit transaction for reversed payable'
);

-- 20. Audit row created with DISPUTE_FULL_REFUND
SELECT is(
    (SELECT count(*)::INT FROM public.audit_logs WHERE target_id = '20000000-0000-0000-0000-000000000008' AND action = 'DISPUTE_FULL_REFUND'),
    1,
    '20. Audit row created with action DISPUTE_FULL_REFUND'
);

-- ----------------------------------------------------------------------------
-- 21. ASSERTION: Calling arbitration twice throws P0003
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
    SELECT public.admin_arbitrate_return_claim(
        '20000000-0000-0000-0000-000000000008'::uuid,
        'Approved',
        'Duplicate refund attempt'
    );
    $$,
    '%already finalized%',
    '21. Calling arbitration twice is blocked by finalized claim check'
);

-- ----------------------------------------------------------------------------
-- 22-23. ASSERTIONS: Audit Forgery Prevention (Direct INSERTs Blocked)
-- ----------------------------------------------------------------------------

-- 22: Buyer direct INSERT into audit_logs is denied
SELECT throws_like(
    $$
    SET LOCAL ROLE authenticated;
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
    INSERT INTO public.audit_logs (actor_user_id, actor_role, action, target_type, target_id)
    VALUES ('10000000-0000-0000-0000-000000000001', 'buyer'::public.app_role, 'FORGERY', 'order', '1');
    $$,
    '%permission denied%',
    '22. Buyer direct INSERT into audit_logs is denied with 42501'
);
RESET ROLE;

-- 23: Buyer direct INSERT into admin_audit_logs view is denied
SELECT throws_like(
    $$
    SET LOCAL ROLE authenticated;
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
    INSERT INTO public.admin_audit_logs (admin_id, action, target_type, target_id)
    VALUES ('10000000-0000-0000-0000-000000000001', 'FORGERY', 'order', '1');
    $$,
    '%permission denied%',
    '23. Buyer direct INSERT into admin_audit_logs view is denied with 42501'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- 24-26. ASSERTIONS: Audit Log RLS Visibility Under authenticated Role
-- ----------------------------------------------------------------------------

-- 24: Normal authenticated buyer reads 0 rows under authenticated role
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
SELECT is(
    (SELECT count(*)::INT FROM public.audit_logs),
    0,
    '24. Normal user (buyer) reads 0 rows from audit_logs under authenticated role'
);
RESET ROLE;

-- 25: Staff role without audit permission (catalogManager) reads 0 rows
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000016', true);
SELECT is(
    (SELECT count(*)::INT FROM public.audit_logs),
    0,
    '25. Staff role without audit access (catalogManager) reads 0 rows from audit_logs under authenticated role'
);
RESET ROLE;

-- 26: Positive case: Staff role with audit access (auditor) CAN read rows (> 0)
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000021', true);
SELECT cmp_ok(
    (SELECT count(*)::INT FROM public.audit_logs),
    '>',
    0,
    '26. Staff role with audit access (auditor) reads > 0 rows from audit_logs under authenticated role'
);
RESET ROLE;

-- ----------------------------------------------------------------------------
-- 27-28. ASSERTIONS: Audit Log Immutability Enforcement
-- ----------------------------------------------------------------------------

-- 27: Direct UPDATE on audit_logs fails for every role
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000010', true);
    UPDATE public.audit_logs SET action = 'TAMPERED';
    $$,
    '%immutable and cannot be modified or deleted%',
    '27. Direct UPDATE on audit_logs fails for all roles'
);

-- 28: Direct DELETE on audit_logs fails for every role
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000010', true);
    DELETE FROM public.audit_logs;
    $$,
    '%immutable and cannot be modified or deleted%',
    '28. Direct DELETE on audit_logs fails for all roles'
);

-- ----------------------------------------------------------------------------
-- 29-34. ASSERTIONS: Staff Role Assignment Governance & Audit Tests
-- ----------------------------------------------------------------------------

-- 29: User cannot assign staff_role to themselves
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
    SELECT public.admin_assign_staff_role('10000000-0000-0000-0000-000000000011'::uuid, 'disputeManager'::public.admin_staff_role);
    $$,
    '%Self-assignment of staff roles is prohibited%',
    '29. User cannot assign staff_role to themselves'
);

-- 30: financeAdmin cannot assign roles (42501)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000013', true);
    SELECT public.admin_assign_staff_role('10000000-0000-0000-0000-000000000099'::uuid, 'supportAdmin'::public.admin_staff_role);
    $$,
    '%Access denied: Only Owner or Super Admin can assign staff roles%',
    '30. financeAdmin cannot assign staff roles'
);

-- 31: superAdmin assigning superAdmin is rejected (Only Owner may assign superAdmin)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
    SELECT public.admin_assign_staff_role('10000000-0000-0000-0000-000000000099'::uuid, 'superAdmin'::public.admin_staff_role);
    $$,
    '%Only Owner can assign the superAdmin role%',
    '31. superAdmin cannot assign the superAdmin role'
);

-- 32: owner assigning superAdmin succeeds
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000010', true);
SELECT is(
    (public.admin_assign_staff_role('10000000-0000-0000-0000-000000000099'::uuid, 'superAdmin'::public.admin_staff_role) ->> 'success')::BOOLEAN,
    TRUE,
    '32. Owner can successfully assign the superAdmin role'
);

-- 33: superAdmin can assign other staff roles (supportAdmin)
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
SELECT is(
    (public.admin_assign_staff_role('10000000-0000-0000-0000-000000000099'::uuid, 'supportAdmin'::public.admin_staff_role) ->> 'success')::BOOLEAN,
    TRUE,
    '33. superAdmin can successfully assign supportAdmin role'
);

-- 34: Assignment writes an audit row
SELECT is(
    (SELECT count(*)::INT FROM public.audit_logs WHERE target_id = '10000000-0000-0000-0000-000000000099' AND action = 'STAFF_ROLE_ASSIGNED'),
    2,
    '34. Both staff role assignments wrote rows to public.audit_logs'
);

-- ----------------------------------------------------------------------------
-- 35-38. ASSERTIONS: Staff Role Revocation Governance & Audit Tests
-- ----------------------------------------------------------------------------

-- 35: Self-revocation is prohibited
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
    SELECT public.admin_revoke_staff_role('10000000-0000-0000-0000-000000000011'::uuid);
    $$,
    '%Self-revocation of staff roles is prohibited%',
    '35. User cannot revoke their own staff role'
);

-- 36: financeAdmin cannot revoke roles (42501)
SELECT throws_like(
    $$
    SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000013', true);
    SELECT public.admin_revoke_staff_role('10000000-0000-0000-0000-000000000099'::uuid);
    $$,
    '%Access denied: Only Owner or Super Admin can revoke staff roles%',
    '36. financeAdmin cannot revoke staff roles'
);

-- 37: superAdmin can revoke a regular staff role (supportAdmin)
SELECT set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000011', true);
SELECT is(
    (public.admin_revoke_staff_role('10000000-0000-0000-0000-000000000099'::uuid) ->> 'success')::BOOLEAN,
    TRUE,
    '37. superAdmin can successfully revoke supportAdmin role'
);

-- 38: Revocation writes an audit row
SELECT is(
    (SELECT count(*)::INT FROM public.audit_logs WHERE target_id = '10000000-0000-0000-0000-000000000099' AND action = 'STAFF_ROLE_REVOKED'),
    1,
    '38. Staff role revocation wrote row to public.audit_logs'
);

-- ----------------------------------------------------------------------------
-- 39. ASSERTION: Foreign Key Safety on auth.users deletion
-- ----------------------------------------------------------------------------
SELECT throws_like(
    $$
    DELETE FROM auth.users WHERE id = '10000000-0000-0000-0000-000000000011';
    $$,
    '%violates foreign key constraint%',
    '39. Deleting a user with records in audit_logs is blocked by FK constraint NO ACTION'
);

SELECT * FROM finish();
ROLLBACK;
