BEGIN;
SELECT plan(6);

-- 1. Table assertions
SELECT has_table('public', 'order_tracking_events', 'order_tracking_events table exists');
SELECT has_table('public', 'user_wishlists', 'user_wishlists table exists');
SELECT has_table('public', 'product_reviews', 'product_reviews table exists');

-- 2. Function assertions
SELECT has_function('public', 'get_order_tracking_events', ARRAY['uuid'], 'get_order_tracking_events RPC exists');
SELECT has_function('public', 'get_flash_sale_products', ARRAY['integer'], 'get_flash_sale_products RPC exists');

-- 3. Wishlist RLS & unique constraint check
SELECT col_is_pk('public', 'user_wishlists', 'id', 'user_wishlists has UUID primary key');

SELECT * FROM finish();
ROLLBACK;
