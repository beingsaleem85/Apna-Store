-- Migration: 20260831000000_fulfillment_rls_refinement_and_account_governance.sql
-- Description: Multi-vendor seller fulfillment, recipient chat notifications, granular RLS policies, account governance, and fraud security tables/RPCs

-- ----------------------------------------------------------------------------
-- 1. SEND CHAT MESSAGE: RECIPIENT NOTIFICATION RESTORATION & CLEANUP
-- ----------------------------------------------------------------------------

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
    v_sender_name TEXT;
    v_sender_is_deactivated BOOLEAN;
BEGIN
    v_sender_id := auth.uid();
    IF v_sender_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    -- Deactivated user guard
    SELECT is_deactivated INTO v_sender_is_deactivated
    FROM public.profiles
    WHERE id = v_sender_id;

    IF v_sender_is_deactivated = TRUE THEN
        RAISE EXCEPTION 'Account is deactivated. Please contact support.' USING ERRCODE = '40301';
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

    -- Insert Message
    INSERT INTO public.chat_messages (
        room_id, sender_id, message_text
    ) VALUES (
        p_room_id, v_sender_id, p_message_text
    ) RETURNING id INTO v_msg_id;

    -- Sender name for notification
    SELECT full_name INTO v_sender_name FROM public.profiles WHERE id = v_sender_id;

    -- Create Recipient Notification
    PERFORM public.internal_create_notification(
        v_recipient_id,
        'CHAT_MESSAGE',
        'New message from ' || COALESCE(v_sender_name, 'User'),
        substr(p_message_text, 1, 100),
        'CHAT',
        p_room_id::text,
        'NOTIF-CHAT-' || v_msg_id::text
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'message_id', v_msg_id,
        'room_id', p_room_id,
        'sender_id', v_sender_id
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. MULTI-VENDOR SELLER FULFILLMENT STATUS RPC
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.seller_update_fulfillment_status(
    p_order_id TEXT,
    p_new_status TEXT,
    p_seller_store_id UUID DEFAULT NULL,
    p_courier_name TEXT DEFAULT NULL,
    p_tracking_number TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_current_user_id UUID;
    v_is_deactivated BOOLEAN;
    v_order RECORD;
    v_target_store_id UUID;
    v_store_count INT;
    v_old_status TEXT;
    v_all_delivered BOOLEAN;
    v_any_cancelled BOOLEAN;
    v_item RECORD;
    v_wallet_account_id UUID;
    v_payment_id UUID;
BEGIN
    v_current_user_id := auth.uid();
    IF v_current_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    -- Deactivated user guard
    SELECT is_deactivated INTO v_is_deactivated
    FROM public.profiles
    WHERE id = v_current_user_id;

    IF v_is_deactivated = TRUE THEN
        RAISE EXCEPTION 'Account is deactivated. Please contact support.' USING ERRCODE = '40301';
    END IF;

    IF p_new_status NOT IN ('Processing', 'Shipped', 'Delivered', 'Cancelled') THEN
        RAISE EXCEPTION 'Invalid fulfillment status: %', p_new_status USING ERRCODE = '22023';
    END IF;

    -- Fetch Order
    SELECT id, order_number, status, payment_status, payment_method, customer_user_id
    INTO v_order
    FROM public.buyer_orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF v_order.id IS NULL THEN
        RAISE EXCEPTION 'Order not found.' USING ERRCODE = 'P0002';
    END IF;

    -- Authorize seller through order_items: identify store(s) caller owns in this order
    IF p_seller_store_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.order_items oi
            JOIN public.seller_stores ss ON ss.id = oi.seller_store_id
            WHERE oi.order_id = p_order_id
              AND oi.seller_store_id = p_seller_store_id
              AND ss.owner_id = v_current_user_id
        ) THEN
            RAISE EXCEPTION 'Unauthorized to update fulfillment status for this store.' USING ERRCODE = '42501';
        END IF;
        v_target_store_id := p_seller_store_id;
    ELSE
        -- Support sellers owning more than one store: count matching stores
        SELECT COUNT(DISTINCT oi.seller_store_id) INTO v_store_count
        FROM public.order_items oi
        JOIN public.seller_stores ss ON ss.id = oi.seller_store_id
        WHERE oi.order_id = p_order_id
          AND ss.owner_id = v_current_user_id;

        IF v_store_count = 0 THEN
            RAISE EXCEPTION 'Unauthorized to update fulfillment status for this store.' USING ERRCODE = '42501';
        ELSIF v_store_count > 1 THEN
            RAISE EXCEPTION 'Multiple stores found for this order. Please specify p_seller_store_id.' USING ERRCODE = '22023';
        END IF;

        SELECT DISTINCT oi.seller_store_id INTO v_target_store_id
        FROM public.order_items oi
        JOIN public.seller_stores ss ON ss.id = oi.seller_store_id
        WHERE oi.order_id = p_order_id
          AND ss.owner_id = v_current_user_id;
    END IF;

    -- Store must be approved and active (not suspended)
    IF NOT public.is_approved_active_seller_store(v_target_store_id) THEN
        RAISE EXCEPTION 'Seller store is not approved or is suspended.' USING ERRCODE = '42501';
    END IF;

    -- Lock & Fetch store_fulfillment row
    SELECT fulfillment_status INTO v_old_status
    FROM public.store_fulfillments
    WHERE order_id = p_order_id
      AND seller_store_id = v_target_store_id
    FOR UPDATE;

    -- If no row exists yet, create it
    IF v_old_status IS NULL THEN
        INSERT INTO public.store_fulfillments (
            order_id, seller_store_id, fulfillment_status, courier_name, tracking_number, notes
        ) VALUES (
            p_order_id, v_target_store_id, 'Pending', p_courier_name, p_tracking_number, p_notes
        );
        v_old_status := 'Pending';
    END IF;

    -- Enforce state transitions
    IF v_old_status = 'Pending' AND p_new_status NOT IN ('Processing', 'Cancelled') THEN
        RAISE EXCEPTION 'Pending fulfillment can only transition to Processing or Cancelled.' USING ERRCODE = '22023';
    ELSIF v_old_status = 'Processing' AND p_new_status NOT IN ('Shipped', 'Cancelled') THEN
        RAISE EXCEPTION 'Processing fulfillment can only transition to Shipped or Cancelled.' USING ERRCODE = '22023';
    ELSIF v_old_status = 'Shipped' AND p_new_status NOT IN ('Delivered') THEN
        RAISE EXCEPTION 'Shipped fulfillment can only transition to Delivered.' USING ERRCODE = '22023';
    ELSIF v_old_status IN ('Delivered', 'Cancelled') THEN
        RAISE EXCEPTION 'Finalized fulfillments cannot change status.' USING ERRCODE = '22023';
    END IF;

    -- Update store_fulfillment
    UPDATE public.store_fulfillments
    SET fulfillment_status = p_new_status,
        courier_name = COALESCE(p_courier_name, courier_name),
        tracking_number = COALESCE(p_tracking_number, tracking_number),
        notes = COALESCE(p_notes, notes),
        shipped_at = CASE WHEN p_new_status = 'Shipped' THEN NOW() ELSE shipped_at END,
        delivered_at = CASE WHEN p_new_status = 'Delivered' THEN NOW() ELSE delivered_at END,
        updated_at = NOW()
    WHERE order_id = p_order_id AND seller_store_id = v_target_store_id;

    -- (d) On Delivered for Cash on Delivery: Mark cash collected & trigger seller balance accrual
    IF p_new_status = 'Delivered' AND v_order.payment_method IN ('Cash on Delivery', 'COD') THEN
        -- Mark payment row Collected
        UPDATE public.payments
        SET status = 'Collected', collected_at = NOW(), updated_at = NOW()
        WHERE order_id = p_order_id;

        -- Accrue seller payable balance for items belonging to this store
        SELECT id INTO v_wallet_account_id
        FROM public.wallet_accounts
        WHERE seller_store_id = v_target_store_id;

        IF v_wallet_account_id IS NOT NULL THEN
            FOR v_item IN (
                SELECT id, seller_payable, quantity, product_id, product_name
                FROM public.order_items
                WHERE order_id = p_order_id AND seller_store_id = v_target_store_id
            ) LOOP
                INSERT INTO public.wallet_transactions (
                    wallet_account_id, seller_store_id, transaction_type, amount,
                    source_type, source_id, idempotency_key, description, created_by
                ) VALUES (
                    v_wallet_account_id, v_target_store_id, 'CREDIT', v_item.seller_payable,
                    'ORDER_FULFILLMENT', v_item.id::TEXT, 'WLT-FUL-' || v_item.id::TEXT,
                    'Payout credit for ' || v_item.product_name, v_current_user_id
                ) ON CONFLICT (idempotency_key) DO NOTHING;
            END LOOP;

            UPDATE public.seller_stores
            SET pending_payout = GREATEST((SELECT available_balance FROM public.get_seller_wallet_summary(v_target_store_id)), 0.00),
                updated_at = NOW()
            WHERE id = v_target_store_id;
        END IF;
    END IF;

    -- (e) On Cancelled: Restore product stock for this store's items
    IF p_new_status = 'Cancelled' THEN
        FOR v_item IN (
            SELECT product_id, quantity
            FROM public.order_items
            WHERE order_id = p_order_id AND seller_store_id = v_target_store_id
        ) LOOP
            UPDATE public.products
            SET stock_quantity = stock_quantity + v_item.quantity,
                updated_at = NOW()
            WHERE id = v_item.product_id;
        END LOOP;
    END IF;

    -- Check overall order status: if all store_fulfillments are Delivered
    SELECT bool_and(fulfillment_status = 'Delivered'), bool_or(fulfillment_status = 'Cancelled')
    INTO v_all_delivered, v_any_cancelled
    FROM public.store_fulfillments
    WHERE order_id = p_order_id;

    IF v_all_delivered = TRUE THEN
        UPDATE public.buyer_orders
        SET status = 'Delivered',
            payment_status = CASE WHEN payment_method IN ('Cash on Delivery', 'COD') THEN 'Paid' ELSE payment_status END,
            updated_at = NOW()
        WHERE id = p_order_id;
    ELSIF p_new_status = 'Shipped' AND v_order.status NOT IN ('Delivered', 'Cancelled') THEN
        UPDATE public.buyer_orders SET status = 'Shipped', updated_at = NOW() WHERE id = p_order_id;
    ELSIF p_new_status = 'Processing' AND v_order.status = 'Pending' THEN
        UPDATE public.buyer_orders SET status = 'Processing', updated_at = NOW() WHERE id = p_order_id;
    END IF;

    -- (f) Insert order tracking event
    INSERT INTO public.order_tracking_events (
        order_id, seller_store_id, event_type, description, location
    ) VALUES (
        p_order_id, v_target_store_id, p_new_status,
        'Fulfillment updated to ' || p_new_status || COALESCE(' (' || p_notes || ')', ''),
        COALESCE(p_courier_name, 'Courier Facility')
    );

    -- (f) Notify buyer of fulfillment change
    PERFORM public.internal_create_notification(
        v_order.customer_user_id,
        'ORDER_FULFILLMENT',
        'Order ' || COALESCE(v_order.order_number, p_order_id) || ' Status Update',
        'Your order items from store have updated to ' || p_new_status,
        'ORDER',
        p_order_id,
        'NOTIF-ORD-' || p_order_id || '-' || v_target_store_id::TEXT || '-' || p_new_status
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'order_id', p_order_id,
        'seller_store_id', v_target_store_id,
        'fulfillment_status', p_new_status
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.seller_update_fulfillment_status(TEXT, TEXT, UUID, TEXT, TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 3. REPLACE is_admin() IN ALL RLS POLICIES WITH has_permission(module, action)
-- ----------------------------------------------------------------------------

-- A. user_roles
DROP POLICY IF EXISTS "Users and admins can view relevant user roles" ON public.user_roles;
CREATE POLICY "Users and admins can view relevant user roles" ON public.user_roles
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR public.has_permission('roles', 'view')
        OR public.is_admin()
    );

-- B. profiles
DROP POLICY IF EXISTS "Users can view own full profile" ON public.profiles;
CREATE POLICY "Users can view own full profile" ON public.profiles
    FOR SELECT TO authenticated
    USING (
        auth.uid() = id
        OR public.has_permission('customers', 'view')
        OR public.is_admin()
    );

-- C. seller_stores
DROP POLICY IF EXISTS "Public view approved stores; Owner/Admin view all" ON public.seller_stores;
CREATE POLICY "Public view approved stores; Owner/Admin view all" ON public.seller_stores
    FOR SELECT TO authenticated, anon
    USING (
        is_approved = TRUE
        OR auth.uid() = owner_id
        OR public.has_permission('sellers', 'view')
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "Store owners update safe business details" ON public.seller_stores;
CREATE POLICY "Store owners update safe business details" ON public.seller_stores
    FOR UPDATE TO authenticated
    USING (
        auth.uid() = owner_id
        OR public.has_permission('sellers', 'edit')
        OR public.is_admin()
    );

-- D. seller_kyc_documents
DROP POLICY IF EXISTS "Sellers view own KYC; Admins view all" ON public.seller_kyc_documents;
CREATE POLICY "Sellers view own KYC; Admins view all" ON public.seller_kyc_documents
    FOR SELECT TO authenticated
    USING (
        public.owns_seller_store(seller_store_id)
        OR public.has_permission('kyc', 'view')
        OR public.is_admin()
    );

-- E. categories
DROP POLICY IF EXISTS "Categories visible to all if active; Admins view all" ON public.categories;
CREATE POLICY "Categories visible to all if active; Admins view all" ON public.categories
    FOR SELECT TO authenticated, anon
    USING (
        is_active = TRUE
        OR public.has_permission('categories', 'view')
        OR public.is_admin()
    );

DROP POLICY IF EXISTS "Admins have full category management" ON public.categories;
CREATE POLICY "Admins have full category management" ON public.categories
    FOR ALL TO authenticated
    USING (
        public.has_permission('categories', 'edit')
        OR public.is_admin()
    );

-- F. products
DROP POLICY IF EXISTS "Public view active approved products; Owners/Admins view all" ON public.products;
CREATE POLICY "Public view active approved products; Owners/Admins view all" ON public.products
    FOR SELECT TO authenticated, anon
    USING (
        (is_active = TRUE AND approval_status = 'approved')
        OR public.owns_seller_store(seller_store_id)
        OR public.has_permission('products', 'view')
        OR public.is_admin()
    );

-- G. buyer_orders
DROP POLICY IF EXISTS "Buyer orders read policy" ON public.buyer_orders;
DROP POLICY IF EXISTS "Buyer view own orders; Admins view all" ON public.buyer_orders;
CREATE POLICY "Buyer view own orders; Admins view all" ON public.buyer_orders
    FOR SELECT TO authenticated
    USING (
        customer_user_id = auth.uid()
        OR public.has_permission('orders', 'view')
        OR public.is_admin()
    );

-- H. platform_vouchers
DROP POLICY IF EXISTS "Admins view all vouchers" ON public.platform_vouchers;
CREATE POLICY "Admins view all vouchers" ON public.platform_vouchers
    FOR SELECT TO authenticated
    USING (
        public.has_permission('promotions', 'view')
        OR public.is_admin()
    );

-- I. seller_payout_requests
DROP POLICY IF EXISTS "Payout requests visibility" ON public.seller_payout_requests;
CREATE POLICY "Payout requests visibility" ON public.seller_payout_requests
    FOR SELECT TO authenticated
    USING (
        public.owns_seller_store(seller_store_id)
        OR public.has_permission('payouts', 'view')
        OR public.is_admin()
    );

-- J. wallet_accounts
DROP POLICY IF EXISTS "Wallet accounts visibility" ON public.wallet_accounts;
CREATE POLICY "Wallet accounts visibility" ON public.wallet_accounts
    FOR SELECT TO authenticated
    USING (
        public.owns_seller_store(seller_store_id)
        OR public.has_permission('finance', 'view')
        OR public.is_admin()
    );

-- ----------------------------------------------------------------------------
-- 4. ACCOUNT DEACTIVATION & REACTIVATION GOVERNANCE
-- ----------------------------------------------------------------------------

-- Column-level revocation on profiles(is_deactivated, deactivated_at)
REVOKE UPDATE (is_deactivated, deactivated_at) ON public.profiles FROM authenticated;

-- Deactivation function with authority checks
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
    v_is_owner BOOLEAN;
    v_target_has_staff_role BOOLEAN;
    v_target_is_owner BOOLEAN;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    -- Caller checks
    v_is_owner := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (role = 'owner'::public.app_role OR staff_role = 'owner'::public.admin_staff_role)
    );

    -- Target checks
    v_target_is_owner := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = p_user_id
          AND (role = 'owner'::public.app_role OR staff_role = 'owner'::public.admin_staff_role)
    );

    IF v_target_is_owner THEN
        RAISE EXCEPTION 'Deactivation of the Owner role is prohibited.' USING ERRCODE = '42501';
    END IF;

    v_target_has_staff_role := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = p_user_id
          AND (role IN ('super_admin'::public.app_role, 'admin'::public.app_role) OR staff_role IS NOT NULL)
    );

    -- Rule (a): Only owner can deactivate a staff or super_admin account
    IF v_target_has_staff_role AND NOT v_is_owner THEN
        RAISE EXCEPTION 'Access denied: Only Owner can deactivate staff or super_admin accounts.' USING ERRCODE = '42501';
    END IF;

    -- Staff with customers:suspend may only deactivate normal buyer/seller accounts
    IF NOT v_is_owner AND v_caller_id != p_user_id THEN
        IF NOT public.has_permission('customers', 'suspend') THEN
            RAISE EXCEPTION 'Access denied: Insufficient privileges to deactivate user accounts.' USING ERRCODE = '42501';
        END IF;
    END IF;

    UPDATE public.profiles
    SET is_deactivated = TRUE,
        deactivated_at = NOW()
    WHERE id = p_user_id;

    v_audit_id := public.internal_record_audit_log(
        'profiles',
        p_user_id::TEXT,
        'USER_ACCOUNT_DEACTIVATED',
        jsonb_build_object('deactivated_by', v_caller_id, 'reason', p_reason)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'user_id', p_user_id,
        'is_deactivated', TRUE,
        'audit_log_id', v_audit_id
    );
