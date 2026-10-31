# Apna Store — Remediation & Completion Prompt

**For:** an autonomous coding agent working inside this repository
**Source:** derived from the 14-phase forensic audit of this codebase
**Stack:** Flutter 3.44 / Dart 3.12 · Supabase (PostgreSQL + GoTrue + Storage) · `provider` state management

---

## 0. READ THIS BEFORE WRITING ANY CODE

### 0.1 What this project actually is

This repository contains **two projects that were never joined**:

1. **A well-built PostgreSQL backend.** 8 migrations, 25 tables, RLS on every table, column-level `GRANT`/`REVOKE` protecting privilege-bearing columns, an append-only wallet ledger with a tamper trigger, tamper-proof audit logs, and 42 `SECURITY DEFINER` functions. `create_atomic_order` does server-side pricing, atomic stock decrement, and idempotency correctly.

2. **A Flutter app that barely uses it.** The client calls **8 of the 42 backend functions**. Products, seller stores, carts, wishlists, chat and notifications live in browser `localStorage` or in memory. Where the client *does* attempt a database write, it frequently targets a column the database has explicitly revoked; the write fails; a `catch { debugPrint(...) }` swallows the error and updates the local cache anyway, so **the UI reports success and nothing was saved.**

**Your job is to close the gap between the two — not to rebuild either one.**

### 0.2 Non-negotiable ground rules

| # | Rule |
|---|------|
| **R1** | **Never weaken the database security model.** Do not add `GRANT` statements on `approval_status`, `is_approved`, `kyc_status`, `commission_rate`, `balance`, `pending_payout`, `last_payout`, `rejection_reason`, or any INSERT/UPDATE grant on `buyer_orders`, `order_items`, `order_status_history`, `wallet_transactions`, `payments`, `refunds`, `audit_logs`. These revocations are deliberate and correct. If a client write is rejected, the fix is **use the RPC**, never **open the grant**. |
| **R2** | **Never swallow an error and continue as if it succeeded.** Every `catch` that logs to `debugPrint` and then mutates local state must be removed. Failures must surface to the user and to logging. This single anti-pattern is the root cause of the majority of findings. |
| **R3** | **Never fabricate data on a failure path.** No fake order numbers, no default prices, no synthesised user objects, no hardcoded totals. If an operation fails, it failed. |
| **R4** | **The server owns money and status.** Prices, totals, shipping, discounts, commission, stock, approval status and order status are computed and written server-side only. The client sends identifiers and quantities; it never sends an amount. |
| **R5** | **Do not delete or rewrite existing migrations.** Add new numbered migration files. The applied migration history must stay intact. |
| **R6** | **Run `flutter analyze` after every module.** Do not increase the issue count. Do not add new warnings. |
| **R7** | **Work module by module in the order given.** Modules declare their dependencies. Do not start a module whose dependency is incomplete. |
| **R8** | **Commit per module** with the module ID in the message (e.g. `M2: route buyer auth through AppAuthProvider`). Do not batch modules into one commit. |
| **R9** | **When you delete a screen, delete its route, its `AppRoutes` constant, and its import.** Leave no dangling references. |
| **R10** | **Ask before inventing product behaviour.** If a fix requires a business decision not specified here (e.g. the real free-shipping threshold), stop and ask. Do not guess and ship. |

### 0.3 Baseline health — measure before you start

Record these numbers, then re-measure after each phase:

```bash
flutter pub get
flutter analyze          # baseline: 846 issues (0 errors, 106 warnings, 740 info)
flutter test             # baseline: 115 pass / 168 fail (283 total)
```

The 168 test failures share **one** root cause, fixed in **M1**. Expect the suite to largely recover after that module.

### 0.4 Reference — column grants you MUST respect

These are the *only* columns `authenticated` may write. Every DTO you build must match these lists exactly.

**`public.products`**
```
INSERT: seller_store_id, category_id, name, description, price, sale_price,
        stock_quantity, image_url, category, is_active
UPDATE: name, description, price, sale_price, category_id, image_url,
        category, is_active
```
> Note: `stock_quantity` is INSERT-only. After creation it may only change via `seller_update_product_stock` RPC or the internal checkout decrement. `approval_status`, `rating`, `id`, `created_at` are server-owned.

**`public.seller_stores`**
```
INSERT: owner_id, shop_name, shop_slug, business_name, business_address,
        city, country, category, shop_description, shop_logo, shop_banner
UPDATE: shop_name, shop_slug, business_name, business_address, city, country,
        category, shop_description, shop_logo, shop_banner, updated_at
```
> `id`, `is_approved`, `kyc_status`, `commission_rate`, `balance`, `pending_payout`, `last_payout` are server-owned.

**`public.seller_kyc_documents`**
```
INSERT: seller_store_id, document_type, document_url, cnic_number,
        ntn_number, submitted_by
```
> `status`, `reviewed_by`, `reviewed_at`, `rejection_reason` are server-owned.

**`public.product_variants`**
```
INSERT: product_id, seller_store_id, sku, variant_name, attributes, price_override
UPDATE: variant_name, attributes, price_override, is_active
```

**`buyer_orders`, `order_items`, `order_status_history`, `wallet_*`, `payments`, `refunds`, `payout_requests`, `audit_logs`** — `SELECT` only. All writes go through RPCs.

### 0.5 Reference — backend functions that already exist and are unused

Do not reimplement any of these. Wire them up.

| RPC | Purpose | Currently called? |
|---|---|---|
| `create_atomic_order` | Full checkout: pricing, stock, commission, idempotency | Yes, but failures are masked |
| `cancel_order` | Buyer/seller order cancellation with stock restore | Service only — no UI |
| `seller_update_fulfillment_status` | Fulfilment state machine + tracking events + notifications | Wrong caller |
| `seller_update_product_stock` | Guarded stock adjustment | Not awaited |
| `seller_update_variant_stock` | Variant stock adjustment | **No** |
| `get_seller_orders` | Seller-isolated order view (no cross-seller totals) | **No** |
| `submit_return_request` / `review_return_request` | Full returns + refund settlement | **No** |
| `submit_product_review` | Verified-purchase review | Service only |
| `send_chat_message` / `create_chat_room` | Buyer↔seller chat | Wrong room id / **No** |
| `mark_notification_read` | Notifications | Service only |
| `admin_review_seller_store` | Approve/reject a store + audit log | **No** |
| `admin_review_seller_application` | Full seller application review | **No** |
| `admin_review_product` | Approve/reject a listing + audit log | **No** |
| `admin_review_kyc_document` | KYC verification + audit log | **No** |
| `seller_submit_kyc_resubmission` | KYC resubmission | **No** |
| `assign_user_role` / `assign_role_permission` | Role administration | **No** |
| `has_permission(module, action)` | Server-side RBAC check | **No** |
| `admin_toggle_seller_suspension` / `admin_toggle_payout_lock` | Seller enforcement | **No** |
| `seller_request_payout` | Payout request with hold reservation | Yes ✔ |
| `get_seller_wallet_summary` | Derived wallet balances | Yes ✔ |
| `admin_process_payout` / `admin_process_refund` / `admin_process_cod_settlement` / `admin_adjust_seller_wallet` | Money movement | **No** |
| `reconcile_financial_ledger` | Ledger integrity check | **No** |

---

# PHASE A — STOP THE BLEEDING

> **Scope:** ~1 week. Mostly deletion. Do not start Phase B until every module here is complete and verified.
> **Why first:** the app currently ships an authentication bypass, an anonymous-access hole, and a checkout that reports success when it fails. Every other fix is unverifiable while failures stay invisible.

---

## M1 — Restore the build and the test suite

**Depends on:** nothing. **Do this first.**
**Why:** `ProductRepository` resolves `Supabase.instance` in a constructor default. `CatalogController` constructs one during field initialisation, and `AppStateProvider` constructs a `CatalogController`. When Supabase is not initialised, the entire provider tree throws. This fails 168 of 283 tests and white-screens the app.

### Steps

1. **`lib/core/services/product_repository.dart`** — make client resolution lazy.
   ```dart
   class ProductRepository {
     final SupabaseClient? _injected;
     ProductRepository({SupabaseClient? client}) : _injected = client;
     SupabaseClient get _client => _injected ?? Supabase.instance.client;
     // ... rest unchanged
   }
   ```

2. **Apply the same lazy pattern** to every service that resolves `Supabase.instance.client` in a constructor initialiser:
   - `lib/core/services/supabase_service.dart`
   - `lib/core/services/supabase_seller_service.dart`
   - `lib/core/services/supabase_orders_service.dart`
   - `lib/core/services/supabase_checkout_service.dart`
   - `lib/core/services/supabase_finance_service.dart`
   - `lib/core/services/supabase_reviews_service.dart`
   - `lib/core/services/supabase_returns_service.dart`
   - `lib/core/services/supabase_chat_service.dart`
   - `lib/core/services/supabase_notifications_service.dart`
   - `lib/core/services/app_auth_provider.dart`

3. **`lib/core/controllers/orders_controller.dart:13`** — remove `fetchOrdersFromSupabase()` from the constructor. Expose it and let screens call it in `initState`. Constructors must not perform I/O.

4. **`lib/core/controllers/catalog_controller.dart:14-21`** — remove `loadProductsFromLocalStorage()` and `WebHelper.listenStorage(...)` from the constructor body. Add an explicit `Future<void> initialize()` called once from the app shell.

