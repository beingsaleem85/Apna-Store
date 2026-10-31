-- Migration: 20260823000000_chat_rooms_concurrency_and_order_validation.sql
-- Description: Concurrency unique index on chat_rooms, store status and order ownership validation in create_chat_room, Realtime RLS replica identity

-- 1. Ensure chat_messages has full replica identity and is registered for Realtime
ALTER TABLE public.chat_messages REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables 
            WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'chat_messages'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
        END IF;
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- 2. Unique index on chat_rooms for concurrency duplicate prevention
CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_rooms_unique_buyer_seller_product
ON public.chat_rooms (
    buyer_user_id,
    seller_store_id,
    (COALESCE(product_id, '00000000-0000-0000-0000-000000000000'::UUID))
);

-- 3. Hardened create_chat_room function
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
        RAISE EXCEPTION 'Access denied: Unauthenticated request.' USING ERRCODE = '42501';
    END IF;

    -- Anti-abuse rate limit (10 room creations per minute per user)
    PERFORM public.enforce_rate_limit('create_chat_room', 10, 60);

    -- Validate store exists, is approved, and is NOT suspended
    IF NOT public.is_approved_active_seller_store(p_seller_store_id) THEN
        RAISE EXCEPTION 'Seller store % is unapproved, suspended, or does not exist.', p_seller_store_id USING ERRCODE = 'P0001';
    END IF;

    -- If order_id is provided, verify order belongs to auth.uid() and has items from this seller store
    IF p_order_id IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.buyer_orders
            WHERE id = p_order_id AND customer_user_id = v_buyer_id
        ) THEN
            RAISE EXCEPTION 'Access denied: Order % does not belong to user %.', p_order_id, v_buyer_id USING ERRCODE = '42501';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM public.order_items
            WHERE order_id = p_order_id AND seller_store_id = p_seller_store_id
        ) THEN
            RAISE EXCEPTION 'Order % does not contain items from seller store %.', p_order_id, p_seller_store_id USING ERRCODE = 'P0001';
        END IF;
    END IF;

    -- Concurrency-safe insert: if room already exists, do nothing on conflict
    INSERT INTO public.chat_rooms (
        buyer_user_id,
        seller_store_id,
        product_id,
        order_id
    ) VALUES (
        v_buyer_id,
        p_seller_store_id,
        p_product_id,
        p_order_id
    )
    ON CONFLICT (buyer_user_id, seller_store_id, (COALESCE(product_id, '00000000-0000-0000-0000-000000000000'::UUID)))
    DO NOTHING;

    -- Re-select the room id (returns whether freshly created or existing)
    SELECT id INTO v_room_id
    FROM public.chat_rooms
    WHERE buyer_user_id = v_buyer_id
      AND seller_store_id = p_seller_store_id
      AND COALESCE(product_id, '00000000-0000-0000-0000-000000000000'::UUID) = COALESCE(p_product_id, '00000000-0000-0000-0000-000000000000'::UUID)
    LIMIT 1;

    v_result := jsonb_build_object(
        'success', TRUE,
        'room_id', v_room_id,
        'buyer_user_id', v_buyer_id,
        'seller_store_id', p_seller_store_id
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

REVOKE ALL ON FUNCTION public.create_chat_room(UUID, UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.create_chat_room(UUID, UUID, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.create_chat_room(UUID, UUID, TEXT) TO authenticated;