END;
$$;

-- Reactivation function
CREATE OR REPLACE FUNCTION public.admin_reactivate_user_account(
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
    v_is_owner BOOLEAN;
    v_target_has_staff_role BOOLEAN;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    v_is_owner := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = v_caller_id
          AND (role = 'owner'::public.app_role OR staff_role = 'owner'::public.admin_staff_role)
    );

    v_target_has_staff_role := EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = p_user_id
          AND (role IN ('super_admin'::public.app_role, 'admin'::public.app_role) OR staff_role IS NOT NULL)
    );

    IF v_target_has_staff_role AND NOT v_is_owner THEN
        RAISE EXCEPTION 'Access denied: Only Owner can reactivate staff or super_admin accounts.' USING ERRCODE = '42501';
    END IF;

    IF NOT v_is_owner THEN
        IF NOT public.has_permission('customers', 'suspend') THEN
            RAISE EXCEPTION 'Access denied: Insufficient privileges to reactivate accounts.' USING ERRCODE = '42501';
        END IF;
    END IF;

    UPDATE public.profiles
    SET is_deactivated = FALSE,
        deactivated_at = NULL
    WHERE id = p_user_id;

    v_audit_id := public.internal_record_audit_log(
        'profiles',
        p_user_id::TEXT,
        'USER_ACCOUNT_REACTIVATED',
        jsonb_build_object('reactivated_by', v_caller_id, 'reason', p_reason)
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'user_id', p_user_id,
        'is_deactivated', FALSE,
        'audit_log_id', v_audit_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_reactivate_user_account(UUID, TEXT) TO authenticated;

-- Guard create_chat_room against deactivated users
CREATE OR REPLACE FUNCTION public.create_chat_room(
    p_seller_store_id UUID,
    p_product_id UUID DEFAULT NULL,
    p_order_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_buyer_id UUID;
    v_is_deactivated BOOLEAN;
    v_room_id UUID;
    v_order_belongs BOOLEAN;
BEGIN
    v_buyer_id := auth.uid();
    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    SELECT is_deactivated INTO v_is_deactivated FROM public.profiles WHERE id = v_buyer_id;
    IF v_is_deactivated = TRUE THEN
        RAISE EXCEPTION 'Account is deactivated. Please contact support.' USING ERRCODE = '40301';
    END IF;

    IF NOT public.is_approved_active_seller_store(p_seller_store_id) THEN
        RAISE EXCEPTION 'Store is not active or approved.' USING ERRCODE = '42501';
    END IF;

    IF p_order_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.buyer_orders bo
            JOIN public.order_items oi ON oi.order_id = bo.id
            WHERE bo.id = p_order_id
              AND bo.customer_user_id = v_buyer_id
              AND oi.seller_store_id = p_seller_store_id
        ) INTO v_order_belongs;

        IF NOT v_order_belongs THEN
            RAISE EXCEPTION 'Order does not belong to buyer or does not contain items from this store.' USING ERRCODE = '42501';
        END IF;
    END IF;

    -- Idempotent upsert
    INSERT INTO public.chat_rooms (
        buyer_user_id, seller_store_id, product_id, order_id
    ) VALUES (
        v_buyer_id, p_seller_store_id, p_product_id, p_order_id
    )
    ON CONFLICT (buyer_user_id, seller_store_id, COALESCE(product_id, '00000000-0000-0000-0000-000000000000'::uuid))
    DO UPDATE SET updated_at = NOW()
    RETURNING id INTO v_room_id;

    RETURN jsonb_build_object('success', TRUE, 'room_id', v_room_id);
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. REAL TABLES & RPCS FOR SCREEN 2 (FRAUD & SECURITY)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.fraud_risk_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type TEXT NOT NULL CHECK (entity_type IN ('Store', 'Buyer')),
    entity_id TEXT NOT NULL,
    entity_name TEXT NOT NULL,
    risk_score INT NOT NULL CHECK (risk_score >= 0 AND risk_score <= 100),
    risk_factor TEXT NOT NULL,
    ip_address TEXT,
    device_hash TEXT,
    location TEXT,
    status TEXT NOT NULL DEFAULT 'High Risk' CHECK (status IN ('High Risk', 'Medium Warning', 'Resolved', 'Frozen')),
    resolved_by UUID REFERENCES auth.users(id),
    resolution_notes TEXT,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.fraud_risk_alerts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.fraud_risk_alerts FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.fraud_risk_alerts TO authenticated;

CREATE POLICY "Fraud alerts visibility" ON public.fraud_risk_alerts
    FOR SELECT TO authenticated
    USING (public.has_permission('fraud', 'view') OR public.is_admin());

CREATE TABLE IF NOT EXISTS public.fraud_blacklisted_identifiers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    identifier_type TEXT NOT NULL CHECK (identifier_type IN ('IP', 'CNIC', 'Bank IBAN', 'Phone Number')),
    identifier_value TEXT NOT NULL,
    holder_name TEXT,
    reason TEXT NOT NULL,
    threat_level TEXT NOT NULL DEFAULT 'High' CHECK (threat_level IN ('High', 'Critical', 'Suspicious')),
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fraud_blacklisted_ident_key UNIQUE (identifier_type, identifier_value)
);

