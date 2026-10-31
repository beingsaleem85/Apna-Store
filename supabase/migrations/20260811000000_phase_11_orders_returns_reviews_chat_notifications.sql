-- ============================================================================
-- APNA STORE — PHASE 11: ORDERS, RETURNS, REVIEWS, CHAT, NOTIFICATIONS & TRACKING
-- Migration: 20260811000000_phase_11_orders_returns_reviews_chat_notifications.sql
-- Purpose: Canonical Multi-Seller Fulfillments, Returns, Reviews, Persisted Chat,
--          Server-Created Notifications & Manual Courier Tracking Events
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. SEED PHASE 11 RBAC PERMISSIONS
-- ----------------------------------------------------------------------------
INSERT INTO public.role_permissions (role, module, action) VALUES
    ('admin'::public.app_role, 'orders', 'manage'),
    ('admin'::public.app_role, 'returns', 'review'),
    ('admin'::public.app_role, 'reviews', 'moderate'),
    ('admin'::public.app_role, 'chat', 'monitor')
ON CONFLICT (role, module, action) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 2. EXTEND order_status_history WITH seller_store_id & TRANSITION DETAILS
-- ----------------------------------------------------------------------------
ALTER TABLE public.order_status_history
    ADD COLUMN IF NOT EXISTS seller_store_id UUID REFERENCES public.seller_stores(id),
    ADD COLUMN IF NOT EXISTS old_status TEXT,
    ADD COLUMN IF NOT EXISTS actor_user_id UUID REFERENCES auth.users(id),
    ADD COLUMN IF NOT EXISTS actor_role TEXT;

-- ----------------------------------------------------------------------------
-- 3. CANONICAL store_fulfillments TABLE (MULTI-SELLER FULFILLMENT AUTHORITY)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.store_fulfillments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id TEXT NOT NULL REFERENCES public.buyer_orders(id) ON DELETE CASCADE,
    seller_store_id UUID NOT NULL REFERENCES public.seller_stores(id),
    fulfillment_status TEXT NOT NULL DEFAULT 'Pending' CHECK (fulfillment_status IN ('Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled')),
    courier_name TEXT,
    tracking_number TEXT,
    shipped_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT store_fulfillments_order_store_key UNIQUE (order_id, seller_store_id)
);

ALTER TABLE public.store_fulfillments ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_store_fulfillments_order ON public.store_fulfillments(order_id);
CREATE INDEX IF NOT EXISTS idx_store_fulfillments_store ON public.store_fulfillments(seller_store_id);

REVOKE ALL ON public.store_fulfillments FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.store_fulfillments TO authenticated;

-- RLS: Buyer views fulfillments for own orders; Seller views own store fulfillments; Admin with orders:manage views all
CREATE POLICY "Fulfillment visibility policy" ON public.store_fulfillments
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.buyer_orders bo
            WHERE bo.id = public.store_fulfillments.order_id
              AND bo.customer_user_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM public.seller_stores ss
            WHERE ss.id = public.store_fulfillments.seller_store_id
              AND ss.owner_id = auth.uid()
        )
        OR public.has_permission('orders', 'manage')
    );

-- Trigger: Automatically seed store_fulfillments on order_items insert
CREATE OR REPLACE FUNCTION public.trg_auto_create_store_fulfillments()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.store_fulfillments (order_id, seller_store_id, fulfillment_status)
    VALUES (NEW.order_id, NEW.seller_store_id, 'Pending')
    ON CONFLICT (order_id, seller_store_id) DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

DROP TRIGGER IF EXISTS trg_auto_create_store_fulfillments ON public.order_items;
CREATE TRIGGER trg_auto_create_store_fulfillments
    AFTER INSERT ON public.order_items
    FOR EACH ROW EXECUTE FUNCTION public.trg_auto_create_store_fulfillments();

-- ----------------------------------------------------------------------------
-- 4. CANONICAL order_tracking_events TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.order_tracking_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id TEXT NOT NULL REFERENCES public.buyer_orders(id) ON DELETE CASCADE,
    seller_store_id UUID REFERENCES public.seller_stores(id),
    event_type TEXT NOT NULL,
    description TEXT NOT NULL,
    location TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.order_tracking_events ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_tracking_events_order ON public.order_tracking_events(order_id);

REVOKE ALL ON public.order_tracking_events FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.order_tracking_events TO authenticated;