5. **`lib/main.dart:22-30`** — the comment `'Supabase init error (using mock fallback)'` is false; there is no fallback. Replace the silent catch with a real failure path:
   ```dart
   bool supabaseReady = true;
   try {
     AppConfig.validate();
     await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
   } catch (e, st) {
     supabaseReady = false;
     debugPrint('FATAL: Supabase initialisation failed: $e\n$st');
   }
   if (!supabaseReady) {
     runApp(const StartupFailureApp());   // new minimal widget: explains the failure, offers retry
     return;
   }
   ```

6. **`lib/core/config/app_config.dart`** — `validate()` currently only throws in production. Make it throw whenever `SUPABASE_URL` or `SUPABASE_ANON_KEY` is empty, in **all** environments. Delete the `demo-apnastore.supabase.co` and demo-JWT fallbacks — a misconfigured build must fail loudly, not point at a project that does not exist.

7. **`lib/main.dart:26`** — replace the deprecated `anonKey:` parameter with `publishableKey:`.

### Acceptance criteria
- [ ] `flutter test` failure count drops from 168 to **under 20**. Report the exact number and list any remaining failures with their distinct causes.
- [ ] `flutter analyze` issue count does not increase.
- [ ] Launching without `--dart-define=SUPABASE_URL=...` shows a readable startup-failure screen, not a blank page.
- [ ] No service resolves `Supabase.instance` before `main()` completes initialisation.

---

## M2 — Close the authentication and authorisation holes

**Depends on:** M1.
**Why:** four independent defects let an anonymous or unprivileged user reach seller and super-admin surfaces.

### Steps

1. **`lib/core/services/app_auth_provider.dart:118-137`** — **delete the entire non-production fallback branch** inside the `catch` of `login()`.

   The current code fabricates an authenticated `User` on *any* login failure, assigning role `super_admin` when the submitted email contains the substring `admin` and `seller` otherwise. `AppConfig.environment` defaults to `development`, so this ships in the default build. The catch must do exactly this and nothing else:
   ```dart
   } catch (e, st) {
     _isLoading = false;
     _status = AuthStatus.unauthenticated;
     _currentUser = null;
     _currentRole = null;
     const failure = AuthenticationFailure(message: 'Invalid email address or password.');
     _errorMessage = failure.message;
     notifyListeners();
     throw failure;
   }
   ```

2. **`lib/core/routes/app_router.dart:107`** — invert the default in `_isSellerAuthorized()`:
   ```dart
   final role = _getAuthenticatedUserRole();
   if (role == null) return false;              // was: return true;
   return role == 'seller' || role == 'admin' || role == 'superadmin';
   ```
   The class doc comment claims "default-deny"; the implementation was default-allow. Every route under `/seller/*` was reachable by an anonymous visitor.

3. **`lib/features/seller/screens/seller_auth_screens.dart:198-202`** — remove the privilege escalation. The current `else` branch sets `AppRouter.activeDevRole = 'seller'` for *any* successfully authenticated account. Replace with:
   ```dart
   if (normalizedRole == 'seller' || normalizedRole == 'admin' ||
       normalizedRole == 'superadmin' || normalizedRole == 'super_admin' || normalizedRole == 'owner') {
     Navigator.pushReplacementNamed(context, '/seller/dashboard');
   } else {
     await authProvider.signOut();
     setState(() {
       _isLoading = false;
       _errorMessage = 'This account is not registered as a seller.';
     });
   }
   ```

4. **Delete `AppRouter.activeDevRole` entirely** (`app_router.dart:80`). It is a mutable public static with no server verification, set from three screens and cleared by nothing.
   - Replace `_getAuthenticatedUserRole()` with a resolver that reads the role from `AppAuthProvider` (which loads it from the protected `user_roles` table).
   - Because `onGenerateRoute` has no `BuildContext`, expose the current role via a small `AuthState` singleton that `AppAuthProvider` updates on every auth state change, and have the router read that.
   - Keep the `@visibleForTesting testRoleResolver` seam — the existing tests depend on it.
   - Remove the three assignment sites: `seller_auth_screens.dart:199,201`, `seller_landing_page.dart:491,493`, `admin_login_screen.dart:201`.

5. **Clear all global state on sign-out.** In both `AppAuthProvider.signOut()` and `SuperAdminProvider.logout()`, reset the auth singleton, the admin session, and `_SellerDashboardState._activeSection`. Currently role state survives logout until a page reload.

6. **`lib/features/seller/screens/seller_dashboard.dart:34`** — change `static String _activeSection` to an instance field. A static field on a `State` class is process-global and leaks between users on a shared browser.

7. **Add a widget-level guard** to every seller and admin screen so a stale route or a direct `Navigator.push` cannot bypass the router check. Use the existing, currently-dead `AdminAuthGuard.guardRoute` for admin screens (see M11 for making its RBAC real).

### Acceptance criteria
- [ ] Submitting `admin@test.com` with a wrong password on `/super-admin/login` shows an error. It must **not** grant access.
- [ ] Navigating to `/seller/dashboard` while signed out redirects to `/seller/login`.
- [ ] Signing in as a buyer on `/seller/login` shows "not registered as a seller" and does not navigate.
- [ ] After sign-out, navigating back to `/seller/dashboard` redirects to login without a page reload.
- [ ] `grep -rn "activeDevRole" lib/` returns nothing.

---

## M3 — Make checkout tell the truth

**Depends on:** M1.
**Why:** `SupabaseCheckoutService.checkout()` catches every exception and returns a fabricated success object with a hardcoded `grand_total: 3150.0`. Because it never throws, every downstream `try/catch` in the checkout screens is unreachable dead code. A logged-out user with no network connection completes checkout, sees an order number, and lands on the confirmation screen. No order exists.

### Steps

1. **`lib/core/services/supabase_checkout_service.dart:52-58`** — delete the fabricated return. Rethrow a mapped failure:
   ```dart
   } catch (e, st) {
     _isSubmitting = false;
     _errorMessage = _mapCheckoutError(e);
     notifyListeners();
     throw FailureMapper.mapException(e, st);
   }
   ```

2. **Add `_mapCheckoutError`** translating the `PostgrestException` messages raised by `create_atomic_order` into user-facing text:

   | Server message contains | Show the user |
   |---|---|
   | `Unauthenticated request` | "Please sign in to place your order." |
   | `Insufficient stock for product` | "«Product» is no longer available in that quantity." |
   | `is unavailable or belongs to an unapproved` | "«Product» is no longer available." |
   | `Payment method % is not currently available` | "Only Cash on Delivery is available right now." |
   | `Idempotency conflict` | "This order was already submitted. Check your order history." |
   | `Cart items array cannot be empty` | "Your cart is empty." |
   | anything else | "We couldn't place your order. Please try again." |

3. **`lib/features/buyer/screens/checkout/buyer_checkout_screen.dart:135-180`** — stop constructing a local `AppOrder` from invented values. The current code hardcodes `couponDiscount: 500.0, commissionDeducted: 315.0, finalPayout: 2835.0` regardless of the real total, and falls back to `?? 3150.0` for price. Delete all of it. On success, read the returned `order_number` and `grand_total` from the RPC response, and re-fetch orders from the server rather than pushing into a presentation cache.

4. **Do not clear the cart until the RPC returns success.** Currently `state.clearCart()` runs unconditionally.

5. **`lib/core/services/app_state_provider.dart:999-1051`** — apply the same treatment to `placeOrder()`. Additionally, it hardcodes `'quantity': 1` and `commissionDeducted: grandTotal * 0.10` / `finalPayout: grandTotal * 0.90`. Remove the hardcoded commission — the server already returns per-item commission in `order_items`.

6. **`lib/features/buyer/screens/checkout/buyer_checkout_screen.dart:200`** — remove the invented price fallback `int.tryParse(...) ?? 3455`.

### Acceptance criteria
- [ ] Placing an order while signed out shows "Please sign in to place your order." The cart is **not** cleared and the app does **not** navigate to the success screen.
- [ ] Placing an order with an out-of-stock item shows a stock-specific message.
- [ ] No order number is generated anywhere on the client. `grep -rn "ORD_\${DateTime" lib/` returns nothing.
- [ ] `grep -rn "3150\|3455\|2835\|315.0" lib/` returns nothing.

---

## M4 — Remove the fake payment gateway

**Depends on:** M3.
**Why:** `/buyer/payment` is a second, contradictory checkout path. It presents JazzCash, Easypaisa, Raast and card as live, collects a 16-digit card number and CVV in plaintext `TextField`s, and prints the "verification OTP" on screen as `849201` — which the confirm handler never compares against the user's input. It then bypasses `create_atomic_order` and calls `insertBuyerOrder()` with a **client-computed `amount`**. The insert is currently rejected by `REVOKE ALL ON public.buyer_orders`, and the resulting exception is unhandled, so the screen hangs on "Processing Secure Transaction…" forever.

Collecting card data in an unintegrated form is a PCI-DSS liability even in a prototype.

### Steps

1. **Delete** `lib/features/buyer/screens/checkout/buyer_payment_gateway_screen.dart`.
2. **Delete** the `buyerPayment` constant from `lib/core/routes/app_routes.dart` and its case in `app_router.dart`. Fix any navigation that targeted it.
3. **Delete** `SupabaseService.insertBuyerOrder()` (`lib/core/services/supabase_service.dart:84-110`) and the now-unused `OrderDto` import. Checkout must only go through `create_atomic_order`.
4. **Keep** `lib/features/buyer/widgets/checkout/checkout_payment_selector.dart` as-is — it is honest: COD is enabled and the other three are disabled with a "Coming Soon" badge. Add a client-side assertion that the selected method is `'COD'` before calling checkout, matching the server's gate.
5. **Audit `SupabaseService` for what remains.** It duplicates `AppAuthProvider` with a divergent role source (`profiles.role` vs `user_roles`). After removing `insertBuyerOrder`, if `login`/`signUp`/`logout` are the only members left, delete the whole class and its provider registration in `main.dart`, migrating any callers to `AppAuthProvider`.

