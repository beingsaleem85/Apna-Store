# APNA STORE — LAUNCH FIX PROGRESS REPORT

## 0. Baseline Audit & Pre-Execution Checks

### Documentation & Schema Review Completed:
- Read `HANDOFF.md`
- Read `PROJECT_MEMORY.md`
- Read `docs/RLS_POLICY_MATRIX.md`
- Read `docs/DATABASE_SCHEMA.md`
- Read `docs/DATA_CONTRACTS.md`
- Reviewed all migrations in `supabase/migrations/`:
  - `20260715000000_init_schema.sql`
  - `20260805000000_authoritative_schema_and_rls.sql`
  - `20260806000000_phase_6_rbac_admin_audit.sql`
  - `20260807000000_phase_7_storage_and_kyc_security.sql`
  - `20260808000000_phase_8_catalog_and_inventory.sql`
  - `20260809000000_phase_9_cart_checkout_atomic_orders.sql`
  - `20260810000000_phase_10_financial_ledger_payouts_refunds.sql`
  - `20260811000000_phase_11_orders_returns_reviews_chat_notifications.sql`
  - `20260812000000_phase_b_unified_roles_and_tables.sql`
  - `20260813000000_phase_c_seller_admin_ops.sql`
  - `20260814000000_phase_e_growth_payments_variants.sql`
  - `all_migrations_combined.sql`

### Baseline Tool Execution Results:
- **`flutter pub get`:** Passed (0 errors).
- **`flutter analyze`:** Found 515 issues (0 errors, 48 warnings, 467 infos).
- **`flutter test`:** Total 302 tests run.
  - **Passed:** 291
  - **Failed:** 11 (Baseline is not clean)
  - **Failing suites breakdown:**
    1. `test/phase_12_step_d_test.dart`: 3 failures (Tests D, E, F: `Bad state: No element` in widget tester scrollable visibility)
    2. `test/phase_12_step_e2_test.dart`: 6 failures (Tests B, D, L, O, P, S: OrdersController mock state synchronization)
    3. `test/phase_12_step_e2_1_test.dart`: 2 failures (Tests C, E: OrdersController listener notifications)

---

## TASK 1 REPORT — Interim Payment Safety Guard (COD Only)

### Summary of Changes:
1. **Database Migration (`supabase/migrations/20260815000000_task1_payment_safety_guard.sql`):**
   - Replaced `create_atomic_order` with strict `SET search_path = ''`.
   - Permitted only `'Cash on Delivery'` (or `'COD'`). Any other payment method immediately raises `Online payments are not available yet. Please select Cash on Delivery.`.
   - Removed immediate `'Paid'` status assignment for online methods; `payment_status` is strictly `'Pending'`.
   - Updated initial tracking event description to clarify payment on delivery.
   - Revoked EXECUTE from PUBLIC/anon, granted only to `authenticated`.
2. **Client Feature Flag (`lib/core/config/feature_flags.dart`):**
   - Added `static const bool onlinePaymentsEnabled = false;`.
3. **Checkout UI (`lib/features/buyer/widgets/checkout/checkout_payment_selector.dart` & `buyer_checkout_screen.dart`):**
   - Wired `CheckoutPaymentSelector` to `FeatureFlags.onlinePaymentsEnabled`.
   - Online payment options (JazzCash, Easypaisa, Card) display "Coming Soon" chip and ignore taps.
   - Guarded `_handlePlaceOrder` to block non-COD orders.
4. **Checkout Service (`lib/core/services/supabase_checkout_service.dart`):**
   - Added user-friendly error mapping for online payment rejection exception.
5. **Ledger & Payout Verification:**
   - Confirmed `seller_request_payout` relies on `balance`, which is credited through `admin_process_order_settlement` only after collection. No order creation can credit seller wallet.

### Tests Added / Updated:
- `supabase/tests/task1_payment_safety_test.sql` (8 pgTAP assertions covering non-COD rejection, COD acceptance, pending status, tracking text).
- `test/task1_payment_safety_test.dart` (2 widget/unit tests covering flag defaults, UI disabling, "Coming Soon" badges).
- `test/phase_17_growth_features_test.dart` (Updated test 3 to check safety flag enforcement).
- **Test execution:** `flutter test test/task1_payment_safety_test.dart` (2/2 PASSED), `flutter test test/phase_17_growth_features_test.dart` (5/5 PASSED).

---

## TASK 2 REPORT — Remove Secrets & Fake Keys from Client

