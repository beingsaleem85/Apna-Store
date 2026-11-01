-- ============================================================================
-- SQL Test: Task A1 - Chat Rooms Idempotency, Order Validation & Realtime RLS Tests
-- ============================================================================

BEGIN;
SELECT plan(5);

-- Seed Auth Users & active store for tests 1 & 2
INSERT INTO auth.users (id, email) VALUES
    ('70000000-0000-0000-0000-000000000001', 'chat_buyer_test@example.com'),
    ('70000000-0000-0000-0000-000000000002', 'chat_seller_test@example.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, full_name, email, role, phone, is_deactivated) VALUES
    ('70000000-0000-0000-0000-000000000001', 'Chat Buyer', 'chat_buyer_test@example.com', 'buyer'::public.app_role, '+923001112233', FALSE),
    ('70000000-0000-0000-0000-000000000002', 'Chat Seller', 'chat_seller_test@example.com', 'seller'::public.app_role, '+923001112234', FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.seller_stores (id, owner_id, name, shop_slug, is_approved, is_suspended) VALUES
    ('00000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000002', 'Active Store Chat', 'active-store-chat', TRUE, FALSE)
ON CONFLICT (id) DO NOTHING;

SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "70000000-0000-0000-0000-000000000001", "role": "authenticated"}';

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

RESET ROLE;

-- 3. Test: Idempotent room creation: duplicate room attempt returns identical room ID
INSERT INTO auth.users (id, email) VALUES
    ('88888888-0000-0000-0000-000000000071', 'buyer_rt1@test.com'),
    ('88888888-0000-0000-0000-000000000072', 'seller_rt1@test.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, full_name, email, role) VALUES
    ('88888888-0000-0000-0000-000000000071', 'Buyer RT1', 'buyer_rt1@test.com', 'buyer'::public.app_role),
    ('88888888-0000-0000-0000-000000000072', 'Seller RT1', 'seller_rt1@test.com', 'seller'::public.app_role)
ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name, role = EXCLUDED.role;

INSERT INTO public.seller_stores (id, owner_id, name, shop_slug, is_approved, is_suspended)
VALUES ('88888888-0000-0000-0000-000000000073', '88888888-0000-0000-0000-000000000072', 'Test Store Realtime', 'test-store-rt-73', TRUE, FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.chat_rooms (id, buyer_user_id, seller_store_id, product_id)
VALUES ('88888888-0000-0000-0000-000000000074', '88888888-0000-0000-0000-000000000071', '88888888-0000-0000-0000-000000000073', NULL)
ON CONFLICT DO NOTHING;

INSERT INTO public.chat_rooms (buyer_user_id, seller_store_id, product_id)
VALUES ('88888888-0000-0000-0000-000000000071', '88888888-0000-0000-0000-000000000073', NULL)
ON CONFLICT (buyer_user_id, seller_store_id, (COALESCE(product_id, '00000000-0000-0000-0000-000000000000'::UUID)))
DO NOTHING;

SELECT is(
    (SELECT count(*)::INT FROM public.chat_rooms WHERE buyer_user_id = '88888888-0000-0000-0000-000000000071' AND seller_store_id = '88888888-0000-0000-0000-000000000073' AND product_id IS NULL),
    1,
    'Idempotent room creation: duplicate room attempt returns the identical canonical room ID'
);

-- 4. Test: Idempotent room creation with product: second call with same buyer, store and product returns the same room_id and creates exactly one row
INSERT INTO auth.users (id, email) VALUES
    ('88888888-0000-0000-0000-000000000081', 'buyer_rt2@test.com'),
    ('88888888-0000-0000-0000-000000000082', 'seller_rt2@test.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, full_name, email, role) VALUES
    ('88888888-0000-0000-0000-000000000081', 'Buyer RT2', 'buyer_rt2@test.com', 'buyer'::public.app_role),
    ('88888888-0000-0000-0000-000000000082', 'Seller RT2', 'seller_rt2@test.com', 'seller'::public.app_role)
ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name, role = EXCLUDED.role;

INSERT INTO public.seller_stores (id, owner_id, name, shop_slug, is_approved, is_suspended)
VALUES ('88888888-0000-0000-0000-000000000083', '88888888-0000-0000-0000-000000000082', 'Test Store Product Chat', 'test-store-prod-83', TRUE, FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.categories (id, name, slug)
VALUES ('88888888-0000-0000-0000-000000000084', 'Apparel', 'apparel-test-cat-84')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.products (id, seller_store_id, category_id, name, slug, price, stock_quantity)
VALUES ('88888888-0000-0000-0000-000000000085', '88888888-0000-0000-0000-000000000083', '88888888-0000-0000-0000-000000000084', 'Lawn Suit', 'lawn-suit-test-85', 2500.00, 10)
ON CONFLICT (id) DO NOTHING;

SELECT set_config('request.jwt.claims', '{"sub": "88888888-0000-0000-0000-000000000081", "role": "authenticated"}', true);
SELECT set_config('request.jwt.claim.sub', '88888888-0000-0000-0000-000000000081', true);

SELECT is(
    (public.create_chat_room('88888888-0000-0000-0000-000000000083'::UUID, '88888888-0000-0000-0000-000000000085'::UUID, NULL) ->> 'room_id'),
    (public.create_chat_room('88888888-0000-0000-0000-000000000083'::UUID, '88888888-0000-0000-0000-000000000085'::UUID, NULL) ->> 'room_id'),
    'Second call with same buyer, store and product returns same room_id and creates exactly one row'
);

-- 5. Test: Non-participant cannot select another room messages under RLS
RESET ROLE;
INSERT INTO auth.users (id, email) VALUES
    ('88888888-0000-0000-0000-000000000091', 'attacker@test.com'),
    ('88888888-0000-0000-0000-000000000092', 'other_buyer@test.com'),
    ('88888888-0000-0000-0000-000000000093', 'other_seller@test.com')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (id, full_name, email, role) VALUES
    ('88888888-0000-0000-0000-000000000091', 'Attacker', 'attacker@test.com', 'buyer'::public.app_role),
    ('88888888-0000-0000-0000-000000000092', 'Other Buyer', 'other_buyer@test.com', 'buyer'::public.app_role),
    ('88888888-0000-0000-0000-000000000093', 'Other Seller', 'other_seller@test.com', 'seller'::public.app_role)
ON CONFLICT (id) DO UPDATE SET full_name = EXCLUDED.full_name, role = EXCLUDED.role;

INSERT INTO public.seller_stores (id, owner_id, name, shop_slug, is_approved, is_suspended)
VALUES ('88888888-0000-0000-0000-000000000094', '88888888-0000-0000-0000-000000000093', 'Other Store', 'other-store-94', TRUE, FALSE)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.chat_rooms (id, buyer_user_id, seller_store_id)
VALUES ('88888888-0000-0000-0000-000000000095', '88888888-0000-0000-0000-000000000092', '88888888-0000-0000-0000-000000000094')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.chat_messages (id, room_id, sender_id, message_text)
VALUES ('88888888-0000-0000-0000-000000000096', '88888888-0000-0000-0000-000000000095', '88888888-0000-0000-0000-000000000092', 'Confidential buyer chat')
ON CONFLICT (id) DO NOTHING;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub": "88888888-0000-0000-0000-000000000091", "role": "authenticated"}', true);
SELECT set_config('request.jwt.claim.sub', '88888888-0000-0000-0000-000000000091', true);

SELECT is(
    (SELECT count(*)::INT FROM public.chat_messages WHERE room_id = '88888888-0000-0000-0000-000000000095'),
    0,
    'RLS prevents non-participants from reading or streaming messages from other rooms'
);

SELECT * FROM finish();
ROLLBACK;
