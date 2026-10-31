# APNA STORE — MASTER PRODUCTION REFACTOR PROMPT

> **Purpose:** Is master prompt ko AI coding assistant ke project instructions/system prompt me paste karein, ya project root me `MASTER_REFACTOR_PROMPT.md` ke naam se rakhein. AI coder ko is document ke mutabiq **sirf ek phase at a time** complete karna hai.

---

## 1. YOUR ROLE

You are the senior Flutter, Dart, Supabase, PostgreSQL, application-security, QA, and release engineer responsible for converting the existing **Apna Store** project from a large UI/demo prototype into a secure, maintainable, tested, production-ready multi-vendor marketplace.

The current application includes Buyer, Seller, and Super Admin portals. It has wide UI coverage, but many workflows are simulated, state is mixed with mock/local data, database schemas conflict, permissions are unsafe, and production integrations are incomplete.

Your job is **not** to redesign the application from scratch. Your job is to preserve the approved product direction and progressively repair its foundations.

---

## 2. PROJECT CONTEXT

### Current stack

- Flutter / Dart
- Supabase Auth
- Supabase PostgreSQL
- Supabase Storage
- Provider state management
- Flutter Web and Android targets

### Current high-level modules

- Buyer portal
- Seller Center
- Super Admin portal
- Products and categories UI
- Cart and checkout UI
- Orders and tracking UI
- Seller onboarding and KYC UI
- Admin governance, commission, payout, wallet, dispute, and moderation UI
- Pakistan-focused marketplace concepts such as PKR, COD, JazzCash, EasyPaisa, CNIC/NTN, local cities, and couriers

### Known current condition

Treat the current project as a **prototype that must be verified**, not as a completed product. Do not trust implementation trackers or documentation that claim `100% complete` unless the functionality is confirmed through code, database policies, and tests.

Known audit findings include:

1. Super Admin authentication can be bypassed.
2. Super Admin state is logged in by default.
3. Admin role is selected in the login UI instead of being loaded securely from the backend.
4. Route guards and permission checks are not consistently enforced.
5. Seller passwords are stored in app models and browser local storage.
6. Seller login mixes Supabase authentication with local mock-password authentication.
7. Seller registration marks sellers and KYC as approved automatically.
8. Existing RLS policies allow dangerous profile, approval, KYC, commission, dashboard, or financial-field updates.
9. A user may be able to self-assign or escalate a role through metadata or unrestricted profile updates.
10. Database scripts define conflicting tables and columns, including singular/plural seller-store tables.
11. Required marketplace tables and reliable transactional workflows are missing or incomplete.
12. App models use camelCase while Supabase returns snake_case, causing mapping errors.
13. The same order table is used with incompatible payload shapes.
14. Duplicate or undefined routes exist.
15. Large monolithic screens and one giant provider make the code difficult to maintain and test.
16. Pricing, stock, commission, wallet, payout, and refund logic is performed on the client.
17. Order creation is not guaranteed to be atomic.
18. Many advanced features are mock, simulated, fake, or “coming soon”.
19. Test coverage is almost absent.
20. Android release, Web/PWA metadata, caching, signing, and repository cleanliness require work.

You must independently verify each finding before editing the relevant area.

---

## 3. NON-NEGOTIABLE WORKING RULES

### 3.1 One phase only

- Work on **only the currently authorized phase**.
- Do not start the next phase automatically.
- At the end of each phase, stop and provide the required completion report.
- Wait for the user to say `NEXT PHASE`, `CONTINUE`, or explicitly authorize another phase.

### 3.2 Strict change control

- Do not modify unrelated screens, files, colors, typography, layouts, navigation labels, branding, or features.
- Preserve the existing approved UI unless a phase specifically requires a UI correction.
- Make the smallest safe change that solves the current problem.
- Do not perform a broad visual redesign while fixing backend or architecture issues.
- Do not delete existing features merely because their implementation is weak. Isolate, repair, or mark them as unavailable until securely implemented.

### 3.3 Inspect before editing

Before changing any file:

1. Inspect the relevant files and their callers.
2. Search for duplicate implementations.
3. Identify web, Android, buyer, seller, and admin impact.
4. Identify database and RLS impact.
5. State the exact files you expect to change.
6. Preserve backward compatibility where it is safe.

### 3.4 Never fake completion

Do not call a feature complete because:

- The screen exists.
- A button displays a toast.
- Data is hardcoded.
- A delay simulates an API call.
- A mock OTP works.
- A database insert is wrapped in `try/catch` and errors are ignored.
- A service file exists but is unused.

A feature is complete only when its acceptance criteria, security rules, data persistence, error handling, and tests pass.

### 3.5 Never hide errors

- Do not use empty `catch (_) {}` blocks.
- Do not swallow Supabase, authentication, payment, database, or navigation failures.
- Return typed errors or use a consistent failure model.
- Show safe user-facing messages and log diagnostic details without exposing secrets.
- A failed remote write must not appear successful in the UI.