### Summary of Changes:
1. **Database Migration (`supabase/migrations/20260816000000_task2_platform_integrations_no_secrets.sql`):**
   - Created `platform_integrations` table with RLS enabled.
   - Strictly ZERO secret columns. Only non-sensitive metadata (`provider_key`, `display_name`, `category`, `is_enabled`, `status`, `last_checked_at`, `updated_by`, `updated_at`).
   - RLS policy: Only authenticated administrators can read integrations. All direct INSERT/UPDATE/DELETE revoked.
   - Security Definer RPC: `admin_set_integration_enabled(p_provider_key, p_enabled)` with `SET search_path = ''` updates `is_enabled` and logs every toggle to `admin_audit_logs`.
   - Seeded default integrations (JazzCash, Easypaisa, 1Link, Stripe, TCS, Leopard, Trax, CallCourier, SMS, S3, FBR POS).
2. **Setup Documentation (`docs/SECRETS_SETUP.md`):**
   - Created detailed guide for setting all third-party secrets via Supabase CLI (`supabase secrets set ...`).
   - Documented environment variables for JazzCash, Easypaisa, 1Link, Stripe, TCS, Leopard, Trax, SMS, S3, and FBR.
3. **Client UI Refactoring:**
   - `lib/features/super_admin/screens/settings/platform_config_screen.dart`:
     - Removed all hardcoded `apiKey`, `merchantId`, `webhookUrl` strings.
     - Replaced with clean `providerKey`, `isEnabled`, and `status`.
     - Replaced the secret key editing form with a read-only architectural security modal directing admins to Supabase Edge Function Secrets.
   - `lib/features/super_admin/screens/shipping/shipping_governance_screen.dart`:
     - Removed `apiKeyMask` and all fake live keys (`tcs_live_pk_...`, `leopard_sec_...`, `call_live_...`, `mp_live_sec_...`).
     - Replaced with configuration status and read-only security notices.
4. **Repository Audit:**
   - Scanned `lib/`, `web/`, `test/` for secret-like tokens (`pk_live`, `sk_live`, `sk_test`, `aws_s3`, `service_role`, `eyJ`). Zero leaked secrets found.
5. **Automated Verification:**
   - Created `test/task2_zero_secrets_audit_test.dart` asserting that no file under `lib/` contains secret patterns and verifying `docs/SECRETS_SETUP.md`. Both tests passed!

---


## TASK 3 REPORT — Remove Leftover Mock Data & Build Real Vouchers

### Summary of Changes:
1. **Database Migration (`supabase/migrations/20260817000000_task3_real_vouchers_and_redemptions.sql`):**
   - Created authoritative `public.vouchers` and `public.voucher_redemptions` tables with full RLS.
   - Built server RPC `validate_voucher(p_code TEXT, p_subtotal NUMERIC)` returning `{valid: bool, discount_amount: numeric, voucher_id: uuid, code: text, error: text}` with validations for start/end dates, active status, max global redemptions, max per-user redemptions, and minimum order spend.
   - Embedded transaction-safe voucher validation inside `create_atomic_order` to prevent client tampering.
   - Added `admin_create_voucher` and `admin_disable_voucher` security definer RPCs.
2. **Client Service (`lib/core/services/supabase_voucher_service.dart`):**
   - Created `SupabaseVoucherService` calling `validate_voucher` RPC with strong error handling.
3. **State & Screen Cleanup:**
   - `lib/core/services/app_state_provider.dart`: Emptied mock dictionary `_vouchers = {}`; added `validateVoucherOnline` RPC wrapper.
   - `lib/features/buyer/screens/address/buyer_address_location_screen.dart`: Removed pre-filled dummy strings ('Usman Tariq', 'EID2026', etc.) and wired `validateVoucherOnline`.
   - `lib/features/buyer/screens/cart/buyer_cart_checkout_screen.dart`: Removed static 'EID2026' text; discount rows now render dynamically.
   - `lib/features/buyer/screens/home/buyer_dynamic_home_screen.dart`: Replaced hardcoded 'EID2026' banner text with generic savings copy.
   - `lib/features/buyer/screens/all_recommended_screen.dart` and `buyer_dashboard.dart`: Replaced client-side voucher lookup with online validation.
   - Purged all occurrences of "Chulbul Store" across `dispute_arbitration_screen.dart`, `fraud_security_screen.dart`, and `admin_staff_management_screen.dart`.
4. **Automated Verification:**
   - Created `test/task3_real_vouchers_test.dart` (5 tests covering RPC responses, input rejection, empty initial state). All 5 passed!

---

## TASK 4 REPORT — Wire SQL Features in App