CREATE POLICY "Tracking visibility policy" ON public.order_tracking_events
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.buyer_orders bo
            WHERE bo.id = public.order_tracking_events.order_id
              AND bo.customer_user_id = auth.uid()
        )
        OR EXISTS (
            SELECT 1 FROM public.seller_stores ss
            WHERE ss.id = public.order_tracking_events.seller_store_id
              AND ss.owner_id = auth.uid()
        )
        OR public.has_permission('orders', 'manage')
    );

-- ----------------------------------------------------------------------------
-- 5. CANONICAL return_requests TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.return_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id TEXT NOT NULL REFERENCES public.buyer_orders(id),
    order_item_id UUID NOT NULL REFERENCES public.order_items(id),
    seller_store_id UUID NOT NULL REFERENCES public.seller_stores(id),
    customer_user_id UUID NOT NULL REFERENCES auth.users(id),
    quantity INT NOT NULL CHECK (quantity > 0),
    reason TEXT NOT NULL CHECK (length(trim(reason)) > 0),
    description TEXT,
    evidence_paths TEXT[] DEFAULT '{}'::TEXT[],
    status TEXT NOT NULL DEFAULT 'Requested' CHECK (status IN ('Requested', 'Approved', 'Rejected', 'Completed')),
    admin_notes TEXT,
    processed_by UUID REFERENCES auth.users(id),
    refund_id UUID REFERENCES public.refunds(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.return_requests ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_return_requests_order ON public.return_requests(order_id);
CREATE INDEX IF NOT EXISTS idx_return_requests_seller ON public.return_requests(seller_store_id);
CREATE INDEX IF NOT EXISTS idx_return_requests_customer ON public.return_requests(customer_user_id);

REVOKE ALL ON public.return_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.return_requests TO anon, authenticated;

CREATE POLICY "Return requests select policy" ON public.return_requests
    FOR SELECT USING (
        customer_user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.seller_stores ss
            WHERE ss.id = public.return_requests.seller_store_id
              AND ss.owner_id = auth.uid()
        )
        OR public.has_permission('returns', 'review')
        OR public.has_permission('finance', 'view')
    );

-- ----------------------------------------------------------------------------
-- 6. CANONICAL product_reviews TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.product_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    order_item_id UUID UNIQUE NOT NULL REFERENCES public.order_items(id),
    buyer_user_id UUID NOT NULL REFERENCES auth.users(id),
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT NOT NULL CHECK (length(trim(comment)) > 0 AND length(comment) <= 1000),
    is_verified_purchase BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.product_reviews ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_product_reviews_product ON public.product_reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_product_reviews_buyer ON public.product_reviews(buyer_user_id);

REVOKE ALL ON public.product_reviews FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.product_reviews TO anon, authenticated;

CREATE POLICY "Public read reviews" ON public.product_reviews
    FOR SELECT USING (TRUE);

-- ----------------------------------------------------------------------------
-- 7. CANONICAL chat_rooms AND chat_messages TABLES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chat_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    buyer_user_id UUID NOT NULL REFERENCES auth.users(id),
    seller_store_id UUID NOT NULL REFERENCES public.seller_stores(id),
    product_id UUID REFERENCES public.products(id),
    order_id TEXT REFERENCES public.buyer_orders(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chat_rooms_buyer_seller_product_key UNIQUE (buyer_user_id, seller_store_id, product_id)
);

ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_chat_rooms_buyer ON public.chat_rooms(buyer_user_id);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_seller ON public.chat_rooms(seller_store_id);

REVOKE ALL ON public.chat_rooms FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.chat_rooms TO authenticated;

CREATE POLICY "Chat room participant select" ON public.chat_rooms
    FOR SELECT USING (
        buyer_user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.seller_stores ss
            WHERE ss.id = public.chat_rooms.seller_store_id
              AND ss.owner_id = auth.uid()
        )
        OR public.has_permission('chat', 'monitor')
    );

CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id),
    message_text TEXT NOT NULL CHECK (length(trim(message_text)) > 0 AND length(message_text) <= 2000),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_chat_messages_room ON public.chat_messages(room_id);

REVOKE ALL ON public.chat_messages FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.chat_messages TO authenticated;

CREATE POLICY "Chat message participant select" ON public.chat_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.chat_rooms cr
            WHERE cr.id = public.chat_messages.room_id
              AND (
                  cr.buyer_user_id = auth.uid()
                  OR EXISTS (
                      SELECT 1 FROM public.seller_stores ss
                      WHERE ss.id = cr.seller_store_id AND ss.owner_id = auth.uid()
                  )
                  OR public.has_permission('chat', 'monitor')
              )
        )
    );

-- ----------------------------------------------------------------------------
-- 8. CANONICAL notifications TABLE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    entity_type TEXT,
    entity_id TEXT,
    event_key TEXT UNIQUE,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON public.notifications(user_id, is_read);