### Acceptance criteria
- [ ] No screen in the app collects a card number or CVV.
- [ ] `grep -rn "849201\|insertBuyerOrder" lib/` returns nothing.
- [ ] Navigating to `/buyer/payment` resolves to `UnknownRouteScreen` (or the route is fully removed from the app's navigation).

---

## M5 — Stop hiding persistence failures

**Depends on:** M1.
**Why:** roughly twenty `catch { debugPrint(...) }` blocks swallow database rejections and then mutate the local cache anyway. This makes RLS and grant violations invisible in the field and is the mechanism by which the entire catalogue ended up in `localStorage`.

### Steps

1. **`lib/core/services/app_state_provider.dart`** — remove the "update cache anyway" fallback from every one of these:
   - `addProduct` (line ~931) — `catch { debugPrint(...); catalogController.syncAddProductCache(product); }`
   - `addCategory` (line ~942)
   - `adjustStock` (line ~953) — additionally, the RPC call is not awaited, so its `try` catches nothing. Make it `Future<void>` and `await` the call.
   - `updateOrderStatus` (line ~969) — currently updates the cache *before* calling the RPC.
   - `approveStore` / `rejectStore` / `adjustCommission` / `approveProduct` / `rejectProduct` (lines 1119–1214) — these are rewritten in **M9**; for now, make the failure visible.

   The pattern to apply everywhere:
   ```dart
   Future<void> addProduct(AppProduct product) async {
     await ProductRepository().createProduct(product.toDatabaseMap()); // may throw — let it
     await catalogController.fetchProductsFromSupabase();              // re-read from source of truth
   }
   ```
   Callers wrap in try/catch and show an error to the user.

2. **`lib/core/controllers/catalog_controller.dart:56-58`** — `fetchProductsFromSupabase` catches and calls `loadProductsFromLocalStorage()`. Remove the localStorage fallback; set an error state instead so the UI can show "Couldn't load products. Retry."

3. **`lib/core/controllers/catalog_controller.dart:49`** — `if (response.isNotEmpty)` means an empty result silently retains stale cached products. Always replace the list, including with an empty one.

4. **`lib/core/controllers/orders_controller.dart:29`** — same defect. Always replace.

5. **Add a shared error surface.** Create `lib/core/widgets/error_banner.dart` and a `showErrorSnack(BuildContext, Object error)` helper that renders a mapped, human-readable message. Route every caught failure through it. No user-facing operation may fail silently.

6. **Add an error boundary.** Wrap the router's builders so an uncaught widget exception renders a recoverable error screen instead of a red screen or a blank page.

### Acceptance criteria
- [ ] `grep -rn "catch" lib/core/services/app_state_provider.dart` shows no block that mutates state after logging.
- [ ] Disconnecting from the network and attempting to add a product shows an error to the user; the product does **not** appear in any list.
- [ ] `flutter analyze` reports zero `unused_catch_stack`.

---

## M6 — Remove fabricated pricing, mock data and prototype shortcuts

**Depends on:** M3.
**Why:** the client computes a total the server does not honour. A two-seller cart worth PKR 6,000 displays PKR 5,500 and creates an order for PKR 6,150.

The client computes `subtotal + shipping − 500`, where shipping is free above PKR 5,000 else `uniqueStores × 150`, and the 500 is a `final int _couponDiscount = 500` applied to every cart with no coupon entered. The server computes `subtotal + 150.00 − 0.00` — flat shipping, zero discount. There is no coupon system in the schema at all.

### Steps

1. **Delete the phantom coupon.**
   - `buyer_checkout_screen.dart:38` — `final int _couponDiscount = 500;`
   - `buyer_cart_checkout_screen.dart:49-50` — `_appliedCoupon = 'EID2026'`, `_couponDiscount = 500`
   - `buyer_cart_checkout_screen.dart:672-696` — the "Apply Code" button that ignores its input and always toasts "Voucher applied successfully! Saved PKR 500", and the permanent "Active Promo Applied: EID2026" badge.

   Either remove the coupon UI entirely, or leave the input disabled with "Promo codes coming soon". Do not display a discount that will not be charged.

2. **Stop computing shipping on the client.** `buyer_checkout_screen.dart:202` and the cart's free-shipping progress bar both invent a shipping policy. Until **M13** adds a `quote_order` RPC, display shipping as "Calculated at confirmation" and show only the subtotal.

3. **Reconcile the free-shipping claims.** Four different thresholds appear in the UI: `dev_version_banner.dart:26` says Rs. 1,999; `buyer_dashboard.dart:1832` says 1,000 PKR; `buyer_cart_checkout_screen.dart:51` says 5,000; the server charges 150 always. **Stop and ask the product owner which is correct**, then define it once in `lib/core/constants/` and reference that constant everywhere.

4. **Remove the auto-approval bypass.** `lib/features/seller/screens/catalog/seller_product_catalog_screen.dart:396`:
   ```dart
   approvalStatus: 'Approved', // Auto-approved for instant prototype testing!
   ```
   The database default is `'Pending'` and the client cannot write this column at all. Remove the field from the client model's write path entirely.

5. **Remove hardcoded seller attribution.** Same file, line ~386: `sellerId: 'seller_1'`. Every product from every seller is currently attributed to one store. Derive the store id from the signed-in seller (see **M8**).

6. **Remove silent default substitution.** `lib/features/seller/widgets/dashboard/seller_dashboard_products.dart:156-168` substitutes `'Embroidered Cotton Kurta'`, price `'3500'`, and stock `50` when fields are blank. Replace with real form validation that blocks submission.

7. **Remove seeded mock data from `app_state_provider.dart`:**
   - `_initializeMockData()` (line ~689) — seeds a fake store named "chulbul"
   - `getPriceHistory()` (line ~858) — fabricates a 5-point price history by multiplying the current price, and uses `double.parse` (not `tryParse`), which throws on any non-numeric price
   - `_walletCash = 4500.0`, `_walletPromoCredits = 800.0` (line ~570)
   - `_currentBudgetSpent = 3700.0` (line ~547)
   - `_bnplCreditLimit = 30000.0` (line ~579)
   - the hardcoded `_announcements` list

8. **Remove data fabrication in parsing.** `AppProduct.fromJson` (line ~220) defaults missing `stock` to **100**, `approvalStatus` to `'Approved'`, `rating` to `'5.0'`, `category` to `'Fashion'`, `name` to `'Product'`. Every one of these invents availability or approval. Default stock to `0`, approval to `'Pending'`, and make `name`/`price` required — a row that lacks them is malformed and should be skipped with a logged warning.

9. **Remove the fake chat auto-reply.** `app_state_provider.dart:1101-1108` schedules a `Future.delayed(1s)` that appends a canned reply attributed to the seller. Customers receive a fabricated response from a merchant who never saw the message.

10. **Remove the instant local refund.** `requestReturn()` (line ~1054) immediately credits `_walletCash`, appends a wallet transaction and debits `store.balance` — with no approval step, no evidence, no eligibility window and no server call. Delete the local wallet mutation entirely; returns are wired properly in **M10**.

11. **Remove `arbitrateDispute`'s ignored parameter** (line ~1231) — it sets `disputeStatus = 'Resolved'` and never reads `resolution`. Either implement it or delete the method and its callers.

12. **Remove the two garbled placeholder label sets** in `product_details_screen.dart:28-42` — `_filtersState` and `_sellerFiltersState` contain nonsense strings (`'Networkorns'`, `'Sexisionine'`, `'Sbatistation'`, `'Abeal'`, `'Silibre'`). They are currently unrendered dead code; delete them and their `_buildFilterItem` / `_buildSellerItem` builders before someone wires them up.

### Acceptance criteria
- [ ] No screen displays a discount, shipping fee or total that the server will not honour.
- [ ] `grep -rniE "EID2026|_couponDiscount|seller_1|Auto-approved|Embroidered Cotton Kurta" lib/` returns nothing.
- [ ] A blank product form cannot be submitted.
- [ ] `flutter analyze` reports zero `double.parse` on user-supplied strings.

---

## M7 — Kill the production dev-tooling

**Depends on:** nothing.
**Why:** `DevVersionBanner` fires an HTTP `HEAD` request to `/main.dart.js` **every 3 seconds, forever**, in every user session — 1,200 requests per hour per session — and can auto-reload the page mid-checkout.

### Steps

1. **`lib/core/widgets/dev_version_banner.dart:56`** — gate the entire poller behind `kDebugMode`:
   ```dart
   if (kDebugMode) { _startBuildPoller(); }
   ```
2. **Separate the two concerns.** This widget is doing two unrelated jobs: a dev build-poller *and* the site's marketing announcement ticker. Extract the ticker into its own `AnnouncementTicker` widget, and drive its content from the CMS once **M14** lands. Until then, keep the strings but reconcile them with M6 step 3.
3. **Verify both `Timer.periodic` instances are cancelled in `dispose()`.**
4. **`lib/core/constants/app_version.dart`** — the version and build number are hand-maintained strings. Generate them at build time from `pubspec.yaml` and the CI build number, or remove the display.

### Acceptance criteria
- [ ] A release web build issues no repeating background requests. Verify in the browser Network tab over 60 seconds.
- [ ] No timer survives widget disposal.

---

### ✅ PHASE A GATE

Do not proceed until all of the following hold:

- [ ] `flutter analyze` — issue count is **at or below** the 846 baseline, with zero new warnings
- [ ] `flutter test` — fewer than 20 failures, each with a documented cause
- [ ] No authentication or authorisation bypass remains (M2 acceptance criteria all pass)
- [ ] No operation reports success on a failure path (M3, M5 acceptance criteria all pass)
- [ ] No screen displays a price the server will not charge (M6)
- [ ] Write a short `PHASE_A_REPORT.md` recording before/after numbers for analyze and test, and listing every file deleted.

---

# PHASE B — MAKE THE CORE MARKETPLACE REAL

> **Scope:** ~4–6 weeks. This is where the app starts actually persisting data.
> **Prerequisite:** Phase A gate passed.

---

## M8 — Real buyer and seller identity

**Depends on:** M2.
**Why:** `loginCustomer({required String email, required String password})` sets four local strings, derives a display name from the email local-part, hardcodes the phone as `'03001234567'`, and **never reads the `password` parameter**. `registerCustomer` is the same shape — no `signUp` call, no `profiles` row. The result is a "session" with no Supabase JWT, so every RLS-protected call runs as `anon` and fails.

### Steps

1. **Delete from `lib/core/services/app_state_provider.dart`:**
   - `loginCustomer` (line ~1250)
   - `registerCustomer` (line ~1264)
   - `logoutCustomer` (line ~1278)
   - `customerLogin` / `customerLogout` (lines ~750, ~759)
   - `saveCustomerSessionToLocalStorage` / `loadCustomerSessionFromLocalStorage`
   - the `_isCustomerLoggedIn`, `_loggedInCustomerName`, `_loggedInCustomerEmail`, `_loggedInCustomerPhone` fields

2. **Derive identity from the real session instead.** Replace the getters:
   ```dart
   bool get isCustomerLoggedIn => Supabase.instance.client.auth.currentSession != null;
   ```
   and read the display name from the `profiles` row loaded by `AppAuthProvider`.

3. **Rewire every buyer auth entry point** to `AppAuthProvider.login` / `.signUp`:
   - `lib/features/buyer/screens/auth/customer_auth_dialog.dart`
   - `lib/features/buyer/widgets/dashboard/buyer_auth_dialog.dart`
   - `lib/features/buyer/screens/auth/buyer_auth_onboarding_screen.dart`
   - `lib/features/buyer/screens/auth/buyer_mobile_sign_in_screen.dart`

4. **Add real form validation** on both dialogs: email format, password minimum length, password confirmation match, duplicate-email error surfaced from the server response.

5. **Never send a role from the client.** `SupabaseService.signUp` passes `data: {'role': role}` and `SupabaseSellerService.registerSeller` upserts `role: 'seller'` into `profiles`. Remove both. Roles are assigned server-side via `assign_user_role` under admin authority. (`handle_new_user` currently ignores the metadata, but do not rely on that invariant.)

6. **Resolve the split role source.** `profiles.role` (from the legacy `user_role` enum, migration 01) and `user_roles.role` (from `app_role`, migration 02) are never synchronised. `user_roles` is authoritative. Add a new migration that:
   - backfills `user_roles` from any `profiles.role` values not already present
   - drops the `profiles.role` column
   - drops the orphaned `public.sellers` table from migration 01 (superseded by `seller_stores`, never referenced)

7. **Derive the seller's store from the session.** In `lib/features/seller/screens/seller_dashboard.dart:34,43-50`, remove `_activeSellerId = 'seller_1'` and the `state.setLoggedInSellerId('seller_1')` fallback. Query `seller_stores` where `owner_id = auth.uid()`. If no store exists, render an explicit "You don't have a store yet — complete registration" state. Never default to another seller's store.

8. **Handle the password-reset return link.** `resetPasswordForEmail` is called but there is no deep-link handler for the recovery URL and no "set new password" screen. Add both.

9. **Gate on email verification** where it matters. `isEmailVerified` is computed and never used — decide (with the product owner) whether checkout requires a verified email, then enforce it.

### Acceptance criteria
- [ ] A buyer registration creates an `auth.users` row and a `profiles` row. Verify in the database.
- [ ] Signing in with a wrong password shows an error and does not create a session.
- [ ] `grep -rn "loginCustomer\|registerCustomer\|03001234567" lib/` returns nothing.
- [ ] A seller with no store sees the "no store" state, not another seller's dashboard.
- [ ] After the migration, `profiles.role` no longer exists and `user_roles` is the only role source.

---

## M9 — Real catalogue: create, read, edit, delete

**Depends on:** M8.
**Why:** `AppProduct.toJson()` sends `id`, `sellerId`, `title`, `imageUrl`, `rating`, `stock`, `approvalStatus`, `approval_status`, `rejectionReason`, `additionalImages` and `videoUrl` to the `products` INSERT. Several are not columns; `approval_status` is explicitly withheld. The insert cannot succeed. `seller_store_id` also receives `'seller_<timestamp>'`, which is not a UUID. Every failure is swallowed (fixed in M5), so **the entire product catalogue lives only in the visitor's browser localStorage** — not shared between users, not visible to admins, and freely editable from DevTools.

### Steps

1. **Split the model from the wire format.** `AppProduct` is a UI model; do not send it to the database. Add explicit, grant-matched mappers:
   ```dart
   // lib/core/models/dtos/product_dto.dart
   Map<String, dynamic> toInsertMap() => {
     'seller_store_id': sellerStoreId,   // real UUID
     'category_id':     categoryId,
     'name':            name,
     'description':     description,
     'price':           price,           // num, NOT String
     'sale_price':      salePrice,
     'stock_quantity':  stockQuantity,
     'image_url':       imageUrl,
     'category':        category,
     'is_active':       isActive,
   };

   Map<String, dynamic> toUpdateMap() => {
     'name': name, 'description': description, 'price': price,
     'sale_price': salePrice, 'category_id': categoryId,
     'image_url': imageUrl, 'category': category, 'is_active': isActive,
   };
   ```
   Note `stock_quantity` appears in insert only — after creation it changes via `seller_update_product_stock`.

2. **Change `AppProduct.price` and `.rating` from `String` to `num`.** They map to `NUMERIC(12,2)` and `NUMERIC(3,2)`. The string representation is why `int.tryParse(p.price)` silently yields 0 for any decimal price, and why the cart subtotal is wrong for such items.

3. **Fix `SellerStoreDto.toDatabaseMap()`** (`lib/core/models/dtos/seller_store_dto.dart:83-105`) the same way. It currently sends `id`, `is_approved`, `kyc_status`, `commission_rate`, `balance`, `pending_payout` and `last_payout` — none grantable. Restrict to the INSERT list in §0.4 and let the database generate `id`.

4. **Add a `seller_create_product` RPC** in a new migration so the server owns `id`, `approval_status` and `sku`, and can verify that the calling seller owns an approved, non-suspended store. Model it on the existing `seller_update_product_stock`. Grant `EXECUTE` to `authenticated` only.

5. **Build a product edit screen.** None exists. A seller can create a listing and can never correct a typo, change a price, or take it down. Wire it to `toUpdateMap()`.

6. **Add product delete (soft).** No delete path exists anywhere in the codebase. Use `is_active = false` — already in the UPDATE grant. Add the action to both the seller catalogue and the admin product list.

7. **Add product drafts.** `approvalStatus` supports `'Draft'` but no UI produces it. Add a "Save as draft" action that sets `is_active = false` and leaves approval `Pending`.

8. **Replace the hardcoded storefront catalogue.** `lib/features/buyer/widgets/dashboard/buyer_product_listing_section.dart:103` returns a hardcoded array of Sony, Apple MacBook, LG, Nike and Canon products keyed by category name. Replace with `state.activeProducts` filtered by category. Do the same in `category_products_screen.dart:26`, which falls back to a hardcoded array whenever real matches are fewer than 4.

9. **Fix the product gallery.** `product_details_screen.dart:72-79` always appends the same five unrelated Unsplash photos to every product — a headphone listing displays a leather jacket. Render `product.additionalImages` and show a single placeholder when empty.

10. **Stop using localStorage as the store of record.** In `catalog_controller.dart` and `seller_controller.dart`, keep localStorage strictly as a read-through cache with a short TTL, or remove it entirely. Never read business state from it. Remove the cross-tab `WebHelper.listenStorage` handlers that propagate injected records.

### Acceptance criteria
- [ ] Creating a product as a seller inserts a row in `public.products` with `approval_status = 'Pending'`. Verify in the database.
- [ ] The product does **not** appear in the buyer storefront until an admin approves it.
- [ ] Editing a product updates the database row.
- [ ] Deactivating a product removes it from the buyer storefront.
- [ ] Two different browsers, signed in as two different sellers, see two different catalogues.
- [ ] `grep -rn "'prod_\${DateTime\|seller_\${DateTime" lib/` returns nothing.

---

## M10 — Persistent cart, addresses, and a truthful price quote

**Depends on:** M8, M9.
**Why:** `CartController.addToCart(product, quantity: n)` executes `for (i<n) _cartProducts.add(product)` — the same object reference repeated. There is no quantity field, no stock ceiling, no persistence, and `subtotal` uses `int.tryParse` so any decimal price contributes **zero**. There is no `carts` table, and no `addresses` table either — the shipping address is an unvalidated JSONB blob per order with no reuse.

### Steps

1. **New migration — `carts` and `cart_items`:**
   ```sql
   CREATE TABLE public.carts (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
     created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
     updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
   );
   CREATE TABLE public.cart_items (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     cart_id UUID NOT NULL REFERENCES public.carts(id) ON DELETE CASCADE,
     product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
     variant_id UUID REFERENCES public.product_variants(id) ON DELETE CASCADE,
     quantity INT NOT NULL CHECK (quantity > 0),
     added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
     UNIQUE (cart_id, product_id, variant_id)
   );
   ```
   Enable RLS on both, scoped to `user_id = auth.uid()`. Index `cart_items(cart_id)`. Grant only the columns a client legitimately sets (`product_id`, `variant_id`, `quantity`).
   **Do not store price in the cart** — price is always read live from `products` at quote and checkout time.

2. **New migration — `addresses`:**
   ```sql
   CREATE TABLE public.addresses (
     id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
     user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
     label TEXT DEFAULT 'Home',
     recipient_name TEXT NOT NULL,
     phone TEXT NOT NULL,
     alt_phone TEXT,
     address_line TEXT NOT NULL,
     city TEXT NOT NULL,
     province TEXT NOT NULL,
     union_council TEXT,
     landmark TEXT,
     postal_code TEXT,
     delivery_instructions TEXT,
     is_default BOOLEAN NOT NULL DEFAULT FALSE,
     created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
     updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
   );
   CREATE UNIQUE INDEX idx_addresses_one_default
     ON public.addresses (user_id) WHERE is_default;
   ```
   RLS scoped to `user_id = auth.uid()`.

3. **Rewrite `CartController`** around a real item model:
   ```dart
   class CartItem {
     final String productId;
     final String? variantId;
     int quantity;
     // display fields hydrated from products on load
   }
   ```
   - `addToCart` increments an existing line rather than duplicating the object
   - `cartCount` returns total units, not row count
   - quantity is clamped to available stock on both add and increment
   - `subtotal` uses `num`, never `int.tryParse`
   - all mutations sync to `cart_items`

4. **Migrate the in-memory address book.** `AppStateProvider.addAddress` / `editAddress` / `deleteAddress` / `setDefaultAddress` (lines 803–841) become `addresses` table operations. Wire `buyer_address_location_screen.dart` and `checkout_address_section.dart` to them.

5. **Add a `quote_order` RPC.** This is the key to permanently ending the display-vs-charge divergence. It must share the exact pricing path as `create_atomic_order` — same product lookup, same variant price override, same commission rate, same shipping rule — but perform no writes:
   ```sql
   CREATE OR REPLACE FUNCTION public.quote_order(
     p_items JSONB,
     p_shipping_address JSONB DEFAULT '{}'::jsonb,
     p_coupon_code TEXT DEFAULT NULL
   ) RETURNS JSONB  -- {subtotal, shipping_fee, discount_amount, grand_total, lines[], unavailable[]}
   ```
   Refactor `create_atomic_order`'s pricing block into a shared internal function that both call, so they can never drift.

6. **Drive every displayed total from `quote_order`.** The cart and checkout screens stop computing arithmetic entirely; they render what the server returns.

7. **Make shipping configurable server-side.** `create_atomic_order` hardcodes `v_calculated_shipping := 150.00` (migration 09, line 453) — no zones, no weight, no free-shipping threshold, and it ignores how many stores are in the order. Add a `shipping_rules` table (zone, threshold, flat fee, per-store fee) and read from it in the shared pricing function.

8. **Wire `create_atomic_order` to the real cart** — send `cart_items` rows, not a synthesised list. Clear the server cart on success inside the same transaction.

### Acceptance criteria
- [ ] Adding to the cart, refreshing the page, and returning shows the same cart.
- [ ] Signing in on a second device shows the same cart.
- [ ] A product priced `1299.50` contributes `1299.50` to the subtotal, not `0`.
- [ ] Attempting to add more than the available stock is blocked with a message.
- [ ] The total shown on the checkout screen **exactly equals** `buyer_orders.grand_total` for the created order. Verify with a two-seller cart above and below the shipping threshold.
- [ ] Saved addresses persist across sessions and the default address is pre-selected at checkout.

---

## M11 — Real search, filtering, sorting and pagination

**Depends on:** M9.
**Why:** `searchQuery` is interpolated into a heading string — `'Search Results for "$searchQuery"'` — and is never used in a `where` clause. The grid below renders a hardcoded array. The item count reads a literal `'1,420 Items Found'` regardless of what is displayed. Brand checkboxes do filter, and then `final displayList = filtered.isEmpty ? rawProducts : filtered;` silently restores the unfiltered list whenever the filter matches nothing.

There is no sort control anywhere, and no pagination anywhere — `from('products').select('*')` fetches the entire catalogue, which Supabase silently truncates at `max_rows = 1000`.

### Steps

1. **Add a full-text index** in a new migration:
   ```sql
   ALTER TABLE public.products ADD COLUMN IF NOT EXISTS search_vector tsvector
     GENERATED ALWAYS AS (
       setweight(to_tsvector('simple', coalesce(name,'')), 'A') ||
       setweight(to_tsvector('simple', coalesce(description,'')), 'B') ||
       setweight(to_tsvector('simple', coalesce(category,'')), 'C')
     ) STORED;
   CREATE INDEX idx_products_search ON public.products USING GIN (search_vector);
   CREATE EXTENSION IF NOT EXISTS pg_trgm;
   CREATE INDEX idx_products_name_trgm ON public.products USING GIN (name gin_trgm_ops);
   ```

2. **Add a `search_products` RPC** taking query text, category, price range, sort key and `limit`/`offset`, returning results plus a total count. Enforce the same visibility rules as the products SELECT policy.

3. **Wire the header search.** A screen that already implements real filtering over `state.activeProducts` exists at `/buyer/search-filter` (`buyer_search_filter_screen.dart`) — and **nothing in the app ever navigates to it**. Either route the header search there, or fold its logic into the listing section. Do not leave two search implementations.

4. **Fix the silent filter fallback** at `buyer_product_listing_section.dart:491`. When a filter matches nothing, show a "No products match these filters — clear filters" empty state. Never render the unfiltered list.

5. **Replace the hardcoded result count** (`'1,420 Items Found'`, line ~480) with the real count returned by the RPC.

6. **Add a sort control** — relevance, price ascending, price descending, newest, rating.

7. **Add pagination everywhere.** Use `.range(offset, offset + pageSize - 1)` on every list query: products, orders, sellers, reviews, wallet transactions, admin tables. Add infinite scroll or a pager to each list UI.

8. **Wire the brand filter to real data** once a `brands` table exists (**M14**). Until then, remove the hardcoded brand checkbox list rather than shipping a filter over fictional brands.

### Acceptance criteria
- [ ] Searching for a term returns only matching products, with an accurate count.
- [ ] A search with no matches shows an empty state, not the full catalogue.
- [ ] Filters and sort visibly change the result set.
- [ ] A catalogue of 1,500 products is fully reachable by scrolling or paging.

---

## M12 — Seller fulfilment and order lifecycle

**Depends on:** M10.
**Why:** `seller_order_dispatch_screen.dart` owns a hardcoded `List<OrderDispatchItem>` of three fictional orders (ORD-9081 Ali Raza, ORD-9082 Saima Khan, ORD-9083 Usman Tariq). "Pack Order" and "Ready to Ship" execute `setState(() => order.status = ...)` and show a toast; the list is a non-static instance field, so every status change is discarded on navigation. Meanwhile `seller_update_fulfillment_status` — a complete RPC with state-machine validation, tracking-event insertion and buyer notification — is never called from this screen.

### Steps

1. **`lib/features/seller/screens/orders/seller_order_dispatch_screen.dart`** — delete the hardcoded `_orders` list. Load from `SupabaseOrdersService.getSellerStoreFulfillments(storeId)` using the store id derived in M8.

2. **Wire every action button** to `SupabaseOrdersService.updateFulfillmentStatus(...)`, awaiting the result and refetching on success. Show the server's error message on failure.

3. **Prefer `get_seller_orders()`** over the current nested select `select('*, buyer_orders(*, order_items(*))')`, which is an N+1 pattern and risks exposing cross-seller grand totals. The RPC already flattens this and isolates the seller correctly.

4. **Add order cancellation.** `cancel_order` is fully implemented with stock restore and has no caller. Add a cancel action to:
   - the buyer's order detail screen (subject to the server's status rules)
   - the seller's dispatch screen

