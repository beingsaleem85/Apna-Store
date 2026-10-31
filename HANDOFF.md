# APNA STORE — PROJECT HANDOFF & MASTER MEMORY (HANDOFF.md)

> **Document Purpose**: This file serves as the permanent persistent memory and context handoff for **Apna Store**. If the conversation context is reset, or if this project is opened in a new session or on another computer, reading this document provides a complete, 100% accurate picture of what has been accomplished, the architecture, and next steps.

---

## 1. Executive Summary & Current Health

- **Project Name:** Apna Store (Multi-Vendor E-Commerce Marketplace)
- **Tech Stack:** Flutter 3.44 / Dart 3.12 · Supabase (PostgreSQL 15+ + GoTrue + Storage) · Provider State Management
- **Repository Location:** `D:\apna store`
- **Current Health Status (Verified):**
  - **Automated Tests:** `302 / 302 PASSED (100%)` across all 15 test suites in `test/`.
  - **Static Analysis:** `0 errors, 0 warnings` via `flutter analyze`.
  - **Code Hygiene:** Cleaned of all temporary cache files, `.docx`, `.iml`, `node_modules/`, and scratch scripts.
  - **Security & RLS:** 100% server-authoritative with column-level `REVOKE` and `SECURITY DEFINER` RPCs.

---

## 2. Complete Phase & Module Status (Phases A – E, M1 – M29)

Every module from the master prompt (`IMPLEMENTATION_PROMPT.md`) has been fully remediated, implemented, and verified:

### Phase A: Stop the Bleeding (M1 – M7) — `100% COMPLETE`
- **M1:** Lazy Supabase initialization across all 10 core services; constructor I/O eliminated; recovered test suite.
- **M2:** Authentication & authorization secured: deleted mock auto-approval branches, default-deny routing in `AppRouter`, removed mutable `activeDevRole`, bound role checks to `user_roles`.
- **M3:** Honest checkout: eliminated hardcoded totals (3,150 PKR), rethrowing mapped server failures, cart preserved on failures.
- **M4:** Removed fake payment gateway (`buyer_payment_gateway_screen.dart`), deleted plain-text card collecting fields and fake OTP (`849201`).
- **M5:** Removed silent `catch { debugPrint }` blocks across `AppStateProvider`; all database failures surface to UI with retry actions.
- **M6:** Cleaned fabricated pricing, phantom coupons (`EID2026`), and seeded mock stores (`chulbul`).
- **M7:** Background build poller in `DevVersionBanner` disabled in release builds.
- *Report:* `PHASE_A_REPORT.md`

### Phase B: Core Marketplace Real (M8 – M13) — `100% COMPLETE`
- **M8:** Real buyer and seller identity tied to GoTrue; role authority unified in `public.user_roles`.
- **M9:** Real catalog DTOs matching exact database column privileges; `approval_status` defaulted to `'Pending'`.
- **M10:** Database-backed `addresses` and atomic order quoting/pricing.
- **M11:** Real search, category filtering, and sorting over active approved listings.
- **M12:** Seller fulfillment lifecycle wired to `seller_update_fulfillment_status`; order cancellation with stock restoration.
- **M13:** Real reviews with verified-purchase enforcement and server-side rating aggregation.
- *Report:* `PHASE_B_REPORT.md`

### Phase C: Seller & Admin Operations (M14 – M17) — `100% COMPLETE`
- **M14:** Admin governance via server RPCs (`admin_review_seller_store`, `admin_review_product`), preventing seller self-approvals; deleted duplicate legacy admin dashboard.
- **M15:** Server-enforced 12-role RBAC (`superAdmin`, `financeAdmin`, `catalogManager`, etc.) with `AdminAuthGuard.guardRoute` and fail-closed security.
- **M16:** Real financial payouts (`seller_request_payout`, `admin_process_payout`), ledger arbitration, and responsive wallet screen (`seller_wallet_payout_screen.dart`).
- **M17:** Category tree and `brands` table governance.
- *Report:* `PHASE_C_REPORT.md`

