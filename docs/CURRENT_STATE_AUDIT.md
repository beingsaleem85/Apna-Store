# APNA STORE — CURRENT STATE AUDIT REPORT

> **Date:** August 5, 2026  
> **Target App:** Apna Store (Multi-Vendor Marketplace)  
> **Audit & Refactor Status:** Phase 4 Static Preparation Complete (Database Schema Consolidation & RLS Alignment)  
> **Environment:** Windows 10 Pro 64-bit (22H2)  

---

## 1. ENVIRONMENT & TOOLING BASELINE

- **Flutter SDK:** `3.44.6` (Channel `stable`, Revision `ee80f08bbf`)
- **Dart SDK:** `3.12.2`
- **DevTools:** `2.57.0`
- **OS Version:** Windows 10 Pro 64-bit (Version 10.0.19045.6466)
- **Available Web Browsers:** Google Chrome `150.0.7871.187`, Microsoft Edge `151.0.4129.59`
- **Tooling Limitations & Environment Constraints:**
  - `git`: Not found in system PATH.
  - `docker`: Not installed / Not in PATH (`docker` command uninstalled).
  - `supabase`: Not installed / Not in PATH (`supabase` CLI command uninstalled).
  - Web & Android debug builds (`flutter build web`, `flutter build apk --debug`) compile successfully.

---

## 2. REVISED PHASE 4 STATIC PREPARATION SUMMARY

### Authoritative Role & Database Schema:
- **Authoritative Migration Script:** [`supabase/migrations/20260805000000_authoritative_schema_and_rls.sql`](file:///c:/Users/X%20COMPUTER/Desktop/apna%20store/supabase/migrations/20260805000000_authoritative_schema_and_rls.sql)
- **Prepared Runtime Security Tests:** [`supabase/tests/phase_4_rls_security_test.sql`](file:///c:/Users/X%20COMPUTER/Desktop/apna%20store/supabase/tests/phase_4_rls_security_test.sql) (30 pgTAP test assertions prepared; marked PREPARED / UNEXECUTED).
- **Authoritative Role Model:** Created `app_role` ENUM (`buyer`, `seller`, `admin`, `super_admin`, `owner`) and protected `user_roles` table.
- **Server-Controlled Trigger:** `handle_new_user()` trigger on `auth.users` ALWAYS assigns default `'buyer'` role. Client signup metadata (`raw_user_meta_data->>'role'`) is strictly ignored.
- **SECURITY DEFINER Functions (`SET search_path = ''`):** Created `get_current_user_role()`, `has_role()`, `is_admin()`, `owns_seller_store()`, `assign_user_role()`, `admin_review_seller_store()`, `admin_review_kyc_document()`, and `admin_review_product()`. All specify `SET search_path = ''` and have `PUBLIC, anon` execution revoked.
- **Private Profiles & Public View:** `profiles` table RLS restricts SELECT to row owners (`auth.uid() = id`) and admins. Public marketplace display is handled via [`public_profile_view`](file:///c:/Users/X%20COMPUTER/Desktop/apna%20store/supabase/migrations/20260805000000_authoritative_schema_and_rls.sql#L56-L59) (`WITH (security_invoker = true)`).
- **Canonical Ownership Columns:** `seller_stores` uses `owner_id`, `products` uses `seller_store_id`, `seller_kyc_documents` uses `seller_store_id` + `submitted_by`. Duplicate writable ownership columns removed. DTOs updated.
- **Column-Level Privilege Protection:** Explicit `REVOKE UPDATE` on `seller_stores`, `products`, `seller_kyc_documents`, and `buyer_orders`, paired with explicit `GRANT UPDATE (...)` on safe fields only.
- **Temporary Orders Direction:** `buyer_orders` documented as temporary Phase 3/4 compatibility table with non-negative checks and buyer ownership RLS. Full normalized relational `orders` + `order_items` transition assigned to Phase 8.
- **Static Test Suite:** Updated [`test/phase_4_static_schema_test.dart`](file:///c:/Users/X%20COMPUTER/Desktop/apna%20store/test/phase_4_static_schema_test.dart) verifying SQL file structure, `SET search_path = ''`, RLS enablement, private profiles, `admin_review_product`, column-level grants, and absence of destructive `DROP SCHEMA` / `TRUNCATE` statements.

---

## 3. COMMAND EXECUTION RESULTS & ISSUE COUNTS (REVISED PHASE 4)

| Command | Exit Code | Result | Breakdown / Error Details |
|---|---|---|---|
| `flutter pub get` | `0` | **PASS** | Dependencies resolved cleanly. |
| `flutter analyze` | `1` | **COMPLETED WITH ISSUES (966 total findings)** | **0 Errors**, **102 Warnings** (pre-existing unused variables/imports/fields), **864 Infos/Deprecations**. *Phase 4 introduced 0 new errors or warnings.* |
| `flutter test` | `0` | **PASS** | **48/48 tests passed** (10 static schema tests in `test/phase_4_static_schema_test.dart`, 22 in `phase_3_models_and_services_test.dart`, 14 in `routing_test.dart`, 1 in `buyer_dashboard_test.dart`, 1 in `widget_test.dart`). |
| `flutter build web` | `0` | **PASS** | Web bundle generated in `build/web`. |
| `flutter build apk --debug` | `0` | **PASS** | `app-debug.apk` built successfully at `build/app/outputs/flutter-apk/app-debug.apk`. |
| `supabase db reset --local` | N/A | **UNEXECUTED** | Docker & Supabase CLI uninstalled locally. Local container reset unexecuted. |

---

## 4. TRUTHFUL PHASE 4 RUNTIME STATUS

- **Runtime SQL tests executed:** No (0% / Blocked)
- **Local container reset validated:** No (0% / Blocked)
- **Remote deployment performed:** No (None)

---

## 5. BACKUP & CHECKPOINT DETAILS

- **Baseline Checkpoint Location:** [`c:\Users\X COMPUTER\Desktop\APNA_STORE_PHASE_0_BASELINE_BACKUP_2026-08-05`](file:///c:/Users/X%20COMPUTER/Desktop/APNA_STORE_PHASE_0_BASELINE_BACKUP_2026-08-05)
- **Checkpoint Status:** Verified intact, unchanged, and isolated outside active repository.