5. **Wire real order tracking.** `buyer_order_tracking_screen.dart` reads `OrdersController` but renders a static timeline. Load `getOrderTrackingEvents(orderId)` and render the real event sequence.

6. **Show multi-seller order splitting.** The server already creates one `store_fulfillments` row per store via `trg_auto_create_store_fulfillments`. The buyer UI never shows them. Group order items by store in the order detail view, with per-store status.

7. **Replace `updateOrderStatus`'s cache-first pattern** in `app_state_provider.dart:969` — it updates the presentation cache *before* calling the RPC. Invert: call, await, then refetch.

8. **Disable the fake print actions.** "Print Bulk Airway Bills" and "Print AWB Label" show toasts. `FeatureFlags.hardwarePrinterIntegrationEnabled` already exists and is `false` — gate the buttons on it so they render disabled with an explanatory tooltip.

### Acceptance criteria
- [ ] The dispatch screen shows the seller's real fulfilments, and only their own.
- [ ] Marking an order packed changes `store_fulfillments.status` in the database and survives navigation and refresh.
- [ ] The buyer sees the status change and receives a notification row.
- [ ] Cancelling an order restores stock. Verify `products.stock_quantity` before and after.
- [ ] A seller cannot see another seller's grand totals in any network response.

---

## M13 — Returns, refunds and reviews