### Phase D: UX, Responsiveness, Performance & Cleanup (M18 – M22) — `100% COMPLETE`
- **M18:** Single responsive mobile strategy: deleted 11 duplicate unreachable `buyer_mobile_*` screens; applied `AppBreakpoints.getResponsiveDialogWidth(context)` to modal dialogs down to 320px viewports.
- **M19:** Created `SafeNetworkImage` for graceful fallback handling; wired interactive `AppFooter` links, modals, and legal policies; enforced KYC policy validation before submission.
- **M20 & M21:** Deleted dead models/repositories (`core/models/product.dart`, `order_repository.dart`, `seller_repository.dart`, `admin_data_table.dart`); cleared analyzer warnings.
- **M22:** Test suite extended with `test/phase_16_responsiveness_cleanup_test.dart`.
- *Report:* `PHASE_D_REPORT.md`

### Phase E: Growth (M23 – M29) — `100% COMPLETE`
- **M23:** Multi-gateway payment support: extended `create_atomic_order` to process Cash on Delivery, JazzCash, Easypaisa, and Debit/Credit Card.
- **M24:** Product variations on PDP: interactive variation choice chips (Sizes, Colors, SKUs), dynamic price recalculations, and real `additionalImages`.
- **M25:** Brands & faceted catalog filtering.
- **M26:** Real order tracking timeline via `get_order_tracking_events(order_id)` RPC.
- **M27:** Dynamic merchandising & flash sales via `get_flash_sale_products` RPC.
- **M28:** Database-backed wishlist with reactive app bar badge count, persistence, and one-tap "Move to Cart" action.
- **M29:** Verified feature flags and added `test/phase_17_growth_features_test.dart`.
- *Report:* `PHASE_E_REPORT.md`

---

## 3. Non-Negotiable Ground Rules & Architectural Guardrails

When continuing development or adding features, ALWAYS strictly preserve these rules:

1. **Database Security Model (R1):** Never add `GRANT UPDATE` on protected columns (`is_approved`, `kyc_status`, `commission_rate`, `balance`, `pending_payout`, `approval_status`, `status`). All modifications to these columns MUST go through `SECURITY DEFINER` RPCs.
2. **No Error Swallowing (R2):** Never use `catch { debugPrint(...) }` to mutate local cache and fake success. Surface failures to the user.
3. **No Data Fabrication (R3):** Never generate fake client-side order numbers, synthesized totals, or fallback mock users.
4. **Server Owns Money & Status (R4):** Prices, line totals, commission deductions, and stock decrements are computed and stored server-side.
5. **Safe Migrations (R5):** Never rewrite or delete existing numbered migrations in `supabase/migrations/`. Add new numbered migrations sequentially.
6. **Zero Analyzer Warnings (R6):** Always ensure `flutter analyze` passes with 0 errors and 0 warnings.
7. **Clean Routing (R9):** If a screen is deleted, remove its route constant from `AppRoutes`, route case from `AppRouter`, and its imports.

---

## 4. Database Migrations Reference (`supabase/migrations/`)

The following sequential migrations contain the complete database schema:

| File | Purpose |
|---|---|
| `20260810000000_phase_a_stop_the_bleeding.sql` | Strict RLS, column revokes, private profiles, `user_roles` table |
| `20260811000000_phase_b_core_marketplace.sql` | `create_atomic_order` RPC, stock locks, `store_fulfillments`, reviews |
| `20260812000000_phase_b_step_g_reviews_moderation.sql` | Reviews security & moderation RPCs |
| `20260813000000_phase_c_seller_admin_ops.sql` | Admin governance RPCs, 12-role RBAC, `seller_payout_requests` table & RPCs |
| `20260814000000_phase_e_growth_payments_variants.sql` | Multi-payments (JazzCash/Easypaisa/Card), `user_wishlists` table, Flash Sales & Tracking RPCs |

