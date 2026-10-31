-- ============================================================================
-- PGTAP TEST SUITE: PHASE 8 CATALOG, VARIANTS, INVENTORY & MODERATION TESTS
-- File: supabase/tests/phase_8_catalog_inventory_test.sql
-- ============================================================================

BEGIN;

SELECT plan(22);

-- ----------------------------------------------------------------------------
-- SETUP: Seed Test Users, Stores, Categories, Products & Variants
-- ----------------------------------------------------------------------------

-- Seed auth users
INSERT INTO auth.users (id, email) VALUES
    ('88888888-8888-8888-8888-888888880001', 'buyer_p8@example.com'),
    ('88888888-8888-8888-8888-888888880002', 'approved_seller_p8@example.com'),
    ('88888888-8888-8888-8888-888888880003', 'unapproved_seller_p8@example.com'),
    ('88888888-8888-8888-8888-888888880004', 'admin_p8@example.com')
ON CONFLICT (id) DO NOTHING;

-- Seed user roles
INSERT INTO public.user_roles (user_id, role, granted_at) VALUES
    ('88888888-8888-8888-8888-888888880001', 'buyer'::public.app_role, NOW()),
    ('88888888-8888-8888-8888-888888880002', 'seller'::public.app_role, NOW() + INTERVAL '1 sec'),
    ('88888888-8888-8888-8888-888888880003', 'buyer'::public.app_role, NOW() + INTERVAL '2 sec'),
    ('88888888-8888-8888-8888-888888880004', 'super_admin'::public.app_role, NOW() + INTERVAL '3 sec')
ON CONFLICT (user_id, role) DO UPDATE SET granted_at = EXCLUDED.granted_at;

-- Seed Seller Stores
INSERT INTO public.seller_stores (id, owner_id, shop_name, shop_slug, is_approved, is_suspended) VALUES
    ('aaaa1111-1111-1111-1111-111111111111', '88888888-8888-8888-8888-888888880002', 'Approved P8 Store', 'approved-p8-store', TRUE, FALSE),
    ('aaaa2222-2222-2222-2222-222222222222', '88888888-8888-8888-8888-888888880003', 'Unapproved P8 Store', 'unapproved-p8-store', FALSE, FALSE)
ON CONFLICT (id) DO NOTHING;

-- Seed Category
INSERT INTO public.categories (id, name, slug) VALUES
    ('cccc1111-1111-1111-1111-111111111111', 'Electronics P8', 'electronics-p8')
ON CONFLICT (id) DO NOTHING;

-- Seed Products
INSERT INTO public.products (id, seller_store_id, category_id, name, price, stock_quantity, approval_status, is_active) VALUES
    ('bbbb1111-1111-1111-1111-111111111111', 'aaaa1111-1111-1111-1111-111111111111', 'cccc1111-1111-1111-1111-111111111111', 'Approved Product P8', 100.00, 50, 'Approved', TRUE),
    ('bbbb2222-2222-2222-2222-222222222222', 'aaaa1111-1111-1111-1111-111111111111', 'cccc1111-1111-1111-1111-111111111111', 'Draft Product P8', 50.00, 10, 'Draft', TRUE),
    ('bbbb3333-3333-3333-3333-333333333333', 'aaaa2222-2222-2222-2222-222222222222', 'cccc1111-1111-1111-1111-111111111111', 'Unapproved Store Product', 80.00, 20, 'Approved', TRUE)
ON CONFLICT (id) DO NOTHING;