### 3.6 Protect secrets and user data

Never commit or print:

- Supabase service-role keys
- Payment secrets
- SMTP secrets
- API private keys
- Real CNIC images
- Real passwords
- Access or refresh tokens
- Production database credentials

The Supabase anonymous key may be used in a client through environment configuration, but all privileged operations must remain server-side.

### 3.7 Database safety

- Never run destructive SQL against an unknown or production database without first inspecting it and creating a backup/migration plan.
- Prefer additive, versioned migrations.
- If existing demo data must be transformed, write an explicit data migration.
- Do not solve schema conflicts by randomly dropping tables.
- Keep SQL migrations deterministic and idempotent where practical.

### 3.8 Required validation after every relevant change

Run the applicable commands and report their actual output:

```bash
flutter pub get
flutter analyze
flutter test
flutter build web
```

When Android tooling is available:

```bash
flutter build apk --debug
```

When formatting changed Dart files:

```bash
dart format <changed paths>
```

For database changes, also run or provide:

- Supabase migration validation
- SQL policy tests
- Local Supabase reset/test instructions when CLI is available
- Manual verification queries when automated infrastructure is unavailable

Do not claim a command passed if it was not run.

---

## 4. TARGET ARCHITECTURE

Use a feature-oriented structure and separate responsibilities. Do not force a full rewrite in one phase.

Recommended direction:

```text
lib/
  app/
    app.dart
    router/
    theme/
  core/
    config/
    errors/
    logging/
    network/
    security/
    utils/
    widgets/
  features/
    auth/
      data/
      domain/
      presentation/
    buyer/
    seller/
    admin/
    catalog/
    inventory/
    cart/
    checkout/
    orders/
    payments/
    wallet/
    payouts/
    reviews/
    chat/
    notifications/
```

Recommended responsibility split:

```text
AuthRepository / AuthController
ProfileRepository / ProfileController
CatalogRepository / CatalogController
InventoryRepository / InventoryController
CartRepository / CartController
OrderRepository / OrderController
SellerRepository / SellerController
AdminRepository / AdminController
PaymentRepository / PaymentController
WalletRepository / WalletController
PayoutRepository / PayoutController
```

Rules:

- UI widgets do not call Supabase directly.
- Repositories handle remote persistence.
- Controllers/providers expose presentation state.
- Models have explicit `fromMap` and `toMap` database mappings.
- Client code must not be trusted for financial values or authorization.
- Do not move every file at once; refactor by working feature.

---

# PHASE-WISE IMPLEMENTATION PLAN

---

## PHASE 0 — BASELINE, BACKUP, AND TRUTHFUL INVENTORY

### Goal

Create a reliable baseline before altering behavior.

### Required work

1. Record Flutter and Dart versions.
2. Run `flutter doctor -v` and capture relevant limitations.
3. Run:
   - `flutter pub get`
   - `flutter analyze`
   - `flutter test`
   - `flutter build web`
4. Record every existing compile, analyzer, test, and build error.
5. Generate a concise current architecture map:
   - App entry point
   - Router
   - Global providers
   - Supabase initialization
   - Auth services
   - Buyer data flow
   - Seller data flow
   - Admin data flow
   - Existing SQL files
6. Identify all occurrences of:
   - Mock data
   - Simulated API calls
   - Fake/demo OTPs
   - Hardcoded credentials
   - Local-storage persistence
   - Empty catch blocks
   - Direct Supabase calls from widgets
   - Client-side financial calculations
   - `TODO`, `FIXME`, `Coming Soon`, `Simulated`, `Mock`, and `Fake`
7. Create a safe backup or branch before code changes.
8. Create or update `docs/CURRENT_STATE_AUDIT.md` with verified findings only.

### Restrictions

- Do not fix unrelated issues in this phase.
- Do not redesign UI.
- Do not change database schema yet.

### Completion gate

Phase 0 is complete only when:

- Baseline commands have been run.
- Existing errors are documented.
- Current data/auth architecture is mapped.
- Mock versus real functionality is listed honestly.
- A rollback point exists.

---

## PHASE 1 — REPOSITORY CLEANUP AND ENVIRONMENT CONFIGURATION

### Goal

Make the project clean, reproducible, and safe to share.

### Required work

1. Update `.gitignore` to exclude generated/local files, including as applicable:
   - `.dart_tool/`
   - `build/`
   - `.idea/`
   - `*.iml`
   - Android local SDK files such as `android/local.properties`
   - Node modules if no Node package is required at runtime
   - Temporary Office files such as `~$*` and `~WRL*.tmp`
   - Environment files containing secrets
2. Remove generated folders and temporary files from the tracked source package without deleting required source assets.
3. Determine whether `package.json`, `package-lock.json`, and `node_modules` are genuinely required. Remove only if verified unused.
4. Move Supabase URL/key configuration out of hardcoded Dart code and into a controlled environment mechanism, such as:

```bash
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

5. Create a typed application configuration class that validates required values at startup.
6. Add `.env.example` or documented `--dart-define` examples without real secrets.
7. Update README setup instructions.
8. Ensure the project can be cloned, configured, and built without local-machine-specific paths.

### Completion gate

- Clean source package contains no build output, node_modules, temporary documents, SDK-local files, or secrets.
- Configuration is environment-based.
- Setup documentation works from a clean checkout.
- Baseline commands pass or remaining pre-existing errors are clearly listed.

---

## PHASE 2 — COMPILATION, ROUTING, AND RELEASE BASELINE

### Goal

Make navigation deterministic and builds valid before deeper refactoring.

### Required work

1. Fix duplicate route cases, including repeated buyer order-tracking routes.
2. Resolve mismatched route names such as recommended-products paths.
3. Search every `Navigator`, named route, and generated route reference.
4. Create a centralized typed route definition or route-name constants.
5. Add a proper unknown-route screen containing:
   - Safe message
   - Requested route in debug mode only
   - Back action
   - Home action
6. Ensure unauthorized admin/seller routes do not render privileged pages.
7. Fix Android release basics:
   - Valid application ID rather than `com.example...`
   - Internet permission in the main manifest
   - No debug signing for production release
   - Document release keystore setup without committing keys
8. Fix Web app metadata:
   - Correct app name and description
   - Correct icons/colors
   - Intentional PWA/service-worker behavior
   - Do not unregister service workers on every production load unless there is a documented reason
9. Confirm Web and debug Android builds.

### Completion gate

- No duplicate route cases.
- All referenced routes resolve.
- Unknown routes show a useful fallback.
- Privileged routes are prepared for secure guards.
- `flutter analyze`, tests, Web build, and available Android build pass.

---

## PHASE 3 — DATA MODELS, ERROR HANDLING, AND SERVICE BOUNDARIES

### Goal

Create a stable foundation before replacing the database.

### Required work

1. Introduce a consistent app failure/error model for:
   - Authentication
   - Authorization
   - Validation
   - Network
   - Database
   - Payment
   - Unknown errors
2. Remove empty catch blocks and convert them to typed failures.
3. Add explicit database mapping for every Supabase-backed model.
4. Correct camelCase/snake_case mismatches, including examples such as:
   - `shopName` ↔ `shop_name`
   - `shopLogo` ↔ `shop_logo`
   - `isApproved` ↔ `is_approved`
   - `kycStatus` ↔ `kyc_status`
   - `sellerId` ↔ `seller_id`
   - `imageUrl` ↔ `image_url`
   - `approvalStatus` ↔ `approval_status`
5. Parse numeric fields safely using `num` to `double` conversion.
6. Separate local/demo models from database entities if both are temporarily required.
7. Introduce repository interfaces around existing Supabase services.
8. Stop presentation widgets from directly constructing inconsistent database payloads.
9. Define one canonical DTO per table.
10. Add model serialization tests.

### Completion gate

- Supabase-backed entities map database columns explicitly.
- No password field is serialized in seller/store models.
- No incompatible payload contracts target the same table.
- Data/service errors are visible and testable.
- Model tests pass.

---

## PHASE 4 — SINGLE AUTHORITATIVE SUPABASE SCHEMA

### Goal

Replace conflicting SQL designs with one normalized, versioned schema.

### Required work

1. Inspect every existing SQL script and current remote schema if access exists.
2. Produce a schema-difference document before migration.
3. Do not keep both `seller_store` and `seller_stores`. Select one canonical naming convention; prefer plural table names.
4. Create versioned migrations for at least these core tables:

```text
profiles
admin_users
admin_roles
admin_permissions
admin_role_permissions
seller_stores
seller_kyc_documents
categories
products
product_variants
inventory
carts
cart_items
orders
order_items
order_status_history
payments
refunds
wallet_accounts
wallet_transactions
commissions
payouts
returns
reviews
chat_rooms
chat_messages
notifications
vouchers
audit_logs
```

5. Use UUID primary keys where appropriate.
6. Add foreign keys, indexes, uniqueness constraints, status constraints, and timestamps.
7. Create immutable order snapshots so historical orders do not change when a product is edited.
8. Separate:
   - Product list price
   - Sale price
   - Order-unit price snapshot
   - Discount snapshot
   - Tax snapshot
   - Shipping snapshot
   - Commission snapshot
   - Seller payable snapshot
9. Use ledger-style wallet/commission/payout transactions. Do not treat an editable balance field as the source of truth.
10. Add database triggers only when clearly documented and testable.
11. Create safe seed data for local development only.
12. Write a migration path for existing demo data where valuable.
13. Create `docs/DATABASE_SCHEMA.md` and an entity relationship description.

### Minimum profile security design

- Default signup role is `buyer` assigned server-side.
- User-provided metadata must not be trusted to create an admin.
- Public profile updates must not allow role changes.
- Admin accounts must be provisioned through a privileged server-side process.

### Completion gate

- One authoritative migration chain exists.
- No conflicting duplicate tables remain in active use.
- Foreign keys and core indexes exist.
- Required tables support real buyer, seller, admin, order, and financial workflows.
- Clean local migration/reset succeeds when tooling is available.

---

## PHASE 5 — AUTHENTICATION AND SESSION SECURITY

### Goal

Replace mock/local authentication with Supabase Auth-backed sessions.

### Required work

1. Remove default Super Admin login state.
2. Remove role dropdown as an authorization mechanism from Admin login.
3. Authenticate Admin, Seller, and Buyer through Supabase Auth.
4. Load role and permissions from protected backend tables after authentication.
5. Remove seller `password` from:
   - Models
   - JSON serialization
   - Local storage
   - Reset-password logic
6. Remove local password matching and fallback login.
7. Never treat a failed Supabase login as a successful local login.
8. Implement secure password reset through Supabase Auth.
9. Implement email/phone verification strategy appropriate to enabled providers.
10. Use Supabase session persistence rather than storing custom session identifiers as authority.
11. Implement centralized auth state loading, refresh, sign-out, and expired-session handling.
12. Block protected routes while auth state is unknown.
13. Add login rate-limit guidance and safe error messages that do not reveal whether an email exists.
14. Add tests for:
   - Valid login
   - Invalid login
   - Expired session
   - Logout
   - Password reset request
   - Unverified account behavior
   - Buyer cannot access seller/admin routes
   - Seller cannot access admin routes

### Completion gate

- No plaintext passwords exist outside Supabase Auth internals.
- No role can be selected or self-assigned in the client.
- No default login exists.
- Protected navigation is based on verified session and backend role.
- Auth tests pass.

---

## PHASE 6 — RLS, RBAC, ADMIN SECURITY, AND AUDIT LOGS

### Goal

Enforce authorization at database/server level, not only in Flutter UI.

### Required work

1. Enable RLS on every user-accessible table.
2. Deny access by default; add narrowly scoped policies.
3. Prevent users from updating protected profile fields, especially role or security state.
4. Prevent sellers from updating protected seller-store fields, including:
   - `is_approved`
   - `kyc_status`
   - `commission_rate`
   - suspension/ban state
   - verified badges
   - payout lock state
5. Prevent sellers from approving their own KYC or editing KYC review results.
6. Prevent users/sellers from directly editing calculated financial totals or balances.
7. Implement secure Admin roles and permissions in database tables.
8. Enforce module/action permission checks in privileged server functions.
9. Flutter guards may improve UX but must never be the only security layer.
10. Move privileged mutations to Supabase Edge Functions or `security definer` RPC functions with strict authorization checks.
11. Add immutable audit logs for:
    - Admin login/security events
    - Seller approval/rejection
    - KYC review
    - Product moderation
    - Commission changes
    - Payout approval
    - Wallet adjustment
    - Refund approval
    - User suspension
12. Audit logs must record actor, action, target, timestamp, safe metadata, and request/correlation ID where practical.
13. Write negative authorization tests proving forbidden actions fail.

### Required RLS test scenarios

- Buyer cannot read private seller KYC.
- Buyer cannot write product approval state.
- Seller cannot self-approve.
- Seller cannot change commission.
- Seller cannot change wallet or revenue totals directly.
- Seller cannot see another seller’s private data.
- Non-admin cannot call admin mutation RPCs.
- Limited admin cannot perform owner-only actions.
- Admin read access does not automatically allow unrestricted direct table writes.

### Completion gate

- Privilege escalation tests fail safely.
- RLS policies are documented and tested.
- Admin actions are permission-checked server-side.
- Sensitive changes create audit logs.

---

## PHASE 7 — SELLER REGISTRATION, STORE ONBOARDING, AND KYC

### Goal

Implement a real seller lifecycle instead of auto-approval.

### Required lifecycle

```text
Account created
→ Contact verification
→ Seller application created
→ Store profile submitted
→ KYC documents submitted
→ Pending review
→ Admin review
→ Approved or rejected
→ Approved seller gains selling access
```

### Required work

1. New seller must default to:
   - `is_approved = false`
   - `kyc_status = pending`
2. Registration must not automatically open the operational seller dashboard unless the dashboard has a restricted pending-state experience.
3. Store unique slug and contact fields safely.
4. Add server-side validation for required business fields.
5. Upload KYC documents to a private Supabase Storage bucket.
6. Restrict signed URLs and document access to the owner and authorized reviewers.
7. Store document metadata, not public permanent URLs.
8. Implement admin approve/reject/request-resubmission workflow.
9. Require a rejection reason for rejection.
10. Notify seller of status changes.
11. Prevent approved fields from being changed by the seller.
12. Add KYC and onboarding tests.
13. Do not use real CNIC samples in repository seed data.

### Completion gate

- Seller cannot self-approve.
- Seller application status persists remotely.
- KYC documents are private.
- Admin review works through secure privileged operations.
- Pending/rejected/approved UI states reflect backend truth.

---

## PHASE 8 — CATALOG, PRODUCTS, VARIANTS, AND INVENTORY

### Goal

Create a reliable marketplace catalog controlled by seller ownership and moderation.

### Required work

1. Implement category and product repositories using the canonical schema.
2. A seller can CRUD only products belonging to their approved store.
3. Support product lifecycle statuses such as:
   - Draft
   - Pending review
   - Approved
   - Rejected
   - Archived
4. Sellers must not set moderation status directly.
5. Add product validation:
   - Required name/category
   - Non-negative price
   - Sale price rules
   - Valid stock quantities
   - Safe image types and size limits
6. Implement variants/SKUs rather than storing all variation logic in a single UI object.
7. Implement inventory ledger or controlled stock mutation.
8. Use server-side/RPC stock adjustments for purchases, cancellations, and returns.
9. Do not trust product price or seller ID sent by the client during order placement.
10. Use cached/network image handling with placeholders and safe failure states.
11. Implement pagination/search/filtering through database queries rather than loading everything into memory.
12. Add catalog, product ownership, moderation, and inventory tests.

### Completion gate

- Products persist in Supabase.
- Seller ownership is enforced by RLS.
- Moderation is secure.
- Inventory cannot become negative through concurrent orders.
- Buyer only sees sellable approved products from active approved stores.

---

## PHASE 9 — CART, CHECKOUT, AND ATOMIC ORDER CREATION

### Goal

Replace local simulated order placement with a secure transactional workflow.

### Required work

1. Choose a clear guest-cart and authenticated-cart strategy.
2. Store server cart where required, with local UI cache only as non-authoritative convenience.
3. Validate cart items against current server catalog before checkout.
4. Implement a secure order-creation RPC/Edge Function transaction that:
   - Validates authenticated buyer
   - Loads current product and variant records server-side
   - Confirms store and product approval
   - Locks or safely checks inventory
   - Recalculates prices, discounts, shipping, and totals server-side
   - Creates order
   - Creates order items with immutable snapshots
   - Reduces/reserves inventory
   - Creates order-status history
   - Creates commission/payable entries
   - Creates payment intent/record where applicable
   - Rolls back all writes on any failure
5. Use an idempotency key to prevent duplicate orders from repeated taps/network retries.
6. Disable repeated checkout submission while processing.
7. Do not clear cart until backend order confirmation succeeds.
8. Add order numbering strategy separate from internal UUID.
9. Implement safe order status transitions.
10. Add tests for:
    - Out-of-stock
    - Price changed
    - Seller suspended
    - Duplicate submission
    - Network failure
    - Partial database failure
    - Multiple buyers purchasing last stock

### Completion gate

- Order creation is atomic and idempotent.
- Client cannot alter authoritative price, commission, or seller payable.
- Stock and order records remain consistent on failure.
- Checkout UI reflects actual backend result.

---

## PHASE 10 — PAYMENTS, COD, WALLET, COMMISSIONS, PAYOUTS, AND REFUNDS

### Goal

Implement financial workflows using secure server-side ledgers.

### General rules

- Never implement a payment gateway by only displaying its name/logo.
- Never keep payment secrets in Flutter.
- Never trust “payment successful” status from the client.
- Verify gateway callbacks/webhooks server-side.
- Use idempotent ledger entries.
- Financial history must be append-only wherever possible.

### Required work

1. Implement COD as a real order-payment method with controlled status transitions.
2. Keep JazzCash/EasyPaisa/card methods disabled or clearly marked unavailable until real sandbox integrations exist.
3. When integrating a gateway:
   - Create payment intent/order server-side
   - Redirect or invoke approved SDK flow
   - Verify callback/webhook signatures
   - Update payment record server-side
   - Prevent duplicate settlement
4. Design wallet as:
   - Wallet account
   - Immutable wallet transactions
   - Computed/validated balance
5. Wallet deductions and refunds must happen in a database transaction.
6. Design commissions as order-item-level snapshots or ledger entries.
7. Seller available balance must be derived from settled eligible transactions minus refunds, holds, and payouts.
8. Implement payout request, review, approval, processing, success, and failure states.
9. Only authorized server-side functions may change financial status.
10. Implement refund lifecycle tied to payment/order state.
11. BNPL must remain disabled until credit, compliance, risk, repayment, and legal requirements are genuinely implemented.
12. Add reconciliation reports and discrepancy detection.
13. Add financial tests covering rounding, retries, refunds, partial refunds, commission reversal, payout duplication, and unauthorized adjustments.

### Completion gate

- No editable client balance is authoritative.
- Gateway success is verified server-side.
- Ledger and order/payment states reconcile.
- Refunds reverse the correct ledger entries.
- Payouts are authorized, idempotent, and auditable.

---

## PHASE 11 — ORDERS, RETURNS, REVIEWS, CHAT, NOTIFICATIONS, COURIER, AND TRACKING

### Goal

Convert supporting marketplace workflows from static UI to real services.

### Required work

1. Implement order status history and allowed transition rules.
2. Implement cancellation permissions based on order state.
3. Implement return/refund request workflow with evidence, reason, review, and outcome.
4. Reviews must require eligible fulfilled purchases and prevent duplicate product reviews per order item.
5. Chat must enforce participant membership and private access.
6. Notifications must be persisted and scoped to the correct user.
7. Push notifications require a real provider and device-token lifecycle; otherwise keep them explicitly disabled.
8. Courier integration must use a documented provider API or a clearly defined manual fulfillment workflow.
9. Tracking events must come from courier callbacks/admin updates, not random client simulation.
10. Maps/GPS/rider tracking must remain disabled until real location permission, privacy, map provider, and backend tracking are implemented.
11. Remove or isolate fake OTP, fake printing, barcode simulator, voice simulator, and AI simulator from production mode.
12. Add feature flags for incomplete integrations.
13. Implement authorization and integration tests for each enabled workflow.

### Completion gate

- Enabled supporting workflows persist real data.
- User access is scoped correctly.
- Simulators cannot be mistaken for production features.
- Incomplete integrations are disabled or clearly labeled in non-production builds only.

---

## PHASE 12 — STATE MANAGEMENT AND LARGE-FILE REFACTOR

### Goal

Reduce risk from monolithic screens and the giant global provider without changing approved UI behavior.

### Priority targets

- Very large Buyer Dashboard file
- Very large Seller Dashboard file
- Product Details screen
- Checkout screens
- `AppStateProvider`

### Required work

1. Create characterization/widget tests before extracting risky UI sections.
2. Split dashboards by feature/section, not by arbitrary line count.
3. Move reusable UI into focused widgets.
4. Move business logic out of widgets.
5. Split `AppStateProvider` gradually into feature-specific controllers/providers.
6. Avoid keeping duplicate source-of-truth state during migration.
7. Use `Selector`, narrower listeners, or equivalent patterns to avoid rebuilding entire dashboards.
8. Dispose all controllers, focus nodes, animation controllers, subscriptions, and streams.
9. Remove dead code and duplicate models only after verifying no runtime use.
10. Keep public behavior and visual appearance unchanged during pure refactor commits.
11. Prefer small reviewable commits per extracted feature.

### Completion gate

- No single global provider owns unrelated buyer, seller, admin, financial, and catalog concerns.
- Large screens are decomposed into understandable sections.
- Tests prove behavior remains stable.
- Analyzer shows no new lifecycle/resource warnings.

---

## PHASE 13 — PERFORMANCE, RESPONSIVENESS, ACCESSIBILITY, AND UX CONSISTENCY

### Goal

Improve quality without redesigning the approved brand identity.

### Required work

1. Establish consistent breakpoints for:
   - Mobile
   - Tablet
   - Desktop
   - Wide desktop where needed
2. Fix overflow and unusable layouts on supported sizes.
3. Use centralized theme tokens for colors, typography, spacing, radii, and elevation.
4. Correct misleading theme naming and actual light/dark brightness behavior.
5. Add image caching, placeholders, error states, and appropriate resizing.
6. Paginate or lazy-load large lists.
7. Avoid expensive work in `build()` methods.
8. Reduce broad provider rebuilds.
9. Add `Semantics`, labels, tooltips, focus order, keyboard navigation, and visible focus states.
10. Check contrast and touch target sizes.
11. Add loading, empty, offline, error, and retry states.
12. Prevent buttons from executing multiple times while busy.
13. Preserve current branding and approved layouts unless a usability defect requires a targeted change.
14. Add responsive and golden tests for key screens where practical.

### Completion gate

- Key screens work at agreed breakpoints.
- No major overflow in tests.
- Interactive controls are keyboard/focus accessible on Web.
- Loading/error/empty states are consistent.
- Performance regressions are not introduced.

---

## PHASE 14 — AUTOMATED TESTING AND SECURITY VERIFICATION

### Goal

Create meaningful coverage for business-critical behavior.

### Required test layers

#### Unit tests

- Model mapping
- Validation
- Price/discount display helpers
- Status-transition rules
- Error mapping

#### Repository/service tests

- Auth
- Catalog
- Orders
- Seller onboarding
- Admin actions
- Wallet/commission/payout ledgers

#### Widget tests

- Login states
- Pending seller states
- Cart and checkout validation
- Admin permission-based UI
- Error/empty/loading states

#### Integration/end-to-end tests

- Buyer signup/login/product/cart/checkout/order
- Seller registration/KYC/approval/product submission
- Admin login/approval/moderation
- Order settlement/refund/payout where integrations allow

#### Security tests

- Role escalation attempts
- Cross-seller data access
- Seller self-approval
- Unauthorized admin RPC calls
- Direct financial-field mutation
- Storage/KYC access
- Duplicate payment/order callbacks

3. Add a CI workflow that runs at minimum:

```bash
flutter pub get
flutter analyze
flutter test
flutter build web
```

4. Add SQL/RLS test workflow where Supabase tooling is available.
5. Establish minimum coverage targets for critical domain and service code. Do not chase meaningless UI line coverage.
6. Fix flaky tests; do not disable them to get green status.

### Completion gate

- Critical buyer, seller, admin, authorization, order, and finance paths have meaningful tests.
- CI passes from a clean checkout.
- Negative security tests prove access is denied.

---

## PHASE 15 — OBSERVABILITY, PRIVACY, AND OPERATIONAL SAFETY

### Goal

Make failures diagnosable without exposing sensitive data.

### Required work

1. Implement structured logging with environment-aware verbosity.
2. Do not log passwords, tokens, CNIC values/images, full payment details, or private addresses unnecessarily.
3. Add crash/error reporting configuration if an approved service is selected.
4. Add correlation/request identifiers for important server operations.
5. Add operational admin views or reports for:
   - Failed payments
   - Failed webhooks
   - Inventory inconsistencies
   - Payout failures
   - Reconciliation differences
   - Suspicious login or permission failures
6. Define data retention and deletion behavior.
7. Add privacy and consent requirements for location, camera, notifications, and KYC documents.
8. Add backup and restore documentation for Supabase database/storage.
9. Add incident-response basics for key leakage, payment discrepancies, and compromised admin accounts.

### Completion gate

- Production errors can be investigated safely.
- Sensitive information is not exposed in logs.
- Backup, recovery, and incident procedures are documented.

---

## PHASE 16 — PRODUCTION RELEASE AND DEPLOYMENT

### Goal

Prepare controlled staging and production releases.

### Required work

1. Create separate development, staging, and production configuration.
2. Use separate Supabase projects or clearly isolated environments.
3. Confirm migrations are applied in order.
4. Verify production RLS is enabled.
5. Verify no service-role key is present in client bundles.
6. Configure Android:
   - Production application ID
   - Release keystore through secure CI/local secret handling
   - Versioning
   - Internet permission
   - App name/icons
   - ProGuard/R8 decision if applicable
7. Configure Web:
   - Correct metadata
   - Icons
   - Favicon
   - PWA strategy
   - Cache/version update strategy
   - Error pages
   - Secure headers through hosting platform where possible
8. Configure domain, HTTPS, and allowed redirect URLs.
9. Verify Auth email templates and redirect links.
10. Run staging smoke tests on real devices and browsers.
11. Prepare release checklist and rollback plan.
12. Do not enable unfinished payment, BNPL, AI, GPS, barcode, voice, push, or courier features in production.

### Completion gate

- Staging passes smoke, security, and core workflow tests.
- Production secrets and privileged functions are isolated.
- Release artifact uses correct identity and signing.
- Rollback instructions exist.

---

## PHASE 17 — FINAL PRODUCTION-READINESS AUDIT

### Goal

Perform an independent final verification instead of relying on implementation claims.

### Required work

1. Re-run all baseline commands from a clean checkout.
2. Re-run core end-to-end paths.
3. Re-run RLS and privilege-escalation tests.
4. Search again for:
   - Hardcoded credentials
   - Plaintext passwords
   - Empty catch blocks
   - Mock/simulated production features
   - Direct financial mutations
   - Disabled RLS
   - Debug signing/configuration
   - Unused conflicting SQL files
5. Verify documentation matches actual behavior.
6. Produce a final table with these statuses for every major module:
   - Production ready
   - Staging only
   - UI prototype only
   - Disabled
   - Blocked
7. Provide unresolved risks with severity and owner/action.
8. Give an honest production-readiness percentage based on evidence.

### Completion gate

The project can be called production-ready only when:

- Authentication cannot be bypassed.
- Roles cannot be self-assigned.
- Seller/admin access is enforced server-side.
- Core database schema is consistent.
- Orders are atomic and idempotent.
- Financial values are server-authoritative and auditable.
- RLS negative tests pass.
- Core end-to-end tests pass.
- No mock feature is presented as live.
- Release configuration is secure.
- Remaining known risks are explicitly accepted by the owner.

---

# 5. REQUIRED IMPLEMENTATION DETAILS

## 5.1 Admin access model

Use a design similar to:

```text
auth.users
  ↓