ALTER TABLE public.fraud_blacklisted_identifiers ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.fraud_blacklisted_identifiers FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.fraud_blacklisted_identifiers TO authenticated;

CREATE POLICY "Fraud blacklist visibility" ON public.fraud_blacklisted_identifiers
    FOR SELECT TO authenticated
    USING (public.has_permission('fraud', 'view') OR public.is_admin());

CREATE TABLE IF NOT EXISTS public.fraud_security_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_code TEXT UNIQUE NOT NULL,
    rule_title TEXT NOT NULL,
    description TEXT NOT NULL,
    threshold_value TEXT NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.fraud_security_rules ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.fraud_security_rules FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.fraud_security_rules TO authenticated;

CREATE POLICY "Fraud security rules visibility" ON public.fraud_security_rules
    FOR SELECT TO authenticated
    USING (public.has_permission('fraud', 'view') OR public.is_admin());

-- Seed initial Security Rules
INSERT INTO public.fraud_security_rules (rule_code, rule_title, description, threshold_value, is_enabled) VALUES
    ('VELOCITY_LIMIT', 'Velocity Abuse Threshold', 'Max orders per buyer window before triggering automatic review', '5 orders / 10m', TRUE),
    ('DEVICE_COLLISION', 'Device Hash Collisions', 'Max accounts linked to same device fingerprint before suspension', '3 accounts', TRUE),
    ('GEO_IP_MISMATCH', 'Geo-IP Distance Threshold', 'Discrepancy between IP location and shipping address', '> 150 km', TRUE),
    ('COD_RETURN_RATE', 'COD High Return Rate Flag', 'COD return/refusal rate exceeding acceptable benchmark', '30% of orders', TRUE)