-- Seed dummy product image object
INSERT INTO storage.objects (id, bucket_id, name, owner, created_at, updated_at) VALUES
    ('88888888-8888-8888-8888-888888880099', 'product-images', '88888888-8888-8888-8888-888888880002/bbbb1111-1111-1111-1111-111111111111/img.png', '88888888-8888-8888-8888-888888880002', NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 1. TEST: Anonymous catalog view returns ONLY Approved products from Approved stores
-- ----------------------------------------------------------------------------
SET LOCAL ROLE anon;

SELECT is(
    (SELECT COUNT(*)::INT FROM public.products),
    1,
    '1. Anonymous catalog view returns ONLY approved products from active approved stores'
);

-- ----------------------------------------------------------------------------
-- 2. TEST: Authenticated buyer cannot view Draft or Unapproved store products
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880001", "role": "authenticated"}';

SELECT is(
    (SELECT COUNT(*)::INT FROM public.products),
    1,
    '2. Authenticated buyer sees only approved sellable products'
);

-- ----------------------------------------------------------------------------
-- 3. TEST: Unapproved seller cannot insert product
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880003", "role": "authenticated"}';

SELECT throws_ok(
    $$ INSERT INTO public.products (seller_store_id, name, price) VALUES ('aaaa2222-2222-2222-2222-222222222222', 'Unauthorized Product', 10.00) $$,
    '42501',
    NULL,
    '3. Unapproved seller attempt to insert product is denied by RLS'
);

-- ----------------------------------------------------------------------------
-- 4. TEST: Seller cannot create product for another seller store
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880002", "role": "authenticated"}';

SELECT throws_ok(
    $$ INSERT INTO public.products (seller_store_id, name, price) VALUES ('aaaa2222-2222-2222-2222-222222222222', 'Cross Store Product', 10.00) $$,
    '42501',
    NULL,
    '4. Seller cannot insert product into another seller store'
);

-- ----------------------------------------------------------------------------
-- 5. TEST: Approved seller CAN insert product for own approved store
-- ----------------------------------------------------------------------------
INSERT INTO public.products (seller_store_id, name, price) VALUES ('aaaa1111-1111-1111-1111-111111111111', 'Valid New Product', 25.00);

SELECT is(
    (SELECT COUNT(*)::INT FROM public.products WHERE name = 'Valid New Product'),
    1,
    '5. Approved seller can insert product for own store'
);

-- ----------------------------------------------------------------------------
-- 6. TEST: Direct stock column UPDATE is denied to authenticated sellers
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ UPDATE public.products SET stock_quantity = 999 WHERE id = 'bbbb1111-1111-1111-1111-111111111111' $$,
    '42501',
    NULL,
    '6. Direct UPDATE on stock_quantity is denied by column-level privileges'
);

-- ----------------------------------------------------------------------------
-- 7. TEST: Seller stock RPC updates stock for owned product
-- ----------------------------------------------------------------------------
SELECT ok(
    public.seller_update_product_stock('bbbb1111-1111-1111-1111-111111111111', 120),
    '7. Controlled seller_update_product_stock RPC succeeds'
);

-- ----------------------------------------------------------------------------
-- 8. TEST: Seller stock RPC rejects negative stock value
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ SELECT public.seller_update_product_stock('bbbb1111-1111-1111-1111-111111111111', -5) $$,
    'P0001',
    NULL,
    '8. seller_update_product_stock rejects negative stock'
);

-- ----------------------------------------------------------------------------
-- 9. TEST: Client role cannot execute internal_decrement_product_stock
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ SELECT public.internal_decrement_product_stock('bbbb1111-1111-1111-1111-111111111111', 5) $$,
    '42501',
    NULL,
    '9. Execution of internal_decrement_product_stock is revoked from client role'
);

-- ----------------------------------------------------------------------------
-- 10. TEST: Seller self-approval attempt on own product fails
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ SELECT public.admin_review_product('bbbb2222-2222-2222-2222-222222222222', TRUE) $$,
    'P0001',
    NULL,
    '10. Seller self-approval attempt on own product raises exception'
);

-- ----------------------------------------------------------------------------
-- 11. TEST: Admin product rejection without reason fails
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880004", "role": "authenticated"}';

SELECT throws_ok(
    $$ SELECT public.admin_review_product('bbbb2222-2222-2222-2222-222222222222', FALSE, '') $$,
    'P0001',
    NULL,
    '11. Admin product rejection without reason fails'
);

-- ----------------------------------------------------------------------------
-- 12. TEST: Admin product approval succeeds & logs audit entry
-- ----------------------------------------------------------------------------
SELECT ok(
    public.admin_review_product('bbbb2222-2222-2222-2222-222222222222', TRUE),
    '12. Admin product approval succeeds'
);

-- ----------------------------------------------------------------------------
-- 13. TEST: Product approval status updated to Approved
-- ----------------------------------------------------------------------------
SELECT is(
    (SELECT approval_status FROM public.products WHERE id = 'bbbb2222-2222-2222-2222-222222222222'),
    'Approved',
    '13. Product approval_status updated to Approved'
);

-- ----------------------------------------------------------------------------
-- 14. TEST: Seller can insert variant for own product
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880002", "role": "authenticated"}';

