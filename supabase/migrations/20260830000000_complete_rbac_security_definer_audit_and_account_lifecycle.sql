-- Migration: 20260830000000_complete_rbac_security_definer_audit_and_account_lifecycle.sql
-- Description: Complete conversion of admin_ functions to has_permission, audit-proof staff revocation, account soft-deactivation, F3/F4/F5 security guards

-- ----------------------------------------------------------------------------
-- 1. STAFF ROLE REVOCATION HARDENING
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.admin_revoke_staff_role(
    p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_is_owner BOOLEAN;
    v_is_super_admin BOOLEAN;
    v_target_staff_role public.admin_staff_role;
    v_row_count INT := 0;
    v_audit_id UUID := NULL;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated caller.' USING ERRCODE = '42501';
    END IF;

    -- Self-revocation prevention
    IF p_user_id = v_caller_id THEN
        RAISE EXCEPTION 'Self-revocation of staff roles is prohibited.' USING ERRCODE = '42501';
    END IF;

    -- Caller authority
    v_is_owner := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (role = 'owner'::public.app_role OR staff_role = 'owner'::public.admin_staff_role)
    );

    v_is_super_admin := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (role = 'super_admin'::public.app_role OR staff_role = 'superAdmin'::public.admin_staff_role)
    );

    IF NOT (v_is_owner OR v_is_super_admin) THEN
        RAISE EXCEPTION 'Access denied: Only Owner or Super Admin can revoke staff roles.'
            USING ERRCODE = '42501';
    END IF;

    -- Target staff role lookup
    SELECT staff_role INTO v_target_staff_role
    FROM public.user_roles
    WHERE user_id = p_user_id AND staff_role IS NOT NULL
    ORDER BY granted_at DESC
    LIMIT 1;

    IF v_target_staff_role IS NULL THEN
        RAISE EXCEPTION 'Target user does not have an active staff role.' USING ERRCODE = 'P0002';
    END IF;

    -- Rule (a): Nobody can revoke the 'owner' staff role
    IF v_target_staff_role = 'owner'::public.admin_staff_role THEN
        RAISE EXCEPTION 'Revocation of the Owner role is prohibited.' USING ERRCODE = '42501';
    END IF;

    -- Rule (d): superAdmin cannot revoke superAdmin (Only Owner can revoke superAdmin)
    IF v_target_staff_role = 'superAdmin'::public.admin_staff_role AND NOT v_is_owner THEN
        RAISE EXCEPTION 'Access denied: Only Owner can revoke the superAdmin role.'
            USING ERRCODE = '42501';
    END IF;

    -- Rule (b): Update the actual row(s) that carry the staff_role (not only role='admin')
    UPDATE public.user_roles
    SET staff_role = NULL, granted_at = NOW()
    WHERE user_id = p_user_id AND staff_role IS NOT NULL;

    -- Rule (c): Only write audit row if a row was really changed
    GET DIAGNOSTICS v_row_count = ROW_COUNT;

    IF v_row_count > 0 THEN
        v_audit_id := public.internal_record_audit_log(
            'user_role',
            p_user_id::TEXT,
            'STAFF_ROLE_REVOKED',
            jsonb_build_object(
                'revoked_staff_role', v_target_staff_role::TEXT,
                'revoked_by', v_caller_id,
                'rows_affected', v_row_count
            )
        );
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'user_id', p_user_id,
        'revoked_staff_role', v_target_staff_role,
        'rows_affected', v_row_count,
        'audit_log_id', v_audit_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_revoke_staff_role(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_revoke_staff_role(UUID) TO authenticated;

-- ----------------------------------------------------------------------------
-- 2. COMPLETE CONVERSION OF admin_ FUNCTIONS & is_admin() TO has_permission
-- ----------------------------------------------------------------------------

-- Redefine public.is_admin() to require owner or superAdmin privilege
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;

    RETURN EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = auth.uid()
          AND (
              role IN ('owner'::public.app_role, 'super_admin'::public.app_role)
              OR staff_role IN ('owner'::public.admin_staff_role, 'superAdmin'::public.admin_staff_role)
          )
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '';

-- A. admin_review_seller_store
CREATE OR REPLACE FUNCTION public.admin_review_seller_store(
    store_id UUID,
    approved BOOLEAN,
    new_commission_rate NUMERIC DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    IF NOT public.has_permission('sellers', 'approve') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to review seller stores.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.seller_stores
    SET is_approved = approved,
        commission_rate = COALESCE(new_commission_rate, commission_rate),
        updated_at = NOW()
    WHERE id = store_id;

    PERFORM public.internal_record_audit_log(
        'seller_stores',
        store_id::TEXT,
        CASE WHEN approved THEN 'SELLER_APPROVED' ELSE 'SELLER_REJECTED' END,
        jsonb_build_object('commission_rate', new_commission_rate)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- B. admin_review_kyc_document
CREATE OR REPLACE FUNCTION public.admin_review_kyc_document(
    doc_id UUID,
    new_status TEXT,
    notes TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    IF NOT public.has_permission('kyc', 'verify') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to verify KYC documents.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.seller_kyc_documents
    SET status = new_status,
        rejection_reason = notes,
        reviewed_by = auth.uid(),
        reviewed_at = NOW()
    WHERE id = doc_id;

    PERFORM public.internal_record_audit_log(
        'seller_kyc_documents',
        doc_id::TEXT,
        'KYC_DOCUMENT_REVIEWED',
        jsonb_build_object('status', new_status, 'notes', notes)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- C. admin_review_product
CREATE OR REPLACE FUNCTION public.admin_review_product(
    prod_id UUID,
    approved BOOLEAN
)
RETURNS VOID AS $$
BEGIN
    IF NOT (public.has_permission('products', 'approve') OR public.has_permission('products', 'moderate')) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to review products.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.products
    SET approval_status = CASE WHEN approved THEN 'approved' ELSE 'rejected' END,
        is_active = approved,
        updated_at = NOW()
    WHERE id = prod_id;

    PERFORM public.internal_record_audit_log(
        'products',
        prod_id::TEXT,
        CASE WHEN approved THEN 'PRODUCT_APPROVED' ELSE 'PRODUCT_REJECTED' END,
        '{}'::jsonb
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- D. admin_adjust_seller_wallet
CREATE OR REPLACE FUNCTION public.admin_adjust_seller_wallet(
    p_store_id UUID,
    p_amount NUMERIC(12,2),
    p_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_account_id UUID;
    v_tx_id UUID;
BEGIN
    IF NOT public.has_permission('finance', 'adjust') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to adjust seller wallets.' USING ERRCODE = '42501';
    END IF;

    SELECT id INTO v_account_id FROM public.wallet_accounts WHERE seller_store_id = p_store_id;
    IF v_account_id IS NULL THEN
        RAISE EXCEPTION 'Wallet account not found.' USING ERRCODE = 'P0002';
    END IF;

    INSERT INTO public.wallet_transactions (
        wallet_account_id, seller_store_id, transaction_type, amount,
        source_type, source_id, idempotency_key, description, created_by
    ) VALUES (
        v_account_id, p_store_id, 'ADJUSTMENT', p_amount,
        'ADMIN_ADJUSTMENT', gen_random_uuid()::TEXT, 'ADJ-' || gen_random_uuid()::TEXT,
        p_reason, auth.uid()
    ) RETURNING id INTO v_tx_id;

    PERFORM public.internal_record_audit_log(
        'wallet_accounts',
        v_account_id::TEXT,
        'WALLET_ADJUSTMENT',
        jsonb_build_object('amount', p_amount, 'reason', p_reason, 'transaction_id', v_tx_id)
    );

    RETURN jsonb_build_object('success', TRUE, 'transaction_id', v_tx_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- E. admin_toggle_seller_suspension
CREATE OR REPLACE FUNCTION public.admin_toggle_seller_suspension(
    p_store_id UUID,
    p_suspended BOOLEAN,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
BEGIN
    IF NOT public.has_permission('sellers', 'suspend') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to toggle seller suspension.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.seller_stores
    SET is_suspended = p_suspended,
        updated_at = NOW()
    WHERE id = p_store_id;

    PERFORM public.internal_record_audit_log(
        'seller_stores',
        p_store_id::TEXT,
        CASE WHEN p_suspended THEN 'SELLER_SUSPENDED' ELSE 'SELLER_UNSUSPENDED' END,
        jsonb_build_object('reason', p_reason)
    );

    RETURN jsonb_build_object('success', TRUE, 'store_id', p_store_id, 'is_suspended', p_suspended);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- F. admin_toggle_payout_lock
CREATE OR REPLACE FUNCTION public.admin_toggle_payout_lock(
    p_store_id UUID,
    p_locked BOOLEAN,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
BEGIN
    IF NOT public.has_permission('payouts', 'hold') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to toggle payout lock.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.wallet_accounts
    SET is_payout_locked = p_locked,
        updated_at = NOW()
    WHERE seller_store_id = p_store_id;

    PERFORM public.internal_record_audit_log(
        'wallet_accounts',
        p_store_id::TEXT,
        CASE WHEN p_locked THEN 'PAYOUT_LOCKED' ELSE 'PAYOUT_UNLOCKED' END,
        jsonb_build_object('reason', p_reason)
    );

    RETURN jsonb_build_object('success', TRUE, 'store_id', p_store_id, 'is_payout_locked', p_locked);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- G. admin_process_payout
CREATE OR REPLACE FUNCTION public.admin_process_payout(
    p_payout_id UUID,
    p_decision TEXT, -- 'Approved' or 'Rejected'
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
BEGIN
    IF NOT public.has_permission('payouts', 'approve') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to approve payouts.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.seller_payout_requests
    SET status = p_decision,
        admin_notes = p_notes,
        processed_at = NOW(),
        processed_by = auth.uid()
    WHERE id = p_payout_id;

    PERFORM public.internal_record_audit_log(
        'seller_payout_requests',
        p_payout_id::TEXT,
        'PAYOUT_PROCESSED',
        jsonb_build_object('decision', p_decision, 'notes', p_notes)
    );

    RETURN jsonb_build_object('success', TRUE, 'payout_id', p_payout_id, 'status', p_decision);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- H. admin_create_voucher and admin_toggle_voucher_active
CREATE OR REPLACE FUNCTION public.admin_create_voucher(
    p_code TEXT,
    p_discount_type TEXT,
    p_discount_value NUMERIC(12,2),
    p_min_order_amount NUMERIC(12,2) DEFAULT 0.00,
    p_max_discount NUMERIC(12,2) DEFAULT NULL,
    p_valid_from TIMESTAMPTZ DEFAULT NOW(),
    p_valid_until TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_voucher_id UUID;
BEGIN
    IF NOT public.has_permission('promotions', 'create') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to create vouchers.' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.platform_vouchers (
        code, discount_type, discount_value, min_order_amount,
        max_discount, valid_from, valid_until, created_by
    ) VALUES (
        upper(trim(p_code)), p_discount_type, p_discount_value, p_min_order_amount,
        p_max_discount, p_valid_from, p_valid_until, auth.uid()
    ) RETURNING id INTO v_voucher_id;

    PERFORM public.internal_record_audit_log(
        'platform_vouchers',
        v_voucher_id::TEXT,
        'VOUCHER_CREATED',
        jsonb_build_object('code', p_code, 'discount_value', p_discount_value)
    );

    RETURN jsonb_build_object('success', TRUE, 'voucher_id', v_voucher_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

CREATE OR REPLACE FUNCTION public.admin_toggle_voucher_active(
    p_voucher_id UUID,
    p_is_active BOOLEAN
)
RETURNS JSONB AS $$
BEGIN
    IF NOT public.has_permission('promotions', 'edit') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to modify vouchers.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.platform_vouchers
    SET is_active = p_is_active,
        updated_at = NOW()
    WHERE id = p_voucher_id;

    PERFORM public.internal_record_audit_log(
        'platform_vouchers',
        p_voucher_id::TEXT,
        'VOUCHER_STATUS_CHANGED',
        jsonb_build_object('is_active', p_is_active)
    );

    RETURN jsonb_build_object('success', TRUE, 'voucher_id', p_voucher_id, 'is_active', p_is_active);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- I. admin_update_commission_rule
CREATE OR REPLACE FUNCTION public.admin_update_commission_rule(
    p_rule_id UUID,
    p_base_rate NUMERIC(5,2),
    p_category TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
BEGIN
    IF NOT public.has_permission('commission', 'edit') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to update commission rules.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.commission_rules
    SET base_rate = p_base_rate,
        updated_at = NOW()
    WHERE id = p_rule_id;

    PERFORM public.internal_record_audit_log(
        'commission_rules',
        p_rule_id::TEXT,
        'COMMISSION_RULE_UPDATED',
        jsonb_build_object('base_rate', p_base_rate, 'category', p_category)
    );

    RETURN jsonb_build_object('success', TRUE, 'rule_id', p_rule_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- J. admin_broadcast_notification
CREATE OR REPLACE FUNCTION public.admin_broadcast_notification(
    p_title TEXT,
    p_body TEXT,
    p_target_role public.app_role DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_count INT := 0;
BEGIN
    IF NOT public.has_permission('notifications', 'send') THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to broadcast notifications.' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.user_notifications (user_id, title, body, notification_type, action_link)
    SELECT u.id, p_title, p_body, 'BROADCAST', '/notifications'
    FROM auth.users u
    JOIN public.user_roles ur ON ur.user_id = u.id
    WHERE (p_target_role IS NULL OR ur.role = p_target_role);

    GET DIAGNOSTICS v_count = ROW_COUNT;

    PERFORM public.internal_record_audit_log(
        'user_notifications',
        'BROADCAST',
        'NOTIFICATION_BROADCAST',
        jsonb_build_object('title', p_title, 'target_role', p_target_role, 'delivered_count', v_count)
    );

    RETURN jsonb_build_object('success', TRUE, 'delivered_count', v_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- ----------------------------------------------------------------------------
-- 3. STAFF ROLE PERMISSIONS SEEDING (ENSURING FULL MODULE COVERAGE)
-- ----------------------------------------------------------------------------

INSERT INTO public.staff_role_permissions (staff_role, module, action) VALUES
    -- SupportAdmin additions for reviews & chat monitoring
    ('supportAdmin', 'reviews', 'moderate'),
    ('supportAdmin', 'reviews', 'view'),
    ('supportAdmin', 'chat', 'monitor'),
    ('supportAdmin', 'chat', 'view'),
    -- DisputeManager additions
    ('disputeManager', 'reviews', 'moderate'),
    ('disputeManager', 'refunds', 'process'),
    -- FraudAnalyst additions
    ('fraudAnalyst', 'audit', 'view'),
    -- Auditor audit view
    ('auditor', 'audit', 'view'),
    ('auditor', 'returns', 'view'),
    ('auditor', 'disputes', 'view'),
    -- MarketingManager voucher permissions
    ('marketingManager', 'vouchers', 'create'),
    ('marketingManager', 'vouchers', 'edit'),
    ('marketingManager', 'vouchers', 'view'),
    -- OrderManager shipping permissions
    ('orderManager', 'shipping', 'view'),
    ('orderManager', 'shipping', 'update')
ON CONFLICT (staff_role, module, action) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 4. ACCOUNT SOFT DEACTIVATION LIFECYCLE
-- ----------------------------------------------------------------------------

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_deactivated BOOLEAN DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS deactivated_at TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION public.deactivate_user_account(
    p_user_id UUID,
    p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_is_authorized BOOLEAN;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    v_is_authorized := (v_caller_id = p_user_id) 
                    OR public.has_permission('customers', 'suspend')
                    OR public.is_admin();

    IF NOT v_is_authorized THEN
        RAISE EXCEPTION 'Access denied: Cannot deactivate other user accounts.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.profiles
    SET is_deactivated = TRUE,
        deactivated_at = NOW()
    WHERE id = p_user_id;

    v_audit_id := public.internal_record_audit_log(
        'profiles',
        p_user_id::TEXT,
        'USER_ACCOUNT_DEACTIVATED',
        jsonb_build_object(
            'deactivated_by', v_caller_id,
            'reason', p_reason
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'user_id', p_user_id,
        'is_deactivated', TRUE,
        'audit_log_id', v_audit_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.deactivate_user_account(UUID, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 5. PART 2 SECURITY GUARDS: F3, F4, F5
-- ----------------------------------------------------------------------------

-- F3. seller_update_fulfillment_status: Explicit ownership check & error message
CREATE OR REPLACE FUNCTION public.seller_update_fulfillment_status(
    p_order_id TEXT,
    p_new_status TEXT,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_order RECORD;
    v_seller_store RECORD;
    v_current_user_id UUID := auth.uid();
BEGIN
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    SELECT id, is_approved INTO v_seller_store
    FROM public.seller_stores
    WHERE owner_id = v_current_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User does not own a registered seller store.' USING ERRCODE = '42501';
    END IF;

    SELECT id, order_number, status, seller_store_id
    INTO v_order
    FROM public.buyer_orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Strict Store Ownership Validation
    IF v_order.seller_store_id != v_seller_store.id THEN
        RAISE EXCEPTION 'Unauthorized to update fulfillment status for this store.' USING ERRCODE = '42501';
    END IF;

    -- State machine forward transitions
    IF v_order.status = 'Pending' AND p_new_status NOT IN ('Processing', 'Cancelled') THEN
        RAISE EXCEPTION 'Pending order can only transition to Processing or Cancelled.' USING ERRCODE = '22023';
    ELSIF v_order.status = 'Processing' AND p_new_status NOT IN ('Shipped', 'Cancelled') THEN
        RAISE EXCEPTION 'Processing order can only transition to Shipped or Cancelled.' USING ERRCODE = '22023';
    ELSIF v_order.status = 'Shipped' AND p_new_status NOT IN ('Delivered') THEN
        RAISE EXCEPTION 'Shipped order can only transition to Delivered.' USING ERRCODE = '22023';
    ELSIF v_order.status IN ('Delivered', 'Cancelled') THEN
        RAISE EXCEPTION 'Finalized orders cannot change status.' USING ERRCODE = '22023';
    END IF;

    UPDATE public.buyer_orders
    SET status = p_new_status,
        updated_at = NOW()
    WHERE id = p_order_id;

    RETURN jsonb_build_object('success', TRUE, 'order_id', p_order_id, 'status', p_new_status);
END;
$$;

-- F4. admin_process_refund: Check permissions & revoke direct EXECUTE from authenticated
CREATE OR REPLACE FUNCTION public.admin_process_refund(
    p_order_id TEXT,
    p_order_item_id UUID,
    p_amount NUMERIC(12,2),
    p_reason TEXT,
    p_idempotency_key TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_admin_id UUID;
    v_customer_user_id UUID;
    v_seller_store_id UUID;
    v_item_total NUMERIC(12,2);
    v_item_commission_rate NUMERIC(5,2);
    v_existing_refunded NUMERIC(12,2) := 0.00;
    v_comm_reversed NUMERIC(12,2);
    v_seller_payable_reversed NUMERIC(12,2);
    v_wallet_account_id UUID;
    v_refund_id UUID;
    v_existing_refund_id UUID;
    v_existing_order_id TEXT;
    v_existing_item_id UUID;
    v_existing_amount NUMERIC(12,2);
    v_existing_status TEXT;
    v_is_seller_owner BOOLEAN;
    v_result JSONB;
BEGIN
    v_admin_id := auth.uid();
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for refund processing.' USING ERRCODE = '42501';
    END IF;

    -- Look up order line item seller store
    SELECT oi.seller_store_id INTO v_seller_store_id
    FROM public.order_items oi
    WHERE oi.id = p_order_item_id AND oi.order_id = p_order_id;

    v_is_seller_owner := FALSE;
    IF v_seller_store_id IS NOT NULL THEN
        v_is_seller_owner := EXISTS (
            SELECT 1 FROM public.seller_stores
            WHERE id = v_seller_store_id AND owner_id = v_admin_id
        );
    END IF;

    -- Authorized staff OR seller store owner reviewing return
    IF NOT (
        public.has_permission('refunds', 'process')
        OR public.has_permission('disputes', 'refund')
        OR public.has_permission('finance', 'adjust')
        OR v_is_seller_owner
    ) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges for refund processing.' USING ERRCODE = '42501';
    END IF;

    IF p_amount IS NULL OR p_amount <= 0.00 THEN
        RAISE EXCEPTION 'Refund amount must be greater than zero.' USING ERRCODE = 'P0004';
    END IF;

    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'Refund reason is required.' USING ERRCODE = 'P0005';
    END IF;

    IF p_idempotency_key IS NULL OR trim(p_idempotency_key) = '' THEN
        RAISE EXCEPTION 'Idempotency key is required for refund.' USING ERRCODE = 'P0001';
    END IF;

    -- Durable Idempotency Check
    SELECT id, order_id, order_item_id, amount, status INTO v_existing_refund_id, v_existing_order_id, v_existing_item_id, v_existing_amount, v_existing_status
    FROM public.refunds
    WHERE idempotency_key = p_idempotency_key;

    IF v_existing_refund_id IS NOT NULL THEN
        IF v_existing_order_id <> p_order_id OR v_existing_item_id <> p_order_item_id OR v_existing_amount <> p_amount THEN
            RAISE EXCEPTION 'Idempotency conflict: Existing refund has different parameters.' USING ERRCODE = 'P0003';
        END IF;

        RETURN jsonb_build_object(
            'success', TRUE,
            'already_processed', TRUE,
            'refund_id', v_existing_refund_id,
            'amount', v_existing_amount,
            'status', v_existing_status
        );
    END IF;

    -- Fetch Line Item Details
    SELECT bo.customer_user_id, oi.seller_store_id, oi.total_price, oi.commission_rate
    INTO v_customer_user_id, v_seller_store_id, v_item_total, v_item_commission_rate
    FROM public.order_items oi
    JOIN public.buyer_orders bo ON bo.id = oi.order_id
    WHERE oi.id = p_order_item_id AND oi.order_id = p_order_id;

    IF v_seller_store_id IS NULL THEN
        RAISE EXCEPTION 'Target order line item not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Cumulative Refund Bound Check
    SELECT COALESCE(SUM(amount), 0.00) INTO v_existing_refunded
    FROM public.refunds
    WHERE order_item_id = p_order_item_id AND status = 'Completed';

    IF (v_existing_refunded + p_amount) > v_item_total THEN
        RAISE EXCEPTION 'Refund amount exceeds eligible paid item amount.' USING ERRCODE = 'P0004';
    END IF;

    v_comm_reversed := ROUND(p_amount * (v_item_commission_rate / 100.00), 2);
    v_seller_payable_reversed := p_amount - v_comm_reversed;

    -- Insert Refund Record
    INSERT INTO public.refunds (
        order_id, order_item_id, seller_store_id, customer_user_id, amount,
        commission_reversed, seller_payable_reversed, status, reason, idempotency_key, processed_by
    ) VALUES (
        p_order_id, p_order_item_id, v_seller_store_id, v_customer_user_id, p_amount,
        v_comm_reversed, v_seller_payable_reversed, 'Completed', p_reason, p_idempotency_key, v_admin_id
    ) RETURNING id INTO v_refund_id;

    -- Debit Seller Wallet
    SELECT id INTO v_wallet_account_id FROM public.wallet_accounts WHERE seller_store_id = v_seller_store_id;

    IF v_wallet_account_id IS NOT NULL THEN
        INSERT INTO public.wallet_transactions (
            wallet_account_id, seller_store_id, transaction_type, amount,
            source_type, source_id, idempotency_key, description, created_by
        ) VALUES (
            v_wallet_account_id, v_seller_store_id, 'DEBIT', v_seller_payable_reversed,
            'REFUND_REVERSAL', v_refund_id::TEXT, 'WLT-REF-' || v_refund_id::TEXT,
            'Refund Reversal for Order ' || p_order_id, v_admin_id
        ) ON CONFLICT (idempotency_key) DO NOTHING;
    END IF;

    PERFORM public.internal_record_audit_log(
        'refunds',
        v_refund_id::TEXT,
        'PROCESS_REFUND',
        jsonb_build_object('order_id', p_order_id, 'amount', p_amount, 'refund_id', v_refund_id)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'refund_id', v_refund_id,
        'amount', p_amount,
        'status', 'Completed'
    );
END;
$$;

-- Revoke direct execution of admin_process_refund from authenticated users
REVOKE ALL ON FUNCTION public.admin_process_refund(TEXT, UUID, NUMERIC, TEXT, TEXT) FROM PUBLIC, anon, authenticated;

-- F5. chat_messages length CHECK, rate limit in send_chat_message, direct DML revoked
ALTER TABLE public.chat_messages
    DROP CONSTRAINT IF EXISTS chat_messages_text_length_check;

ALTER TABLE public.chat_messages
    ADD CONSTRAINT chat_messages_text_length_check
    CHECK (length(trim(message_text)) >= 1 AND length(message_text) <= 2000);

REVOKE INSERT, UPDATE, DELETE ON public.chat_messages FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.chat_rooms FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.chat_messages TO authenticated;
GRANT SELECT ON public.chat_rooms TO authenticated;

CREATE OR REPLACE FUNCTION public.send_chat_message(
    p_room_id UUID,
    p_message_text TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_sender_id UUID;
    v_room RECORD;
    v_recipient_id UUID;
    v_msg_id UUID;
BEGIN
    v_sender_id := auth.uid();
    IF v_sender_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    -- Enforce 30 messages per minute rate limit
    PERFORM public.enforce_rate_limit('send_chat_message', 30, 60);

    IF p_message_text IS NULL OR trim(p_message_text) = '' THEN
        RAISE EXCEPTION 'Message text cannot be empty.' USING ERRCODE = '22023';
    END IF;

    IF length(p_message_text) > 2000 THEN
        RAISE EXCEPTION 'Message exceeds maximum length of 2000 characters.' USING ERRCODE = '22023';
    END IF;

    -- Fetch Chat Room Details
    SELECT cr.id, cr.buyer_user_id, ss.owner_id AS seller_owner_id
    INTO v_room
    FROM public.chat_rooms cr
    JOIN public.seller_stores ss ON ss.id = cr.seller_store_id
    WHERE cr.id = p_room_id;

    IF v_room.id IS NULL THEN
        RAISE EXCEPTION 'Chat room not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Room Membership Check
    IF v_sender_id <> v_room.buyer_user_id AND v_sender_id <> v_room.seller_owner_id AND NOT public.has_permission('chat', 'monitor') THEN
        RAISE EXCEPTION 'Access denied: You are not a participant in chat room %.', p_room_id USING ERRCODE = '42501';
    END IF;

    -- Determine Recipient ID
    IF v_sender_id = v_room.buyer_user_id THEN
        v_recipient_id := v_room.seller_owner_id;
    ELSE
        v_recipient_id := v_room.buyer_user_id;
    END IF;

    -- Insert Message (runs with security definer privileges)
    INSERT INTO public.chat_messages (
        room_id, sender_id, message_text
    ) VALUES (
        p_room_id, v_sender_id, p_message_text
    ) RETURNING id INTO v_msg_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'message_id', v_msg_id,
        'room_id', p_room_id,
        'sender_id', v_sender_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_chat_message(UUID, TEXT) TO authenticated;