ON CONFLICT (rule_code) DO NOTHING;

-- Fraud RPC 1: Fetch Alerts with Server Pagination & Join
CREATE OR REPLACE FUNCTION public.admin_fetch_fraud_alerts(
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0,
    p_status TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_results JSONB;
    v_total INT;
BEGIN
    IF NOT (public.has_permission('fraud', 'view') OR public.is_admin()) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to view fraud alerts.' USING ERRCODE = '42501';
    END IF;

    SELECT COUNT(*) INTO v_total
    FROM public.fraud_risk_alerts
    WHERE (p_status IS NULL OR status = p_status);

    SELECT jsonb_build_object(
        'total_count', v_total,
        'alerts', COALESCE(jsonb_agg(sub), '[]'::jsonb)
    ) INTO v_results
    FROM (
        SELECT id, entity_type, entity_id, entity_name, risk_score, risk_factor,
               ip_address, device_hash, location, status, created_at
        FROM public.fraud_risk_alerts
        WHERE (p_status IS NULL OR status = p_status)
        ORDER BY risk_score DESC, created_at DESC
        LIMIT p_limit OFFSET p_offset
    ) sub;

    RETURN v_results;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_fetch_fraud_alerts(INT, INT, TEXT) TO authenticated;

-- Fraud RPC 2: Resolve Fraud Alert
CREATE OR REPLACE FUNCTION public.admin_resolve_fraud_alert(
    p_alert_id UUID,
    p_resolution TEXT, -- 'Resolved' or 'Frozen'
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_alert RECORD;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF NOT (public.has_permission('fraud', 'score') OR public.has_permission('fraud', 'audit') OR public.is_admin()) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to resolve fraud alerts.' USING ERRCODE = '42501';
    END IF;

    IF p_resolution NOT IN ('Resolved', 'Frozen') THEN
        RAISE EXCEPTION 'Invalid resolution status: %. Must be Resolved or Frozen.', p_resolution USING ERRCODE = '22023';
    END IF;

    SELECT id, entity_type, entity_id, entity_name, risk_score INTO v_alert
    FROM public.fraud_risk_alerts
    WHERE id = p_alert_id
    FOR UPDATE;

    IF v_alert.id IS NULL THEN
        RAISE EXCEPTION 'Fraud alert not found.' USING ERRCODE = 'P0002';
    END IF;

    UPDATE public.fraud_risk_alerts
    SET status = p_resolution,
        resolved_by = v_caller_id,
        resolution_notes = p_notes,
        resolved_at = NOW(),
        updated_at = NOW()
    WHERE id = p_alert_id;

    v_audit_id := public.internal_record_audit_log(
        'fraud_risk_alerts',
        p_alert_id::TEXT,
        'FRAUD_ALERT_RESOLVED',
        jsonb_build_object(
            'resolution', p_resolution,
            'entity_type', v_alert.entity_type,
            'entity_id', v_alert.entity_id,
            'notes', p_notes
        )
    );

    RETURN jsonb_build_object(
        'success', TRUE,
        'alert_id', p_alert_id,
        'status', p_resolution,
        'audit_log_id', v_audit_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_resolve_fraud_alert(UUID, TEXT, TEXT) TO authenticated;

-- Fraud RPC 3: Add Blacklisted Identifier
CREATE OR REPLACE FUNCTION public.admin_add_blacklisted_identifier(
    p_identifier_type TEXT,
    p_identifier_value TEXT,
    p_holder_name TEXT,
    p_reason TEXT,
    p_threat_level TEXT DEFAULT 'High'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_id UUID;
    v_audit_id UUID;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF NOT (public.has_permission('fraud', 'blacklist') OR public.is_admin()) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to manage fraud blacklist.' USING ERRCODE = '42501';
    END IF;

    IF p_identifier_type NOT IN ('IP', 'CNIC', 'Bank IBAN', 'Phone Number') THEN
        RAISE EXCEPTION 'Invalid identifier type: %', p_identifier_type USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.fraud_blacklisted_identifiers (
        identifier_type, identifier_value, holder_name, reason, threat_level, created_by
    ) VALUES (
        p_identifier_type, trim(p_identifier_value), p_holder_name, p_reason, p_threat_level, v_caller_id
    ) RETURNING id INTO v_id;

    v_audit_id := public.internal_record_audit_log(
        'fraud_blacklisted_identifiers',
        v_id::TEXT,
        'BLACKLIST_IDENTIFIER_ADDED',
        jsonb_build_object(
            'type', p_identifier_type,
            'value', p_identifier_value,
            'reason', p_reason
        )
    );

    RETURN jsonb_build_object('success', TRUE, 'blacklist_id', v_id, 'audit_log_id', v_audit_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_add_blacklisted_identifier(TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- Fraud RPC 4: Remove Blacklisted Identifier
CREATE OR REPLACE FUNCTION public.admin_remove_blacklisted_identifier(
    p_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_audit_id UUID;
    v_item RECORD;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF NOT (public.has_permission('fraud', 'blacklist') OR public.is_admin()) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to manage fraud blacklist.' USING ERRCODE = '42501';
    END IF;

    SELECT id, identifier_type, identifier_value INTO v_item
    FROM public.fraud_blacklisted_identifiers
    WHERE id = p_id;

    IF v_item.id IS NULL THEN
        RAISE EXCEPTION 'Blacklisted identifier not found.' USING ERRCODE = 'P0002';
    END IF;

    DELETE FROM public.fraud_blacklisted_identifiers WHERE id = p_id;

    v_audit_id := public.internal_record_audit_log(
        'fraud_blacklisted_identifiers',
        p_id::TEXT,
        'BLACKLIST_IDENTIFIER_REMOVED',
        jsonb_build_object('type', v_item.identifier_type, 'value', v_item.identifier_value)
    );

    RETURN jsonb_build_object('success', TRUE, 'id', p_id, 'audit_log_id', v_audit_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_remove_blacklisted_identifier(UUID) TO authenticated;

-- Fraud RPC 5: Toggle Security Rule
CREATE OR REPLACE FUNCTION public.admin_toggle_security_rule(
    p_rule_id UUID,
    p_is_enabled BOOLEAN,
    p_threshold_value TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_caller_id UUID;
    v_audit_id UUID;
    v_rule_code TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
    END IF;

    IF NOT (public.has_permission('fraud', 'audit') OR public.has_permission('fraud', 'score') OR public.is_admin()) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to modify fraud security rules.' USING ERRCODE = '42501';
    END IF;

    UPDATE public.fraud_security_rules
    SET is_enabled = p_is_enabled,
        threshold_value = COALESCE(p_threshold_value, threshold_value),
        updated_by = v_caller_id,
        updated_at = NOW()
    WHERE id = p_rule_id
    RETURNING rule_code INTO v_rule_code;

    IF v_rule_code IS NULL THEN
        RAISE EXCEPTION 'Security rule not found.' USING ERRCODE = 'P0002';
    END IF;

    v_audit_id := public.internal_record_audit_log(
        'fraud_security_rules',
        p_rule_id::TEXT,
        'SECURITY_RULE_MODIFIED',
        jsonb_build_object('rule_code', v_rule_code, 'is_enabled', p_is_enabled, 'threshold', p_threshold_value)
    );

    RETURN jsonb_build_object('success', TRUE, 'rule_id', p_rule_id, 'is_enabled', p_is_enabled, 'audit_log_id', v_audit_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_toggle_security_rule(UUID, BOOLEAN, TEXT) TO authenticated;