REVOKE ALL ON public.notifications FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.notifications TO authenticated;

CREATE POLICY "User views own notifications" ON public.notifications
    FOR SELECT USING (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- 9. PRIVATE STORAGE BUCKET FOR RETURN EVIDENCE
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'return-evidence',
    'return-evidence',
    FALSE,
    10485760, -- 10MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
) ON CONFLICT (id) DO UPDATE SET
    public = FALSE,
    file_size_limit = 10485760;

DROP POLICY IF EXISTS "Return evidence upload policy" ON storage.objects;
CREATE POLICY "Return evidence upload policy" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'return-evidence'
        AND auth.role() = 'authenticated'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS "Return evidence select policy" ON storage.objects;
CREATE POLICY "Return evidence select policy" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'return-evidence'
        AND auth.role() = 'authenticated'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR public.has_permission('returns', 'review')
            OR public.has_permission('finance', 'view')
            OR EXISTS (
                SELECT 1 FROM public.return_requests rr
                JOIN public.seller_stores ss ON ss.id = rr.seller_store_id
                WHERE ss.owner_id = auth.uid()
                  AND name = ANY(rr.evidence_paths)
            )
        )
    );

-- ----------------------------------------------------------------------------
-- 10. SERVER-AUTHORITATIVE RPC: INTERNAL NOTIFICATION HELPER
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.internal_create_notification(
    p_user_id UUID,
    p_type TEXT,
    p_title TEXT,
    p_body TEXT,
    p_entity_type TEXT DEFAULT NULL,
    p_entity_id TEXT DEFAULT NULL,
    p_event_key TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO public.notifications (
        user_id, type, title, body, entity_type, entity_id, event_key
    ) VALUES (
        p_user_id, p_type, p_title, p_body, p_entity_type, p_entity_id, p_event_key
    ) ON CONFLICT (event_key) DO NOTHING
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

REVOKE EXECUTE ON FUNCTION public.internal_create_notification FROM PUBLIC, anon, authenticated;

-- ----------------------------------------------------------------------------
-- 11. SERVER-AUTHORITATIVE RPC: MARK NOTIFICATION AS READ
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    UPDATE public.notifications
    SET is_read = TRUE, read_at = NOW()
    WHERE id = p_notification_id
      AND user_id = v_user_id;

    RETURN jsonb_build_object('success', TRUE, 'notification_id', p_notification_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.mark_notification_read(UUID) TO authenticated;

-- ----------------------------------------------------------------------------
-- 12. SERVER-AUTHORITATIVE RPC: SELLER UPDATE STORE FULFILLMENT STATUS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.seller_update_fulfillment_status(
    p_order_id TEXT,
    p_new_status TEXT,
    p_seller_store_id UUID DEFAULT NULL,
    p_courier_name TEXT DEFAULT NULL,
    p_tracking_number TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_seller_user_id UUID;
    v_store_id UUID;
    v_old_status TEXT;
    v_order_customer_id UUID;
    v_shipped_count INT;
    v_delivered_count INT;
    v_total_fulfillments INT;
    v_derived_parent_status TEXT;
    v_result JSONB;
BEGIN
    v_seller_user_id := auth.uid();
    IF v_seller_user_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF p_new_status NOT IN ('Processing', 'Shipped', 'Delivered') THEN
        RAISE EXCEPTION 'Invalid fulfillment target status: %', p_new_status;
    END IF;

    IF p_seller_store_id IS NOT NULL THEN
        IF NOT (
            EXISTS (SELECT 1 FROM public.seller_stores WHERE id = p_seller_store_id AND owner_id = v_seller_user_id)
            OR public.has_permission('orders', 'manage')
        ) THEN
            RAISE EXCEPTION 'Access denied: You do not own store %.', p_seller_store_id;
        END IF;
        v_store_id := p_seller_store_id;
    ELSE
        SELECT ss.id INTO v_store_id
        FROM public.seller_stores ss
        WHERE ss.owner_id = v_seller_user_id;
    END IF;

    IF v_store_id IS NULL THEN
        RAISE EXCEPTION 'Seller store not found for authenticated user.';
    END IF;

    -- Lock & Fetch Store Fulfillment Row
    SELECT fulfillment_status INTO v_old_status
    FROM public.store_fulfillments
    WHERE order_id = p_order_id
      AND seller_store_id = v_store_id
    FOR UPDATE;

    IF v_old_status IS NULL THEN
        RAISE EXCEPTION 'Fulfillment record not found for order % and store %.', p_order_id, v_store_id;
    END IF;

    IF v_old_status = 'Cancelled' THEN
        RAISE EXCEPTION 'Cannot update status of cancelled store fulfillment.';
    END IF;

    -- Strict Transition Logic
    IF p_new_status = 'Processing' AND v_old_status <> 'Pending' THEN
        RAISE EXCEPTION 'Invalid transition: Store fulfillment can only move to Processing from Pending (Current: %).', v_old_status;
    ELSIF p_new_status = 'Shipped' AND v_old_status NOT IN ('Pending', 'Processing') THEN
        RAISE EXCEPTION 'Invalid transition: Store fulfillment can only move to Shipped from Pending or Processing (Current: %).', v_old_status;
    ELSIF p_new_status = 'Delivered' THEN
        -- Delivery confirmation requires Shipped status or Admin permission
        IF v_old_status <> 'Shipped' AND NOT public.has_permission('orders', 'manage') THEN
            RAISE EXCEPTION 'Invalid transition: Store fulfillment can only move to Delivered from Shipped status (Current: %).', v_old_status;
        END IF;
    END IF;

    -- Update Store Fulfillment Record
    UPDATE public.store_fulfillments
    SET fulfillment_status = p_new_status,
        courier_name = COALESCE(p_courier_name, courier_name),
        tracking_number = COALESCE(p_tracking_number, tracking_number),
        shipped_at = CASE WHEN p_new_status = 'Shipped' THEN COALESCE(shipped_at, NOW()) ELSE shipped_at END,
        delivered_at = CASE WHEN p_new_status = 'Delivered' THEN COALESCE(delivered_at, NOW()) ELSE delivered_at END,
        notes = COALESCE(p_notes, notes),
        updated_at = NOW()
    WHERE order_id = p_order_id
      AND seller_store_id = v_store_id;

    -- Fetch Customer User ID for Order
    SELECT customer_user_id INTO v_order_customer_id
    FROM public.buyer_orders
    WHERE id = p_order_id;

    -- Record Immutable Order Status History
    INSERT INTO public.order_status_history (
        order_id, seller_store_id, status, old_status, notes, created_by, actor_user_id, actor_role
    ) VALUES (
        p_order_id, v_store_id, p_new_status, v_old_status, p_notes, v_seller_user_id, v_seller_user_id, public.get_current_user_role()
    );

    -- Record Tracking Event
    INSERT INTO public.order_tracking_events (
        order_id, seller_store_id, event_type, description, location
    ) VALUES (
        p_order_id, v_store_id, p_new_status,
        'Store Fulfillment ' || p_new_status || COALESCE(' via ' || p_courier_name || ' (Tracking #: ' || p_tracking_number || ')', ''),
        'Seller Warehouse'
    );

    -- Derive Parent buyer_orders.status Dynamically across all Store Fulfillments
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE fulfillment_status = 'Delivered'),
        COUNT(*) FILTER (WHERE fulfillment_status = 'Shipped')
    INTO v_total_fulfillments, v_delivered_count, v_shipped_count
    FROM public.store_fulfillments
    WHERE order_id = p_order_id
      AND fulfillment_status <> 'Cancelled';

    IF v_total_fulfillments > 0 AND v_delivered_count = v_total_fulfillments THEN
        v_derived_parent_status := 'Delivered';
    ELSIF v_shipped_count > 0 THEN
        v_derived_parent_status := 'Shipped';
    ELSE
        v_derived_parent_status := 'Processing';
    END IF;

    UPDATE public.buyer_orders
    SET status = v_derived_parent_status, updated_at = NOW()
    WHERE id = p_order_id;

    -- Send Server Notification to Buyer
    PERFORM public.internal_create_notification(
        v_order_customer_id,
        'ORDER_STATUS_UPDATE',
        'Order Update: ' || p_new_status,
        'Your items for order ' || p_order_id || ' are now ' || p_new_status || '.',
        'ORDER',
        p_order_id,
        'NOTIF-ORD-' || p_order_id || '-' || v_store_id::text || '-' || p_new_status
    );

    v_result := jsonb_build_object(
        'success', TRUE,
        'order_id', p_order_id,
        'store_id', v_store_id,
        'store_fulfillment_status', p_new_status,
        'parent_order_status', v_derived_parent_status
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.seller_update_fulfillment_status(TEXT, TEXT, UUID, TEXT, TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 13. SERVER-AUTHORITATIVE RPC: ORDER CANCELLATION (IDEMPOTENT & STOCK RESTORATIVE)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cancel_order(
    p_order_id TEXT,
    p_seller_store_id UUID DEFAULT NULL,
    p_reason TEXT DEFAULT 'Cancelled by user'
)
RETURNS JSONB AS $$
DECLARE
    v_actor_id UUID;
    v_actor_role public.app_role;
    v_customer_user_id UUID;
    v_order_status TEXT;
    v_payment_status TEXT;
    v_item RECORD;
    v_ful RECORD;
    v_canceled_any BOOLEAN := FALSE;
    v_result JSONB;
BEGIN
    v_actor_id := auth.uid();
    IF v_actor_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    v_actor_role := public.get_current_user_role();

    SELECT customer_user_id, status, payment_status
    INTO v_customer_user_id, v_order_status, v_payment_status
    FROM public.buyer_orders
    WHERE id = p_order_id FOR UPDATE;

    IF v_order_status IS NULL THEN
        RAISE EXCEPTION 'Order % does not exist.', p_order_id;
    END IF;

    IF v_order_status = 'Cancelled' THEN
        RETURN jsonb_build_object('success', TRUE, 'already_cancelled', TRUE, 'order_id', p_order_id);
    END IF;

    -- Buyer Cancellation Rules: Can cancel whole order only if pre-fulfillment (Pending / Processing)
    IF v_actor_role = 'buyer' THEN
        IF v_customer_user_id <> v_actor_id THEN
            RAISE EXCEPTION 'Access denied: You do not own order %.', p_order_id;
        END IF;

        IF v_order_status IN ('Shipped', 'Delivered') THEN
            RAISE EXCEPTION 'Cannot cancel order %: Order is already %.', p_order_id, v_order_status;
        END IF;
    END IF;

    -- Seller Cancellation Rules: Can cancel only own store fulfillment
    IF v_actor_role = 'seller' AND p_seller_store_id IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM public.seller_stores WHERE id = p_seller_store_id AND owner_id = v_actor_id) THEN
            RAISE EXCEPTION 'Access denied: You do not own store %.', p_seller_store_id;
        END IF;
    END IF;

    -- Cancel Store Fulfillments and Restore Stock for Affected Items
    FOR v_ful IN SELECT id, seller_store_id, fulfillment_status FROM public.store_fulfillments
                 WHERE order_id = p_order_id
                   AND (p_seller_store_id IS NULL OR seller_store_id = p_seller_store_id)
                   AND fulfillment_status <> 'Cancelled'
    LOOP
        IF v_ful.fulfillment_status IN ('Shipped', 'Delivered') AND v_actor_role <> 'super_admin' THEN
            RAISE EXCEPTION 'Cannot cancel store fulfillment %: Already %.', v_ful.id, v_ful.fulfillment_status;
        END IF;

        UPDATE public.store_fulfillments
        SET fulfillment_status = 'Cancelled', updated_at = NOW()
        WHERE id = v_ful.id;

        -- Restore Inventory for Order Items belonging to canceled store fulfillment
        FOR v_item IN SELECT oi.product_id, oi.variant_id, oi.quantity
                      FROM public.order_items oi
                      WHERE oi.order_id = p_order_id
                        AND oi.seller_store_id = v_ful.seller_store_id
        LOOP
            IF v_item.variant_id IS NOT NULL THEN
                UPDATE public.product_variants
                SET stock_quantity = stock_quantity + v_item.quantity, updated_at = NOW()
                WHERE id = v_item.variant_id;
            ELSE
                UPDATE public.products
                SET stock_quantity = stock_quantity + v_item.quantity, updated_at = NOW()
                WHERE id = v_item.product_id;
            END IF;
        END LOOP;

        v_canceled_any := TRUE;
    END LOOP;

    -- If all active fulfillments are now cancelled, mark parent order Cancelled and update payment
    IF NOT EXISTS (SELECT 1 FROM public.store_fulfillments WHERE order_id = p_order_id AND fulfillment_status <> 'Cancelled') THEN
        UPDATE public.buyer_orders
        SET status = 'Cancelled', updated_at = NOW()
        WHERE id = p_order_id;

        UPDATE public.payments
        SET status = 'Cancelled', updated_at = NOW()
        WHERE order_id = p_order_id AND status = 'Pending';
    END IF;

    -- Record Status History
    INSERT INTO public.order_status_history (
        order_id, seller_store_id, status, old_status, notes, created_by, actor_user_id, actor_role
    ) VALUES (
        p_order_id, p_seller_store_id, 'Cancelled', v_order_status, p_reason, v_actor_id, v_actor_id, v_actor_role
    );

    -- Notify Customer
    PERFORM public.internal_create_notification(
        v_customer_user_id,
        'ORDER_CANCELLED',
        'Order Cancelled',
        'Order ' || p_order_id || ' has been cancelled (' || p_reason || ').',
        'ORDER',
        p_order_id,
        'NOTIF-CANCEL-' || p_order_id || '-' || COALESCE(p_seller_store_id::text, 'ALL')
    );

    v_result := jsonb_build_object('success', TRUE, 'already_cancelled', FALSE, 'order_id', p_order_id);
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.cancel_order(TEXT, UUID, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 14. SERVER-AUTHORITATIVE RPC: SUBMIT RETURN REQUEST
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_return_request(
    p_order_id TEXT,
    p_order_item_id UUID,
    p_quantity INT,
    p_reason TEXT,
    p_description TEXT DEFAULT NULL,
    p_evidence_paths TEXT[] DEFAULT '{}'::TEXT[]
)
RETURNS JSONB AS $$
DECLARE
    v_buyer_user_id UUID;
    v_customer_user_id UUID;
    v_order_status TEXT;
    v_seller_store_id UUID;
    v_purchased_qty INT;
    v_already_returned_qty INT := 0;
    v_return_id UUID;
    v_result JSONB;
BEGIN
    v_buyer_user_id := auth.uid();
    IF v_buyer_user_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Return quantity must be greater than zero.';
    END IF;

    IF p_reason IS NULL OR trim(p_reason) = '' THEN
        RAISE EXCEPTION 'Return reason is required.';
    END IF;

    -- Fetch Order & Line Item Details
    SELECT bo.customer_user_id, bo.status, oi.seller_store_id, oi.quantity
    INTO v_customer_user_id, v_order_status, v_seller_store_id, v_purchased_qty
    FROM public.order_items oi
    JOIN public.buyer_orders bo ON bo.id = oi.order_id
    WHERE oi.id = p_order_item_id
      AND oi.order_id = p_order_id;

    IF v_seller_store_id IS NULL THEN
        RAISE EXCEPTION 'Target order line item % not found for order %.', p_order_item_id, p_order_id;
    END IF;

    IF v_customer_user_id <> v_buyer_user_id THEN
        RAISE EXCEPTION 'Access denied: You do not own order %.', p_order_id;
    END IF;

    IF v_order_status <> 'Delivered' THEN
        RAISE EXCEPTION 'Return requests can only be submitted for Delivered orders (Current status: %).', v_order_status;
    END IF;

    -- Cumulative Return Quantity Accounting
    SELECT COALESCE(SUM(quantity), 0) INTO v_already_returned_qty
    FROM public.return_requests
    WHERE order_item_id = p_order_item_id
      AND status IN ('Requested', 'Approved', 'Completed');

    IF (v_already_returned_qty + p_quantity) > v_purchased_qty THEN
        RAISE EXCEPTION 'Return quantity exceeds eligible purchased quantity. Eligible: %, Requested: %', (v_purchased_qty - v_already_returned_qty), p_quantity;
    END IF;

    -- Insert Return Request Row
    INSERT INTO public.return_requests (
        order_id, order_item_id, seller_store_id, customer_user_id, quantity, reason, description, evidence_paths, status
    ) VALUES (
        p_order_id, p_order_item_id, v_seller_store_id, v_buyer_user_id, p_quantity, p_reason, p_description, p_evidence_paths, 'Requested'
    ) RETURNING id INTO v_return_id;

    -- Notify Seller Store Owner
    PERFORM public.internal_create_notification(
        (SELECT owner_id FROM public.seller_stores WHERE id = v_seller_store_id),
        'RETURN_REQUESTED',
        'New Return Request',
        'A return request for item in order ' || p_order_id || ' has been submitted.',
        'RETURN',
        v_return_id::text,
        'NOTIF-RET-' || v_return_id::text
    );

    v_result := jsonb_build_object(
        'success', TRUE,
        'return_id', v_return_id,
        'order_id', p_order_id,
        'status', 'Requested'
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.submit_return_request(TEXT, UUID, INT, TEXT, TEXT, TEXT[]) TO authenticated;

-- ----------------------------------------------------------------------------
-- 15. SERVER-AUTHORITATIVE RPC: REVIEW RETURN REQUEST & PHASE 10 REFUND INTEGRATION
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.review_return_request(
    p_return_id UUID,
    p_decision TEXT, -- 'Approved' or 'Rejected'
    p_admin_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_reviewer_id UUID;
    v_return RECORD;
    v_refund_amount NUMERIC(12,2);
    v_idempotency_key TEXT;
    v_refund_res JSONB;
    v_refund_id UUID;
    v_result JSONB;
BEGIN
    v_reviewer_id := auth.uid();
    IF v_reviewer_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF p_decision NOT IN ('Approved', 'Rejected') THEN
        RAISE EXCEPTION 'Invalid return review decision: %', p_decision;
    END IF;

    -- Lock & Fetch Return Request Row
    SELECT id, order_id, order_item_id, seller_store_id, customer_user_id, quantity, status
    INTO v_return
    FROM public.return_requests
    WHERE id = p_return_id FOR UPDATE;

    IF v_return.id IS NULL THEN
        RAISE EXCEPTION 'Return request % not found.', p_return_id;
    END IF;

    -- Authorization: Seller store owner or Admin with returns:review permission
    IF NOT (
        EXISTS (SELECT 1 FROM public.seller_stores WHERE id = v_return.seller_store_id AND owner_id = v_reviewer_id)
        OR public.has_permission('returns', 'review')
    ) THEN
        RAISE EXCEPTION 'Access denied: Insufficient privileges to review return request.';
    END IF;

    IF v_return.status <> 'Requested' THEN
        RAISE EXCEPTION 'Return request % is already in % status.', p_return_id, v_return.status;
    END IF;

    IF p_decision = 'Rejected' THEN
        UPDATE public.return_requests
        SET status = 'Rejected', admin_notes = p_admin_notes, processed_by = v_reviewer_id, updated_at = NOW()
        WHERE id = p_return_id;

        PERFORM public.internal_create_notification(
            v_return.customer_user_id,
            'RETURN_REJECTED',
            'Return Request Rejected',
            'Your return request for order ' || v_return.order_id || ' was rejected.',
            'RETURN',
            p_return_id::text,
            'NOTIF-RET-DEC-' || p_return_id::text || '-REJ'
        );

        v_result := jsonb_build_object('success', TRUE, 'status', 'Rejected', 'return_id', p_return_id);
        RETURN v_result;

    ELSIF p_decision = 'Approved' THEN
        -- Calculate Refund Amount based on Line Item Unit Price * Returned Quantity
        SELECT (unit_price * v_return.quantity) INTO v_refund_amount
        FROM public.order_items
        WHERE id = v_return.order_item_id;

        v_idempotency_key := 'REF-RET-' || p_return_id::text;

        -- Invoke Phase 10 Authoritative Refund Function
        v_refund_res := public.admin_process_refund(
            v_return.order_id,
            v_return.order_item_id,
            v_refund_amount,
            'Approved Return Request ' || p_return_id::text,
            v_idempotency_key
        );

        v_refund_id := (v_refund_res->>'refund_id')::uuid;

        UPDATE public.return_requests
        SET status = 'Completed', refund_id = v_refund_id, admin_notes = p_admin_notes, processed_by = v_reviewer_id, updated_at = NOW()
        WHERE id = p_return_id;

        PERFORM public.internal_create_notification(
            v_return.customer_user_id,
            'RETURN_APPROVED',
            'Return Request Approved',
            'Your return request for order ' || v_return.order_id || ' was approved and refund processed.',
            'RETURN',
            p_return_id::text,
            'NOTIF-RET-DEC-' || p_return_id::text || '-APP'
        );

        v_result := jsonb_build_object(
            'success', TRUE,
            'status', 'Completed',
            'return_id', p_return_id,
            'refund_id', v_refund_id,
            'refund_amount', v_refund_amount
        );

        RETURN v_result;
    END IF;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.review_return_request(UUID, TEXT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 16. SERVER-AUTHORITATIVE RPC: SUBMIT PRODUCT REVIEW
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_product_review(
    p_product_id UUID,
    p_order_item_id UUID,
    p_rating INT,
    p_comment TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_buyer_id UUID;
    v_customer_user_id UUID;
    v_order_status TEXT;
    v_item_product_id UUID;
    v_review_id UUID;
    v_result JSONB;
BEGIN
    v_buyer_id := auth.uid();
    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'Rating must be an integer between 1 and 5.';
    END IF;

    IF p_comment IS NULL OR trim(p_comment) = '' THEN
        RAISE EXCEPTION 'Review comment cannot be empty.';
    END IF;

    -- Verify Line Item & Order Ownership
    SELECT bo.customer_user_id, bo.status, oi.product_id
    INTO v_customer_user_id, v_order_status, v_item_product_id
    FROM public.order_items oi
    JOIN public.buyer_orders bo ON bo.id = oi.order_id
    WHERE oi.id = p_order_item_id;

    IF v_item_product_id IS NULL THEN
        RAISE EXCEPTION 'Order line item % not found.', p_order_item_id;
    END IF;

    IF v_item_product_id <> p_product_id THEN
        RAISE EXCEPTION 'Line item % does not match product %.', p_order_item_id, p_product_id;
    END IF;

    IF v_customer_user_id <> v_buyer_id THEN
        RAISE EXCEPTION 'Access denied: You do not own the order associated with line item %.', p_order_item_id;
    END IF;

    IF v_order_status <> 'Delivered' THEN
        RAISE EXCEPTION 'Product reviews are only permitted for Delivered orders (Current status: %).', v_order_status;
    END IF;

    -- Duplicate Check via UNIQUE constraint
    BEGIN
        INSERT INTO public.product_reviews (
            product_id, order_item_id, buyer_user_id, rating, comment, is_verified_purchase
        ) VALUES (
            p_product_id, p_order_item_id, v_buyer_id, p_rating, p_comment, TRUE
        ) RETURNING id INTO v_review_id;
    EXCEPTION WHEN unique_violation THEN
        RAISE EXCEPTION 'You have already submitted a review for this purchased line item.';
    END;

    v_result := jsonb_build_object(
        'success', TRUE,
        'review_id', v_review_id,
        'product_id', p_product_id,
        'rating', p_rating
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.submit_product_review(UUID, UUID, INT, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 17. SERVER-AUTHORITATIVE RPC: SEND CHAT MESSAGE
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.send_chat_message(
    p_room_id UUID,
    p_message_text TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_sender_id UUID;
    v_room RECORD;
    v_recipient_id UUID;
    v_msg_id UUID;
    v_result JSONB;
BEGIN
    v_sender_id := auth.uid();
    IF v_sender_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF p_message_text IS NULL OR trim(p_message_text) = '' THEN
        RAISE EXCEPTION 'Message text cannot be empty.';
    END IF;

    -- Fetch Chat Room Details
    SELECT cr.id, cr.buyer_user_id, ss.owner_id AS seller_owner_id
    INTO v_room
    FROM public.chat_rooms cr
    JOIN public.seller_stores ss ON ss.id = cr.seller_store_id
    WHERE cr.id = p_room_id;

    IF v_room.id IS NULL THEN
        RAISE EXCEPTION 'Chat room % not found.', p_room_id;
    END IF;

    -- Room Membership Check
    IF v_sender_id <> v_room.buyer_user_id AND v_sender_id <> v_room.seller_owner_id AND NOT public.has_permission('chat', 'monitor') THEN
        RAISE EXCEPTION 'Access denied: You are not a participant in chat room %.', p_room_id;
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

    -- Create Notification for Recipient
    PERFORM public.internal_create_notification(
        v_recipient_id,
        'NEW_CHAT_MESSAGE',
        'New Chat Message',
        'You have a new message: ' || substring(p_message_text from 1 for 50),
        'CHAT',
        p_room_id::text,
        'NOTIF-MSG-' || v_msg_id::text
    );

    v_result := jsonb_build_object(
        'success', TRUE,
        'message_id', v_msg_id,
        'room_id', p_room_id,
        'sender_id', v_sender_id
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.send_chat_message(UUID, TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- 18. SERVER-AUTHORITATIVE RPC: CREATE CHAT ROOM (SAFE & AUTH-DERIVED)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_chat_room(
    p_seller_store_id UUID,
    p_product_id UUID DEFAULT NULL,
    p_order_id TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_buyer_id UUID;
    v_room_id UUID;
    v_result JSONB;
BEGIN
    v_buyer_id := auth.uid();
    IF v_buyer_id IS NULL THEN
        RAISE EXCEPTION 'Access denied: Unauthenticated request.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.seller_stores WHERE id = p_seller_store_id) THEN
        RAISE EXCEPTION 'Seller store % not found.', p_seller_store_id;
    END IF;

    INSERT INTO public.chat_rooms (
        buyer_user_id, seller_store_id, product_id, order_id
    ) VALUES (
        v_buyer_id, p_seller_store_id, p_product_id, p_order_id
    ) ON CONFLICT (buyer_user_id, seller_store_id, product_id)
    DO UPDATE SET created_at = chat_rooms.created_at
    RETURNING id INTO v_room_id;

    v_result := jsonb_build_object(
        'success', TRUE,
        'room_id', v_room_id,
        'buyer_user_id', v_buyer_id,
        'seller_store_id', p_seller_store_id
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

GRANT EXECUTE ON FUNCTION public.create_chat_room(UUID, UUID, TEXT) TO authenticated;