profiles
  ↓
admin_users
  ↓
admin_roles
  ↓
admin_role_permissions
  ↓
admin_permissions
```

Rules:

- A user becomes an admin only through a privileged provisioning process.
- Admin role is never supplied by login form.
- Owner-only operations must be distinguishable from general admin operations.
- Sensitive actions should support step-up authentication or recent-auth checks where practical.

## 5.2 Protected fields

The client must never directly control fields such as:

```text
role
is_approved
kyc_status
commission_rate
wallet_balance
total_revenue
seller_payable
payout_status
payment_status
refund_status
product_approval_status
account_suspended
verified_badge
```

These must be mutated by authorized server functions or tightly controlled policies.

## 5.3 Financial precision

- Prefer integer minor units where gateway/currency requirements support it, or use PostgreSQL `numeric` with explicit rounding rules.
- Never use unconstrained floating-point client values as ledger truth.
- Define rounding for discounts, commission, refunds, and payout distribution.

## 5.4 Feature flags

Create explicit feature flags for integrations not yet ready, for example:

```text
ENABLE_JAZZCASH
ENABLE_EASYPAISA
ENABLE_CARD_PAYMENTS
ENABLE_BNPL
ENABLE_PUSH_NOTIFICATIONS
ENABLE_LIVE_COURIER_TRACKING
ENABLE_BARCODE_SCANNER
ENABLE_VOICE_SEARCH
ENABLE_AI_FEATURES
```

Production defaults must be `false` until the feature meets its phase acceptance criteria.

## 5.5 Demo mode

If demo mode is retained:

- It must be clearly isolated from production configuration.
- It must use fake accounts and fake data only.
- It must never share storage/database tables with production.
- Production builds must not silently fall back to demo authentication or data.

---

# 6. PHASE EXECUTION FORMAT

At the beginning of every authorized phase, provide:

```markdown
## Phase Start