**Depends on:** M12.
**Why:** the real returns workflow exists and is unreachable — `supabase_returns_service.dart` is **never imported by any file**. `submit_product_review` is implemented and never called from the buyer app; the PDP renders hardcoded reviews and hardcoded Q&A.

### Steps

1. **Wire `buyer_returns_claims_screen.dart`** to `SupabaseReturnsService.submitReturnRequest(...)`, replacing the hardcoded `_activeClaims` list. Include evidence upload (depends on **M15**).
2. **Wire `seller_returns_disputes_screen.dart`** and the admin dispute screen to `reviewReturnRequest(returnId, decision, adminNotes)`.
3. **Wire admin refunds** to `admin_process_refund`. Currently the seller can request and nobody can approve.
4. **Add review submission to the PDP.** Call `submit_product_review(productId, orderItemId, rating, comment)` — the RPC already enforces verified purchase. Gate the UI on the buyer having a delivered `order_item` for that product.
5. **Render real reviews.** Replace the hardcoded `_sellerReviews` and `_productQuestions` arrays in `product_reviews_section.dart:18,33` with `SupabaseReviewsService.getProductReviews(productId)`.
6. **Remove `rateProduct()`** (`app_state_provider.dart:1215`) — it overwrites the product's rating string locally with no aggregation. Ratings are aggregated server-side from `product_reviews`; add a trigger or a scheduled recompute that maintains `products.rating`.
7. **Add a unique constraint** `(product_id, buyer_id)` on `product_reviews` — duplicate prevention currently lives only inside the RPC, not in the schema.
8. **Decide on Q&A.** There is no schema for it. Either add a `product_questions` table with an answer workflow, or remove the Q&A tab.