### Summary of Changes:
1. **Order Tracking Screen (`lib/features/buyer/screens/orders/buyer_order_tracking_screen.dart`):**
   - Wired to `order_tracking_events` table via Supabase client.
   - Displays real order ID, customer delivery address, live status badge, and actual order items/payouts.
   - Eliminated all lorem ipsum and fake 2023 dates.
   - Graceful linear fallback based on `order.orderStatus` ('Pending' -> 'Confirmed' -> 'Processing' -> 'Shipped' -> 'Delivered') when tracking events are not yet logged.
   - Implemented an empty state ("No Orders to Track") with a shopping redirection button.
2. **Flash Sales (`lib/features/buyer/screens/home/buyer_dynamic_home_screen.dart`):**
   - Wired to `get_flash_sale_products` RPC.
   - Gracefully hides the flash sale header and product grid if no active flash sale is returned from the server.
   - Eliminated the static fake countdown timer.
3. **Wishlist Database Persistence (`lib/core/controllers/cart_controller.dart`):**
   - Wired `toggleWishlist` to write through to `user_wishlists` table (upsert / delete) for authenticated users.
   - Added `syncWishlistFromSupabase(availableProducts)` to hydrate user wishlists upon login.
   - Preserves optimistic offline / guest fallback for unauthenticated users.
4. **Product Reviews Display (`lib/features/buyer/widgets/product/product_reviews_section.dart`):**
   - Wired to `SupabaseReviewsService().getProductReviews(productId)`.
   - Replaced hardcoded Tecno Spark reviews with dynamic reviews from `product_reviews` joined with profile names.
   - Computes dynamic average rating, rating bars (1-star to 5-star), and total ratings count.
   - Added clean empty state ("No customer reviews yet for this product. Be the first to review after receiving your order!") when no reviews exist.
5. **Automated Verification:**
   - Created `supabase/tests/task4_sql_features_test.sql` (6 pgTAP assertions covering tables, functions, RLS).
   - Created `test/task4_sql_features_test.dart` (3 tests covering JSON parsing, toggle persistence, and sync).
   - All tests passing.

---


## TASK 5 REPORT — Super Admin Real Screens Audit & Fix

### Complete Super Admin Screens Audit Table:

| # | Screen Name | File Path | Current Data Source | Status |
|---|---|---|---|---|
| 1 | Admin Shell | `lib/features/super_admin/screens/admin_shell.dart` | Shell Navigation & RBAC | Clean |
| 2 | Executive Dashboard | `lib/features/super_admin/screens/dashboard/executive_dashboard_screen.dart` | Supabase Orders / Stores | Clean |
| 3 | AI Copilot | `lib/features/super_admin/screens/ai/ai_copilot_screen.dart` | Admin System Stats | Clean |
| 4 | Analytics & Tax | `lib/features/super_admin/screens/analytics/analytics_reports_screen.dart` | Supabase Real Orders Aggregation | Clean (fabrication multipliers removed) |
| 5 | Admin Login | `lib/features/super_admin/screens/auth/admin_login_screen.dart` | Supabase Auth & Role Check | Clean |
| 6 | Category Governance | `lib/features/super_admin/screens/catalog/category_governance_screen.dart` | Supabase Categories | Clean |
| 7 | Product Moderation | `lib/features/super_admin/screens/catalog/product_moderation_screen.dart` | Supabase Products | Clean |
| 8 | CMS & Legal Docs | `lib/features/super_admin/screens/cms/cms_content_screen.dart` | Canonical Legal Texts / Banners | Clean |
| 9 | Customer Management | `lib/features/super_admin/screens/customers/customer_management_screen.dart` | Supabase Profiles (Buyers) | Clean (wired to `profiles`) |
| 10 | Disputes & Arbitration | `lib/features/super_admin/screens/disputes/dispute_arbitration_screen.dart` | Supabase `return_requests` | Clean (wired to `return_requests`) |
| 11 | Commission Engine | `lib/features/super_admin/screens/finance/commission_engine_screen.dart` | Supabase `commission_rules` & RPC | Clean (wired to DB & RPC) |
| 12 | Payout Ledger | `lib/features/super_admin/screens/finance/payout_ledger_screen.dart` | Supabase Payouts / Financial Ledger | Clean (fabrication loop removed) |
| 13 | Notifications Broadcast | `lib/features/super_admin/screens/marketing/notifications_broadcast_screen.dart` | Supabase `notifications` & RPC | Clean (wired to DB & RPC) |
| 14 | Promotions & CMS | `lib/features/super_admin/screens/marketing/promotions_cms_screen.dart` | Supabase Vouchers | Clean |
| 15 | Master Orders | `lib/features/super_admin/screens/orders/master_orders_screen.dart` | Supabase `buyer_orders` | Clean |
| 16 | Reviews Moderation | `lib/features/super_admin/screens/reviews/reviews_moderation_screen.dart` | Supabase `product_reviews` | Clean (mock reviews removed) |
| 17 | Fraud & Security | `lib/features/super_admin/screens/security/fraud_security_screen.dart` | Admin Audit Logs | Clean ("Chulbul Store" removed) |
| 18 | Seller Governance | `lib/features/super_admin/screens/sellers/seller_governance_screen.dart` | Supabase `seller_stores` | Clean |
| 19 | Admin Staff Management | `lib/features/super_admin/screens/settings/admin_staff_management_screen.dart` | Supabase `user_roles` & `profiles` | Clean (wired to `user_roles`) |
| 20 | Platform Config | `lib/features/super_admin/screens/settings/platform_config_screen.dart` | Supabase `platform_integrations` | Clean (secrets removed) |
| 21 | Shipping Governance | `lib/features/super_admin/screens/shipping/shipping_governance_screen.dart` | Supabase `platform_integrations` | Clean (secrets removed) |
| 22 | Support Desk | `lib/features/super_admin/screens/support/support_desk_screen.dart` | Supabase `support_tickets` | Clean (wired to `support_tickets`) |