---

## 5. Key Architecture & File Structure

```
D:\apna store\
├── lib\
│   ├── core\
│   │   ├── config\             # AppConfig (environment, supabase URL & anon key validation)
│   │   ├── constants\          # AppBreakpoints, AppColors, AppVersion, FeatureFlags
│   │   ├── controllers\        # CartController, CatalogController, OrdersController, SellerController
│   │   ├── errors\             # Failures & FailureMapper
│   │   ├── models\             # AppProduct, AppAddress, DTOs (order_dto, product_dto, seller_store_dto, etc.)
│   │   ├── routes\             # AppRoutes, AppRouter (default-deny role guard)
│   │   ├── services\           # AppAuthProvider, AppStateProvider, SupabaseServices (Checkout, Orders, Seller, Finance, Reviews)
│   │   └── widgets\            # AppFooter, SafeNetworkImage, ErrorBanner
│   ├── features\
│   │   ├── buyer\              # Buyer storefront, PDP, Cart, Checkout, Orders, Wishlist
│   │   ├── seller\             # Seller dashboard, Catalog, Orders Dispatch, Finance & Wallet Payouts, KYC
│   │   └── super_admin\        # SuperAdmin shell, Seller Governance, Product Moderation, Payout Ledger, RBAC Guard
│   └── main.dart               # Startup entry with StartupFailureApp fallback
├── test\                       # 15 automated test suites (302 passing tests)
├── supabase\
│   └── migrations\             # 5 authoritative PostgreSQL migrations
├── PHASE_A_REPORT.md           # Phase A verification report
├── PHASE_B_REPORT.md           # Phase B verification report
├── PHASE_C_REPORT.md           # Phase C verification report
├── PHASE_D_REPORT.md           # Phase D verification report
├── PHASE_E_REPORT.md           # Phase E verification report
└── HANDOFF.md                  # This master handoff file
```

---

## 6. How to Resume Work & Run Commands

### 1. Run Development Server (Web Port 8080)
```powershell
flutter run -d web-server --web-port=8080 --web-hostname=localhost --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjE3ODk1MjAwLCJleHAiOjE5MzM0NzEyMDB9.mock_anon_key
```

### 2. Verify Codebase & Run Tests
```powershell
# Run the entire automated test suite (all 302 tests must pass)
flutter test

# Run static analysis (must report 0 errors and 0 warnings)
flutter analyze
```

### 3. Apply Migrations to Remote Supabase
When connecting to a live Supabase project:
```powershell
supabase db push
# Or copy and execute SQL files in order from supabase/migrations/ in Supabase SQL Editor
```

### 4. Build & Deploy
```powershell
# Android APK
flutter build apk --release

# Web Build
flutter build web --release
```

---

## 7. Key Application URLs (When Running on Port 8080)

- **Buyer Marketplace (Home):** `http://localhost:8080/`
- **Super Admin Portal:** `http://localhost:8080/#/super-admin/login`
- **Seller Portal:** `http://localhost:8080/#/seller/login`
- **Buyer Account:** `http://localhost:8080/#/buyer/account`
- **Cart & Checkout:** `http://localhost:8080/#/buyer/cart` & `http://localhost:8080/#/buyer/checkout`

---

## 8. Remaining Live / Operational Steps (Production Setup)

1. **Live Supabase DB Push:** Execute migration files on your live cloud Supabase database.
2. **Payment Gateway Credentials:** Configure live API keys/credentials for JazzCash & Easypaisa Merchant Portals in your environment configuration.
3. **SMS & Email Gateway:** Connect Twilio / Telenor SMS API and SMTP server for live OTPs and order confirmation emails.
4. **App Deployment:** Upload built Android App Bundle to Google Play Console and host Web build on Cloudflare / Vercel / Firebase Hosting.

---
*Created and verified for Apna Store master context and memory persistence.*
