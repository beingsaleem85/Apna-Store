-- Migration: 20260822000000_chat_hardening_and_realtime.sql
-- Description: Rate-limiting and duplicate prevention on create_chat_room, plus Realtime publication setup

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

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

    -- Anti-abuse rate limit (10 room creation attempts per minute per buyer)
    PERFORM public.enforce_rate_limit('create_chat_room', 10, 60);

    -- Validate store exists and is valid
    IF NOT EXISTS (SELECT 1 FROM public.seller_stores WHERE id = p_seller_store_id) THEN
        RAISE EXCEPTION 'Seller store % not found.', p_seller_store_id;
    END IF;

    -- Prevent duplicate rooms for the same buyer + seller store (+ product if specified)
    SELECT id INTO v_room_id
    FROM public.chat_rooms
    WHERE buyer_user_id = v_buyer_id
      AND seller_store_id = p_seller_store_id
      AND (
          (p_product_id IS NULL AND product_id IS NULL)
          OR product_id = p_product_id
      )
    LIMIT 1;

    -- If no room exists yet, insert a new canonical room
    IF v_room_id IS NULL THEN
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
        RETURNING id INTO v_room_id;
    END IF;

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