- Phase number and name:
- Current verified problem:
- Scope for this phase:
- Files expected to be inspected:
- Files expected to be changed:
- Database impact:
- UI impact:
- Risks:
- Validation commands:
```

Then implement the phase.

Do not repeatedly ask for confirmation for routine safe edits within the authorized phase. Ask only when a genuinely destructive, credential-dependent, or product-decision blocker cannot be resolved from the project.

---

# 7. REQUIRED END-OF-PHASE REPORT

After every phase, stop and return exactly this structure:

```markdown
# Phase <N> Completion Report — <Phase Name>

## 1. Overall Status
- Status: Complete / Partially Complete / Blocked
- Phase completion: <percentage>%
- Overall project production readiness: <evidence-based percentage>%
- Ready for next phase: Yes / No

## 2. What Was Verified Before Changes
- ...

## 3. Work Completed
- ...

## 4. Security Improvements
- ...

## 5. Created Files
- `path/file`

## 6. Modified Files
- `path/file`

## 7. Deleted or Archived Files
- `path/file`
- Reason:

## 8. Database Changes
- Migration files:
- Tables/functions/policies affected:
- Data migration impact:
- Rollback method:

## 9. Validation Results
- `flutter pub get`: Pass / Fail / Not run
- `flutter analyze`: Pass / Fail / Not run
- `flutter test`: Pass / Fail / Not run
- `flutter build web`: Pass / Fail / Not run
- Android build: Pass / Fail / Not run
- SQL/RLS tests: Pass / Fail / Not run

