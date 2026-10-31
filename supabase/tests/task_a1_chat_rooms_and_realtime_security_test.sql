-- ============================================================================
-- SQL Test: Task A1 - Chat Rooms Idempotency, Order Validation & Realtime RLS Tests
-- ============================================================================

BEGIN;
SELECT plan(5);

-- 1. Test: Suspended or unapproved store is rejected by create_chat_room
SELECT throws_like(
    $$
    -- Call with non-existent or suspended store ID
    SELECT public.create_chat_room('00000000-0000-0000-0000-000000000099'::uuid, NULL, NULL);
    $$,
    '%unapproved, suspended, or does not exist%',
    'create_chat_room rejects suspended or non-existent seller store'
);

-- 2. Test: Order not owned by buyer is rejected
SELECT throws_like(
    $$
    -- Setup dummy store if needed and attempt with non-owned order
    SELECT public.create_chat_room(
        '00000000-0000-0000-0000-000000000001'::uuid,
        NULL,
        'ORD-NON-EXISTENT-OR-NOT-OWNED'
    );
    $$,
    '%Access denied%Order%does not belong to user%',
    'create_chat_room validates order belongs to calling buyer'
);

-- 3. Test: Idempotent room creation: duplicate room attempt returns identical room ID
DO $$
DECLARE
    v_buyer_id UUID := gen_random_uuid();
    v_store_id UUID := gen_random_uuid();
    v_room1_id UUID;
    v_room2_id UUID;
BEGIN
    -- Insert test store
    INSERT INTO public.seller_stores (id, owner_id, name, shop_slug, is_approved, is_suspended)
    VALUES (v_store_id, gen_random_uuid(), 'Test Store Realtime', 'test-store-rt', TRUE, FALSE);

    -- Insert initial room
    INSERT INTO public.chat_rooms (buyer_user_id, seller_store_id, product_id)
    VALUES (v_buyer_id, v_store_id, NULL)
    RETURNING id INTO v_room1_id;

    -- Concurrently attempt insert with ON CONFLICT DO NOTHING
    INSERT INTO public.chat_rooms (buyer_user_id, seller_store_id, product_id)
    VALUES (v_buyer_id, v_store_id, NULL)
    ON CONFLICT (buyer_user_id, seller_store_id, (COALESCE(product_id, '00000000-0000-0000-0000-000000000000'::UUID)))
    DO NOTHING;

    -- Re-select
    SELECT id INTO v_room2_id
    FROM public.chat_rooms
    WHERE buyer_user_id = v_buyer_id AND seller_store_id = v_store_id AND product_id IS NULL;

    IF v_room1_id = v_room2_id THEN
        PERFORM pass('Idempotent room creation: duplicate room attempt returns the identical canonical room ID');
    ELSE
        PERFORM fail('Idempotent room creation failed: created duplicate room row');
    END IF;
END $$;

-- 4. Test: Idempotent room creation with product: second call with same buyer, store and product returns the same room_id and creates exactly one row
DO $$
DECLARE
    v_buyer_id UUID := gen_random_uuid();
    v_store_id UUID := gen_random_uuid();
    v_product_id UUID := gen_random_uuid();
    v_cat_id UUID := gen_random_uuid();
    v_room1_id UUID;
    v_room2_id UUID;
    v_total_rows INT;
BEGIN
    -- Setup store & product category
    INSERT INTO public.seller_stores (id, owner_id, name, shop_slug, is_approved, is_suspended)
    VALUES (v_store_id, gen_random_uuid(), 'Test Store Product Chat', 'test-store-prod', TRUE, FALSE);

    INSERT INTO public.categories (id, name, slug)
    VALUES (v_cat_id, 'Apparel', 'apparel-test-cat');

    INSERT INTO public.products (id, seller_store_id, category_id, name, slug, price, stock_quantity)
    VALUES (v_product_id, v_store_id, v_cat_id, 'Lawn Suit', 'lawn-suit-test', 2500.00, 10);

    -- Switch auth context to buyer
    PERFORM set_config('request.jwt.claim.sub', v_buyer_id::text, true);

    -- Call 1
    SELECT (public.create_chat_room(v_store_id, v_product_id, NULL) ->> 'room_id')::UUID INTO v_room1_id;

    -- Call 2
    SELECT (public.create_chat_room(v_store_id, v_product_id, NULL) ->> 'room_id')::UUID INTO v_room2_id;

    -- Count total rows in chat_rooms for this tuple
    SELECT COUNT(*) INTO v_total_rows
    FROM public.chat_rooms
    WHERE buyer_user_id = v_buyer_id
      AND seller_store_id = v_store_id
      AND product_id = v_product_id;

    IF v_room1_id = v_room2_id AND v_total_rows = 1 THEN
        PERFORM pass('Second call with same buyer, store and product returns same room_id and creates exactly one row');
    ELSE
        PERFORM fail('Idempotent creation with product failed: room1=' || COALESCE(v_room1_id::text, 'null') || ' room2=' || COALESCE(v_room2_id::text, 'null') || ' total=' || v_total_rows);
    END IF;
END $$;

-- 5. Test: Non-participant cannot select another room messages under RLS
DO $$
DECLARE
    v_attacker_id UUID := gen_random_uuid();
    v_room_id UUID := gen_random_uuid();
    v_visible_count INT;
BEGIN
    -- Insert a room with completely different users
    INSERT INTO public.chat_rooms (id, buyer_user_id, seller_store_id)
    VALUES (v_room_id, gen_random_uuid(), gen_random_uuid());

    -- Insert message inside that room
    INSERT INTO public.chat_messages (id, room_id, sender_id, message_text)
    VALUES (gen_random_uuid(), v_room_id, gen_random_uuid(), 'Confidential buyer chat');

    -- Switch auth context to attacker
    PERFORM set_config('request.jwt.claim.sub', v_attacker_id::text, true);

    -- Query as attacker
    SELECT COUNT(*) INTO v_visible_count
    FROM public.chat_messages
    WHERE room_id = v_room_id;

    IF v_visible_count = 0 THEN
        PERFORM pass('RLS prevents non-participants from reading or streaming messages from other rooms');
    ELSE
        PERFORM fail('RLS failed: non-participant was able to read other room messages');
    END IF;
END $$;

SELECT * FROM finish();
ROLLBACK;