### Acceptance criteria
- [ ] A buyer can request a return only on a delivered item, and it creates a `return_requests` row.
- [ ] An admin approving the return creates a `refunds` row and a `wallet_transactions` entry.
- [ ] A buyer who has not purchased a product cannot submit a review — verify the server rejects it.
- [ ] Product ratings on the storefront reflect real review data.

---

### ✅ PHASE B GATE

Run the full seller lifecycle end to end on a clean database and confirm every step persists:

**Seller registers → Admin approves store → Seller completes KYC → Admin verifies KYC → Seller creates product → Admin approves product → Product appears on the storefront → Buyer registers → Buyer searches and finds it → Buyer adds to cart → Buyer checks out → Order row created with correct totals → Stock decremented → Seller sees the order → Seller marks it shipped → Buyer sees tracking → Buyer receives it → Buyer reviews it → Seller's wallet reflects the payable**

- [ ] Every step above verified in the database, not just the UI
- [ ] Two sellers, two buyers, two browsers — no data leaks between them
- [ ] Write `PHASE_B_REPORT.md` documenting the walkthrough with database evidence

---

# PHASE C — SELLER & ADMIN OPERATIONS

---

## M14 — Admin governance: approvals, moderation, KYC

**Depends on:** M9.
**Why:** `approveStore`, `rejectStore`, `adjustCommission`, `approveProduct` and `rejectProduct` all attempt a direct `.update()` on `is_approved` / `kyc_status` / `rejection_reason` / `commission_rate` / `approval_status`. None of these columns appear in any `GRANT UPDATE`. Column privileges are not role-conditional, so the update is rejected **even for an admin JWT**. `adjustCommission` additionally never awaits its future.

The correct entry points already exist and are ignored — each `SECURITY DEFINER`, each writing an audit entry via `internal_record_audit_log`.

### Steps

1. **Replace all five methods** in `app_state_provider.dart:1119-1214` with RPC calls:

   | Current method | Replace with |
   |---|---|
   | `approveStore(storeId)` | `admin_review_seller_store(storeId, true, commissionRate)` |
   | `rejectStore(storeId, reason)` | `admin_review_seller_store(storeId, false, null)` |
   | `approveProduct(productId)` | `admin_review_product(productId, true)` |
   | `rejectProduct(productId, reason)` | `admin_review_product(productId, false)` |
   | `adjustCommission(storeId, rate)` | `admin_review_seller_store(storeId, isApproved, rate)` |

   Await each call, then refetch from the server. Only update the local cache from the returned row.

2. **Read admin lists from the database, not from `AppStateProvider`.** `seller_governance_screen.dart` and `product_moderation_screen.dart` currently read `state.stores` and `state.products` — i.e. localStorage. Query `seller_stores` and `products` directly; the admin's RLS policy already grants full visibility via `is_admin()`.

3. **Build the KYC review screen.** None exists. List `seller_kyc_documents` with signed URLs from `getSignedKycUrl(path)` (implemented, never called), and wire approve/reject to `admin_review_kyc_document`.

4. **Wire `admin_review_seller_application`** for the full application flow, and `seller_submit_kyc_resubmission` for the seller's re-upload path after rejection.

5. **Replace static admin lists with real queries** in these modules, or remove the module until its schema exists:

   | Screen | Currently | Action |
   |---|---|---|
   | `customer_management_screen` | hardcoded `_customers` | Query `profiles` + `user_roles` |
   | `master_orders_screen` | reads localStorage | Query `buyer_orders` with filters |
   | `category_governance_screen` | hardcoded `_categories`, `_brands` | Query `categories`; **add a `brands` table** |
   | `commission_engine_screen` | hardcoded `_rules` | Query `seller_stores.commission_rate`; add a rules table if per-category rates are needed |
   | `payout_ledger_screen` | hardcoded `_paymentTxns` | Query `payout_requests` + `payments` |
   | `dispute_arbitration_screen` | hardcoded `_claims` | Query `return_requests` |
   | `shipping_governance_screen` | hardcoded `_couriers`, `_zones` | Backed by the `shipping_rules` table from M10 |
   | `promotions_cms_screen` | hardcoded `_vouchers`, `_campaigns` | Needs a coupons schema — **M17** |
   | `cms_content_screen` | hardcoded `_faqs` | Needs a CMS schema — **M17** |
   | `support_desk_screen` | hardcoded `_tickets` | Needs a tickets schema, or remove |
   | `fraud_security_screen` | hardcoded `_alerts` | Remove until real signals exist |
   | `notifications_broadcast_screen` | hardcoded `_broadcastHistory` | Wire to `internal_create_notification` via a new admin RPC |
   | `analytics_reports_screen` | hardcoded KPIs | Build real aggregate queries — **M16** |
   | `ai_copilot_screen` | static | Remove; `FeatureFlags.aiCopilotEnabled` is already `false` |

6. **Persist the audit trail.** `SuperAdminProvider.logAuditAction` writes to an in-memory list lost on refresh, while the tamper-proof `audit_logs` table is never written to by the app. The `admin_*` RPCs already write audit entries — read from `audit_logs` in the admin audit view and delete the in-memory list.

7. **Delete the duplicate admin panel.** `lib/features/admin/screens/admin_dashboard.dart` is an 865-line second console duplicating `/super-admin`'s seller approvals. Remove it, its route, and its `AppRoutes.admin` constant.

### Acceptance criteria
- [ ] Approving a seller sets `seller_stores.is_approved = true` in the database and writes an `audit_logs` row.
- [ ] Approving a product sets `products.approval_status = 'Approved'` and the product appears on the storefront.
- [ ] Rejecting either records the reason and notifies the seller.
- [ ] No admin screen reads from `AppStateProvider` or localStorage.
- [ ] An admin action that fails shows the error; it does not appear to succeed.

---

## M15 — Real RBAC, staff and user administration

**Depends on:** M14.
**Why:** `RbacEngine` defines a 12-role permission matrix and `AdminAuthGuard.guardRoute` renders proper denial screens — and **neither is referenced by a single other file**. Even if wired, `SuperAdminProvider._mapRoleStringToEnum` ends with an unconditional `return AdminRole.superAdmin;`, so a finance admin, support admin or auditor all map to `superAdmin`, whose matrix entry is `{'*': ['*']}`.

The database has the correct mechanism — a `role_permissions` table and a `has_permission(module, action)` function — which the client never calls.

### Steps

1. **Enforce authorisation server-side first.** Every `admin_*` RPC must call `has_permission('<module>', '<action>')` and raise on failure. Client-side guards are for UI affordance only and must never be the sole control.

2. **Fix `_mapRoleStringToEnum`** (`super_admin_provider.dart:57-62`). An unknown role string must map to a least-privilege role or throw — never to `superAdmin`.

3. **Load permissions from the server.** Replace `RbacEngine`'s hardcoded matrix with a fetch from `role_permissions` at session start, cached for the session.

4. **Actually apply `AdminAuthGuard.guardRoute`** in `admin_shell.dart:_buildActiveModuleView`, passing the correct `requiredModule` / `requiredAction` per case.

5. **Build user and role administration.** `assign_user_role` and `assign_role_permission` have no UI. Add screens for granting roles, and wire `admin_toggle_seller_suspension` and `admin_toggle_payout_lock` to the seller governance screen.

6. **Decide on seller staff accounts.** `seller_staff_permissions_screen.dart` is decorative with no schema. Either add a `seller_staff` table with its own RLS, or remove the screen.

### Acceptance criteria
- [ ] A user with a `supportAdmin` role cannot execute `admin_process_payout` — verify the **server** rejects it, not just that the button is hidden.
- [ ] Navigating directly to a restricted admin module shows the denial screen.
- [ ] `grep -rn "AdminAuthGuard" lib/` shows real usage.

---

## M16 — Real finance: payouts, settlements, seller analytics

**Depends on:** M12, M15.
**Why:** `seller_request_payout` and `get_seller_wallet_summary` are genuinely wired — the best-integrated feature in the app. But `admin_process_payout`, `admin_process_refund`, `admin_process_cod_settlement` and `admin_adjust_seller_wallet` are implemented in `SupabaseFinanceService` and **never called from any UI**. Sellers can request payouts that nobody can approve. The marketplace cannot pay anyone.