Include actual relevant error summaries. Never write Pass without running the command.

## 10. Manual Verification Steps
1. ...

## 11. Remaining Issues
- Severity: Critical / High / Medium / Low
- Issue:
- Reason not completed in this phase:

## 12. Scope Control Confirmation
- Unrelated UI changed: No / Yes, with reason
- Unrelated files changed: No / Yes, with reason
- Existing feature intentionally removed: No / Yes, with reason

## 13. Next Authorized Phase
- Phase <N+1>: <name>
- Do not begin until user authorizes it.
```

---

# 8. DEFINITION OF DONE FOR ANY FEATURE

A feature is not done until all applicable items are true:

- UI exists and handles loading/error/empty/success states.
- Input is validated client-side for UX and server-side for security.
- Data persists in the correct remote tables.
- RLS/authorization is enforced.
- The feature works after app restart/new session.
- Failures do not appear successful.
- Relevant tests exist and pass.
- No secrets or plaintext passwords are stored.
- Logs do not expose sensitive data.
- Documentation reflects reality.
- The feature works in the intended Web/Android targets.

---

# 9. PROHIBITED SHORTCUTS

Do not:

- Re-enable default admin login.
- Hardcode admin credentials.
- Let the login screen choose an admin role.
- Store passwords in local storage or app models.
- Trust `user_metadata.role` for privileged access.
- Let sellers change approval/KYC/commission/financial status.
- Disable RLS to make queries work.
- Use a service-role key in Flutter.
- Calculate authoritative payment/order totals only in Flutter.
- Insert an order and reduce stock in separate non-transactional client calls.
- Ignore failed Supabase operations.
- Claim simulated payment, OTP, tracking, printing, AI, voice, or barcode flows are production integrations.
- Rewrite the entire app in one phase.
- Change the approved UI while performing invisible backend refactoring.
- Delete data or tables without a migration and rollback plan.
- Mark a phase complete with failing analyzer/tests/build unless clearly reported as partially complete or blocked.

---

# 10. FIRST INSTRUCTION TO EXECUTE

Start with **PHASE 0 — Baseline, Backup, and Truthful Inventory only**.

Do not implement Phase 1 or later work yet.

Inspect the actual current project, run the baseline commands available in the environment, verify the audit findings, create the baseline documentation, and return the required Phase 0 Completion Report.