INSERT INTO public.product_variants (product_id, seller_store_id, sku, variant_name) VALUES ('bbbb1111-1111-1111-1111-111111111111', 'aaaa1111-1111-1111-1111-111111111111', 'SKU-RED-XL', 'Red XL');

SELECT is(
    (SELECT COUNT(*)::INT FROM public.product_variants WHERE sku = 'SKU-RED-XL'),
    1,
    '14. Seller can insert variant for own product'
);

-- ----------------------------------------------------------------------------
-- 15. TEST: Duplicate SKU in same store fails
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ INSERT INTO public.product_variants (product_id, seller_store_id, sku, variant_name) VALUES ('bbbb1111-1111-1111-1111-111111111111', 'aaaa1111-1111-1111-1111-111111111111', 'SKU-RED-XL', 'Duplicate SKU') $$,
    '23505',
    NULL,
    '15. Duplicate SKU within same seller store fails constraint'
);

-- ----------------------------------------------------------------------------
-- 16. TEST: Variant attached to another seller product fails
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ INSERT INTO public.product_variants (product_id, seller_store_id, sku, variant_name) VALUES ('bbbb3333-3333-3333-3333-333333333333', 'aaaa1111-1111-1111-1111-111111111111', 'SKU-MALICIOUS', 'Malicious Variant') $$,
    '42501',
    NULL,
    '16. Attaching variant to another seller product fails RLS'
);

-- ----------------------------------------------------------------------------
-- 17. TEST: Invalid sale price (> regular price) fails constraint
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ INSERT INTO public.products (seller_store_id, name, price, sale_price) VALUES ('aaaa1111-1111-1111-1111-111111111111', 'Invalid Sale Price', 50.00, 100.00) $$,
    '23514',
    NULL,
    '17. Sale price greater than regular price fails check constraint'
);

-- ----------------------------------------------------------------------------
-- 18. TEST: Direct client update on approval_status is denied by column privileges
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ UPDATE public.products SET approval_status = 'Approved' WHERE id = 'bbbb1111-1111-1111-1111-111111111111' $$,
    '42501',
    NULL,
    '18. Direct client UPDATE on approval_status is denied by column privileges'
);

-- ----------------------------------------------------------------------------
-- 19. TEST: Category mutation by non-admin seller fails RLS
-- ----------------------------------------------------------------------------
SELECT throws_ok(
    $$ INSERT INTO public.categories (name, slug) VALUES ('Unauthorized Cat', 'unauthorized-cat') $$,
    '42501',
    NULL,
    '19. Category creation attempt by non-admin seller is denied by RLS'
);

-- ----------------------------------------------------------------------------
-- 20. TEST: Admin category creation succeeds
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880004", "role": "authenticated"}';

INSERT INTO public.categories (name, slug) VALUES ('Admin Category', 'admin-category');

SELECT is(
    (SELECT COUNT(*)::INT FROM public.categories WHERE slug = 'admin-category'),
    1,
    '20. Admin category creation succeeds'
);

-- ----------------------------------------------------------------------------
-- 21. TEST: Anyone can view product images bucket object
-- ----------------------------------------------------------------------------
SET LOCAL ROLE anon;

SELECT is(
    (SELECT COUNT(*)::INT FROM storage.objects WHERE bucket_id = 'product-images' AND id = '88888888-8888-8888-8888-888888880099'),
    1,
    '21. Public/Anonymous read on product-images bucket is allowed'
);

-- ----------------------------------------------------------------------------
-- 22. TEST: Seller cannot upload product image into another seller folder
-- ----------------------------------------------------------------------------
SET LOCAL ROLE authenticated;
SET LOCAL "request.jwt.claims" = '{"sub": "88888888-8888-8888-8888-888888880003", "role": "authenticated"}';

SELECT throws_ok(
    $$ INSERT INTO storage.objects (id, bucket_id, name, owner) VALUES ('88888888-8888-8888-8888-888888880098', 'product-images', '88888888-8888-8888-8888-888888880002/bbbb1111-1111-1111-1111-111111111111/malicious.png', '88888888-8888-8888-8888-888888880003') $$,
    '42501',
    NULL,
    '22. Cross-folder product image upload attempt is denied by RLS'
);

SELECT * FROM finish();
ROLLBACK;