Separately, every seller dashboard KPI is hardcoded: "Total sales PKR 450,780", "Store visitors 3,210", "Conversion rate 2.8%", "92%", "85%", "14,250 Visitors". Analytics also displays "Platform Fee (5%)" while commission is 10% everywhere else.

### Steps

1. **Build the admin payout queue.** List `payout_requests` with status filters; wire approve/reject to `admin_process_payout`.
2. **Build COD settlement.** Wire `admin_process_cod_settlement` so delivered COD orders credit the seller's wallet.
3. **Wire `admin_adjust_seller_wallet`** for manual corrections, with a mandatory reason recorded in the audit log.
4. **Expose `reconcile_financial_ledger`** as an admin integrity check with a visible pass/fail result.
5. **Replace all hardcoded seller KPIs** in `seller_dashboard_overview.dart:562-567` and `seller_dashboard_analytics.dart:131-134,330-332` with real aggregates. Add server-side aggregate RPCs — do not compute these by fetching all orders to the client.
6. **Fix the commission inconsistency.** Commission is hardcoded as 10% in `placeOrder` and `buyer_checkout_screen`, and displayed as 5% in analytics. The authoritative value is `seller_stores.commission_rate` per store, snapshotted per line in `order_items.commission_rate`. Read it; never hardcode it.
7. **Remove the fake export buttons** — "Download PDF" and "Export CSV" show toasts. Either implement real export or remove them.
8. **Remove the fake buyer wallet and BNPL.** `_walletCash`, `_walletPromoCredits`, `_bnplStatus`, `_bnplCreditLimit`, `chargeBnpl` and `applyForBnpl` in `app_state_provider.dart` are seeded local numbers presenting themselves as financial products. Delete them, or build them properly on the `wallet_accounts` ledger. Do not ship the middle ground.

### Acceptance criteria
- [ ] A seller payout request can be approved by an admin, and the wallet balance and `wallet_transactions` reflect it.
- [ ] Every number on the seller dashboard traces to a database query. Verify each one.
- [ ] Commission displayed to a seller matches `order_items.commission_amount` for their orders.
- [ ] `reconcile_financial_ledger` returns a clean result after a full order → delivery → settlement → payout cycle.

---

## M17 — Communications, notifications and content

**Depends on:** M12.
**Why:** chat calls `send_chat_message` with a fabricated room id `'room_$customerName'` that can never match a UUID in `chat_rooms`, and `create_chat_room` is never invoked so no room exists to match. `supabase_notifications_service.dart` is never imported. All merchandising and legal content is hardcoded in Dart.

### Steps

1. **Fix chat room creation.** Call `create_chat_room(buyerId, storeId, productId)` on first message, store the returned UUID, and use it for all subsequent `send_chat_message` calls. Replace the in-memory `_chats` map with `chat_messages` queries and a realtime subscription.
2. **Wire real notifications.** Replace the static `_notifications` list in `seller_notifications_center_screen.dart:34` with `getUserNotifications()`, and wire mark-as-read to `mark_notification_read`. Add a notification bell with an unread count to the buyer, seller and admin shells.
3. **Add a CMS schema** — `cms_pages`, `faqs`, `banners`, `homepage_sections`. Admin-writable, publicly readable.
4. **Wire the footer.** `app_footer.dart:211,242,270` — every link is `onTap: () {}`: About Us, Privacy Policy, Terms & Conditions, FAQs, Careers, Blog, Return Policy, social icons and app-store badges. Privacy Policy and Terms are legally expected on a commerce site. Build the pages from the CMS or remove the links.
5. **Drive banners and homepage sections from the CMS** instead of the hardcoded carousel.
6. **Add a coupons schema** — `coupons` (code, type, value, min spend, usage limit, per-user limit, valid window, applicable categories/sellers) and `coupon_redemptions`. Extend `quote_order` and `create_atomic_order` to validate and apply a coupon code atomically, enforcing the usage limits inside the transaction. Only then restore the coupon UI removed in M6.
7. **Configure email and SMS.** No SMTP or SMS provider is set in `supabase/config.toml`. Wire order confirmations, shipping notifications, password resets and OTP.
8. **Replace the fake OTP flows.** `buyer_mobile_otp_screen.dart` and the KYC onboarding "Send SMS OTP" button send nothing and verify nothing. Either integrate a real provider or remove the screens.

### Acceptance criteria
- [ ] A buyer message reaches the seller's inbox in the database and appears in their UI.
- [ ] Order status changes generate notification rows that the buyer sees.
- [ ] Privacy Policy and Terms & Conditions are reachable from the footer.
- [ ] A coupon code applied at checkout produces the same discount in `quote_order` and in the created order, and cannot be reused past its limit.

---

# PHASE D — UX, RESPONSIVENESS, PERFORMANCE, CLEANUP

---

## M18 — Decide and implement the mobile strategy

**Depends on:** Phase B.
**Why:** `ResponsiveBuilder` exists and is **never instantiated**. `AppBreakpoints` is referenced by only two files. Eleven `/buyer/mobile-*` screens are routable but never navigated to. Mobile users receive the desktop layout at 320px.

### Steps

1. **Make the call, then execute it fully.** Two viable options:
   - **(a) Adaptive single screen** — delete the 11 duplicate mobile screens and make the existing screens genuinely responsive with `LayoutBuilder`. *Recommended:* one code path, no drift.
   - **(b) Route-level split** — wrap each route in `ResponsiveBuilder(mobileLayout:, webLayout:)`. Keeps both, doubles the maintenance.

   Note that the mobile screens are also **less complete** than their desktop counterparts (most have zero backend wiring), so option (a) loses very little.

2. **Fix fixed-width dialogs.** Replace hardcoded widths with `AppBreakpoints.getResponsiveDialogWidth(context)`, which already exists and is called in exactly one place:

   | File | Width |
   |---|---|
   | `admin_shell.dart:559` | 700 |
   | `seller_governance_screen.dart:542` | 650 |
   | `product_moderation_screen.dart:377` | 600 |
   | `master_orders_screen.dart:417` | 580 |
   | `support_desk_screen.dart:315` | 580 |
   | `customer_management_screen.dart:370` | 550 |
   | `dispute_arbitration_screen.dart:370` | 550 |
   | `seller_store_setup_screen.dart:410` | 850 |
   | `seller_dashboard_header.dart:49` | 340 |

3. **Wrap every wide table** in a horizontally scrollable container so the page body never scrolls sideways.

4. **Test at 320 / 375 / 390 / 414 / 768 / 1024 / 1440 / 1920 px.** Document overflow, overlap, cut-off text, unreachable buttons and broken modals at each. Fix all of them.

5. **Delete `admin_data_table.dart`** — a dead widget with no usages — or adopt it consistently across admin tables.

### Acceptance criteria
- [ ] No horizontal body scroll at any of the eight viewports on any screen.
- [ ] Every dialog fits within a 320px viewport.
- [ ] Either the mobile screens are reachable, or they are deleted. No unreachable duplicates remain.

---

## M19 — Feedback, states and accessibility

**Depends on:** Phase B.

### Steps

1. **Loading states on every fetch.** Loading indicators exist on some submit buttons (`_isSubmitting`) but on no list fetch — screens render empty, then populate. Add skeletons.
2. **Empty states everywhere.** Some lists show a designed empty view, others render nothing. Standardise.
3. **Error states everywhere.** Every failed fetch shows a message and a retry action.
4. **Add `errorBuilder` to all 51 `Image.network` calls** — 21 currently lack one, so a dead URL renders a grey box.
5. **Replace the 77 empty handlers** (`onTap: () {}`) — implement or remove the control. A visible control that does nothing is worse than no control.
6. **Replace the 112 toast-only handlers.** Success toasts on actions that did nothing — "Product published successfully", "KYC Documents Submitted for Review", "Order Packed & Invoiced" — actively deceive sellers, who will discover it at their first reconciliation.
7. **Make "Add to Cart" and "Buy Now" consistent.** "Buy Now" gates on login; "Add to Cart" does not.
8. **Enforce the unenforced checkbox.** `seller_kyc_onboarding_screen.dart` has `_policyAccepted` which never gates the continue action.
9. **Accessibility:**
   - `Semantics` labels and tooltips on all icon-only buttons
   - fix contrast: `#94A3B8` and `#CBD5E1` on white fall below WCAG AA at small sizes
   - visible keyboard focus on custom `InkWell` controls
   - respect OS text scaling — text sizes are currently fixed in logical pixels throughout

### Acceptance criteria
- [ ] `grep -rn "onTap: () {}\|onPressed: () {}" lib/` returns nothing.
- [ ] No success message is shown for an operation that did not persist.
- [ ] Every list has a loading, empty and error state.
- [ ] Keyboard-only navigation reaches every interactive control with a visible focus ring.

---

## M20 — Performance

**Depends on:** Phase B.

### Steps

1. **Split `buyer_dashboard.dart` (5,461 LOC).** `Provider.of<AppStateProvider>(context)` at the top of `build` rebuilds the entire homepage on any state change, including a cart-count increment. Break into `Selector`/`Consumer` subtrees scoped to what each actually reads.
2. **Add `cached_network_image`.** 51 raw `Image.network` calls re-download on every scroll with no memory or disk cache. Add `cacheWidth`/`cacheHeight` hints to size the decode.
3. **Debounce localStorage writes.** `saveProductsToLocalStorage()` JSON-encodes the entire catalogue synchronously on the main thread after every add or stock change. Once M9 removes localStorage as the store of record this largely disappears; debounce whatever remains.
4. **Eliminate duplicate fetches.** `OrdersController`'s constructor fires a fetch and screens fetch again on mount (the constructor call is removed in M1 — verify no screen double-fetches).
5. **Optimise assets.** `assets/images/ramzan_banner.png` is 478 KB — one third of the total asset payload in a single unoptimised PNG. Convert to WebP and serve responsive sizes.
6. **Delete dead code.** 51 unreferenced private methods (≈44 in `buyer_dashboard.dart` alone) and 11 dead files. Tree-shaking cannot remove referenced-but-unused class members.
7. **Apply the analyzer's `prefer_const` fixes** — roughly 120 avoidable rebuild allocations.
8. **Verify pagination** from M11 is applied to every list without exception.