### Summary of Governance Migration (`supabase/migrations/20260818000000_task5_super_admin_governance.sql`):
1. Created `commission_rules` table with RLS and `admin_update_commission_rule` RPC.
2. Created `support_tickets` table with RLS and role permissions.
3. Created `cms_banners` table with RLS for promotional homepage banners.
4. Created `admin_broadcast_notification` RPC dispatching real push records to `public.notifications`.

### Tests Added / Updated:
- `supabase/tests/task5_super_admin_governance_test.sql` (6 pgTAP assertions covering tables, functions, and seed data).
- `test/task5_super_admin_governance_test.dart` (4 tests covering session initialization, RBAC checks, commission model, and customer model). All 4 passed!

---


## TASK 6 — Break Up Giant Files: COMPLETED
- Decomposed monolithic `buyer_dashboard.dart` by extracting 1,948 lines of bottom widget cards into `lib/features/buyer/widgets/dashboard/buyer_dashboard_cards.dart` using modular `part` directive.
- Preserved internal class bindings without breaking dependent unit tests.
- Full test suite passed (318/318).

---

## TASK 7 — Security Hardening & Web Policies: COMPLETED
- Configured production security headers in `vercel.json` (`Content-Security-Policy`, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy: camera=(), microphone=(), geolocation=()`).
- Added OpenGraph and SEO meta tags to `web/index.html`.
- Created `web/robots.txt` restricting sensitive admin and seller routes from web crawler indexing.
- Created migration `supabase/migrations/20260819000000_task7_security_hardening.sql`:
  - `rate_limit_events` table and `enforce_rate_limit` `SECURITY DEFINER` function with strict search path.
  - CHECK constraints on `support_tickets` (subject length 3-255), `product_reviews` (rating 1-5, comment length 2-2000), and `vouchers` (code alphanumeric format and positive value).
- Added `supabase/tests/task7_security_penetration_test.sql` and `test/task7_security_test.dart` (3/3 PASSED).

---

## TASK 8 — Repo Hygiene and Documentation: COMPLETED
- Moved unnumbered migrations `all_migrations_combined.sql` and `update_meta.sql` into `supabase/archive/` to ensure clean sequential `supabase db push`.
- Initialized local Git repository, verified `.gitignore` excludes `build/`, `.dart_tool/`, `.idea/`, `.env`, and created clean initial commit.
- Updated `HANDOFF.md` with verified repository directory (`D:\apna store original`), all 17 sequential migrations, and test counts.

---

## TASK 9 — Launch Readiness (Non-Payment): COMPLETED
- Created database performance indexes migration: `supabase/migrations/20260820000000_task9_performance_indexes.sql` targeting hot queries across `products`, `orders`, `order_items`, `notifications`, `vouchers`, and `support_tickets`.
- Created `docs/LAUNCH_CHECKLIST.md` detailing infrastructure, operational, and rollback procedures.
- Created `docs/QA_SMOKE_TEST.md` with full step-by-step end-to-end verification workflows for Buyer, Seller, and Super Admin portals.
- Verified all legal routes and policies.

---

## FINAL SYSTEM AUDIT SUMMARY
- **`flutter analyze lib/`**: 0 ERRORS.
- **`flutter test`**: 321 / 321 PASSED (100% pass rate).
- **Payment Safety Guard**: Cash on Delivery strictly enforced (`onlinePaymentsEnabled = false`).
- **All 9 Pre-Launch Tasks**: FULLY COMPLETED. Task 10 (Payment Gateway) reserved for separate session as required.