### Acceptance criteria
- [ ] Adding an item to the cart does not rebuild the product grid. Verify with the Flutter DevTools rebuild counter.
- [ ] Scrolling the storefront twice issues no duplicate image requests.
- [ ] Release web bundle size measured and recorded before and after dead-code removal.

---

## M21 — Code quality and structural cleanup

**Depends on:** all prior modules.

### Steps

1. **Delete the 11 dead files:**
   `category_dto.dart` · `kyc_dto.dart` · `profile_dto.dart` · `core/models/product.dart` · `order_repository.dart` · `seller_repository.dart` · `supabase_notifications_service.dart`\* · `supabase_returns_service.dart`\* · `buyer_product_details_screen.dart` · `admin_auth_guard.dart`\* · `admin_data_table.dart`
   \* these three should be **wired up** rather than deleted — see M13, M15, M17.

2. **Remove all remaining duplicates:**
   - two admin panels (M14 removes one)
   - two checkout paths (M4 removes one)
   - two product-detail screens
   - two auth providers with divergent role sources (M4/M8)
   - two seller-registration writers (M9)

3. **Break up `AppStateProvider` (1,300 LOC).** It spans auth, cart, orders, wallet, BNPL, chat, admin moderation, vouchers and budget tracking. After Phases A–C most of it should already be gone; move what remains into the relevant controllers and delete the facade.

4. **Break up the remaining monoliths:**
   `buyer_dashboard.dart` (5,461) · `seller_landing_page.dart` (1,417) · `seller_auth_screens.dart` (1,046) · `buyer_cart_checkout_screen.dart` (975)

5. **Remove methods with ignored parameters:**
   - `submitKyc(sellerId, cnic, ntn)` — ignores `cnic` and `ntn` (line 922)
   - `arbitrateDispute(orderId, resolution)` — ignores `resolution` (line 1231)

6. **Fix the mangled non-English strings.** Several Urdu strings survive only as stray punctuation — `app_state_provider.dart:746` (budget warning) and `:1105` (chat auto-reply, deleted in M6). Restore them properly or remove them. Consider adding real i18n if Urdu is a target language.

7. **Extract remaining hardcoded values** to `lib/core/constants/`: commission rates, shipping fees, thresholds, page sizes, timeouts.

8. **Clear the analyzer backlog** — target zero warnings:
   15 unused imports · 17 unused locals · 12 unused fields · ~120 `prefer_const` · ~60 `withOpacity` deprecations · ~25 `use_build_context_synchronously` · 3 `unnecessary_null_comparison` (dead null checks on the non-nullable `session.user`) · 1 stray `@override` at `category_products_screen.dart:25`

9. **Upgrade dependencies:** `flutter_lints` 3.0.0 → 6.x (two major versions of rules missed), `supabase_flutter` 2.16.0 → 2.17.2.

10. **Migrate off `dart:html`.** `web_helper_real.dart` uses the deprecated `dart:html`, which blocks Wasm compilation. Move to `package:web` + `dart:js_interop`.

11. **Repo hygiene.** `build/`, `node_modules/`, `.dart_tool/` and a 620 KB `.docx` are committed. Nine stray planning markdown files sit at the project root. Update `.gitignore` and remove them from tracking.

12. **Add structured logging and crash reporting.** `debugPrint` is not observability. There is currently no way to know that anything failed in production.

### Acceptance criteria
- [ ] `flutter analyze` reports **zero** warnings and zero errors.
- [ ] No file exceeds 800 lines.
- [ ] No `debugPrint` remains on an error path.
- [ ] `git status` is clean and build artefacts are untracked.

---

## M22 — Restore and extend the test suite

**Depends on:** all prior modules.

### Steps

1. **Fix any tests still failing after M1.** Report each remaining failure with its cause.
2. **Update tests invalidated by behaviour changes** — particularly the routing and auth tests, which currently assert the *old* default-allow behaviour. `test/routing_test.dart` and `test/phase_5_auth_test.dart` must be updated to assert default-deny.
3. **Add widget tests** for the flows most likely to regress: checkout, buyer auth, seller auth, cart quantity and stock clamping, admin approval.
4. **Add integration tests** for the full seller and buyer lifecycles from the Phase B gate.
5. **Run the seven pgTAP suites** in `supabase/tests/` against a local Postgres. They have never been executed.
6. **Wire CI** to run `flutter analyze`, `flutter test` and the pgTAP suites on every push.

### Acceptance criteria
- [ ] `flutter test` — 100% pass.
- [ ] pgTAP suites — 100% pass.
- [ ] CI blocks a merge on any analyze warning or test failure.

---

# PHASE E — GROWTH

Only after Phases A–D are complete and the Phase B gate walkthrough passes.

| Module | Scope | Notes |
|---|---|---|
| **M23** Online payments | JazzCash / Easypaisa / card, with webhook reconciliation against `payments` | `create_atomic_order`'s payment-method gate must be extended in the same change. COD-only limits conversion and raises RTO cost. |
| **M24** Product variants on the PDP | `product_variants` schema and RPCs already exist; no UI reads them | Fashion and electronics are not viable categories without variants. |
| **M25** Brands and attributes | New schema + admin management + faceted filtering | Unblocks the brand filter removed in M11. |
| **M26** Courier integration | Real tracking; `FeatureFlags.realCourierApiEnabled` is already `false` and honest | Manual dispatch does not scale. |
| **M27** Merchandising | Flash sales, scheduled campaigns, featured products, real recommendations | All currently static screens. |
| **M28** Wishlist and recently viewed | Persist properly; the wishlist screen currently renders a hardcoded list instead of the actual wishlist | |
| **M29** Loyalty, B2B, sponsored ads | All behind `FeatureFlags` that are already `false` | Leave disabled until the core is proven. |

---

## Appendix A — Files that are pure static UI

These 64 files have **zero** backend or provider wiring. When a module says "wire this screen", these are what it means. Each must either be connected to real data or deleted.

**Buyer (25):** `ai/buyer_ai_copilot_screen` · `auth/buyer_auth_onboarding_screen` · `auth/buyer_mobile_otp_screen` · `auth/buyer_mobile_sign_in_screen` · `auth/buyer_onboarding_carousel_screen` · `b2b/buyer_b2b_digital_screen` · `buyer_splash_screen` · `campaigns/buyer_campaign_vouchers_screen` · `cart/buyer_mobile_cart_screen` · `category/buyer_mobile_categories_screen` · `chat/buyer_chat_qa_screen` · `checkout/buyer_mobile_order_success_screen` · `checkout/buyer_order_success_screen` · `home/buyer_dynamic_home_screen` · `home/buyer_mobile_home_screen` · `orders/buyer_mobile_order_history_screen` · `orders/buyer_mobile_order_tracking_screen` · `product/buyer_mobile_product_details_screen` · `product/buyer_product_details_screen` · `profile/buyer_mobile_account_screen` · `returns/buyer_returns_claims_screen` · `reviews/buyer_product_reviews_screen` · `rewards/buyer_rewards_loyalty_screen` · `wallet/buyer_wallet_bnpl_screen` · `wishlist/buyer_wishlist_gifting_screen`

**Buyer widgets (15):** all four `checkout/*` widgets · six `dashboard/*` widgets · four `product/*` widgets

**Seller (18):** `ads/seller_advertising_campaign_screen` · `ai/seller_ai_copilot_screen` · `analytics/seller_business_advisor_screen` · `b2b/seller_b2b_growth_screen` · `chat/seller_customer_chat_screen` · `dashboard/seller_executive_dashboard_screen` · `health/seller_account_health_screen` · `inventory/seller_inventory_management_screen` · `notifications/seller_notifications_center_screen` · `onboarding/seller_kyc_onboarding_screen` · `orders/seller_order_dispatch_screen` · `pricing/seller_pricing_engine_screen` · `promotions/seller_promotions_campaign_screen` · `returns/seller_returns_disputes_screen` · `reviews/seller_review_management_screen` · `security/seller_security_settings_screen` · `shipping/seller_logistics_governance_screen` · `staff/seller_staff_permissions_screen` · `storefront/seller_store_decoration_screen` · `widgets/dashboard/seller_dashboard_sidebar`

**Admin (4):** `core/permissions/rbac_engine` · `core/theme/admin_theme` · `core/widgets/admin_data_table` · `core/widgets/admin_toast_dialog`

---

## Appendix B — Working session checklist

Before you report a module complete:

- [ ] Every step in the module is done — no partial completion
- [ ] Every acceptance criterion is verified, and you state **how** you verified it
- [ ] Database changes are verified **in the database**, not inferred from the UI
- [ ] `flutter analyze` — issue count did not increase
- [ ] `flutter test` — failure count did not increase
- [ ] No new `catch { debugPrint }` was introduced
- [ ] No new hardcoded price, total, id, or status
- [ ] Committed with the module ID in the message
- [ ] Any blocked or deferred step is named explicitly, with the reason

**If you cannot complete a step, say so.** Do not work around it with a mock, a fallback, or a local cache write. That pattern is the reason this document exists.
