# APNA STORE — PRODUCTION LAUNCH CHECKLIST

## 1. Supabase Infrastructure & Security Hardening
- [x] **RLS Enabled on All Tables:** 100% of tables have row-level security enabled with explicit policies.
- [x] **No Protected Column UPDATES:** Zero client updates permitted on `is_approved`, `balance`, `kyc_status`, `role`.
- [x] **Role-Based RPCs:** Super Admin governance RPCs enforce 12-role RBAC server-side with `SECURITY DEFINER` and `SET search_path = ''`.
- [x] **Voucher Discount Ownership:** Discounts and promo eligibility are calculated exclusively server-side.
- [x] **Safe Migrations:** Sequential timestamp migrations executed through `20260820000000_task9_performance_indexes.sql`.
- [x] **Unnumbered SQL Archived:** Cleaned root and migrations folders; moved combined scripts into `supabase/archive/`.
- [ ] **Daily Backups & PITR:** Enable Point-in-Time Recovery (PITR) in Supabase Dashboard (Database -> Backups).
- [ ] **First Super Admin Bootstrap:** Run `INSERT INTO public.user_roles (user_id, role) VALUES ('<SUPER_ADMIN_AUTH_UID>', 'owner');` via Supabase SQL Editor.
- [ ] **Required Database Extensions (`pg_cron`, `pg_net`):**
  Ensure extensions are enabled in Supabase Dashboard:
  1. Open Supabase Dashboard -> **Database** -> **Extensions**.
  2. Search for `pg_cron` and click toggle to **Enable** (installs cron into `cron` schema).
  3. Search for `pg_net` and click toggle to **Enable**.
  Or run via Supabase SQL Editor (requires superuser/postgres role):
  ```sql
  CREATE EXTENSION IF NOT EXISTS pg_cron;
  CREATE EXTENSION IF NOT EXISTS pg_net;
  ```
- [ ] **Automated Escrow Maturity Schedule (`pg_cron`):**
  Schedule hourly execution of `release_mature_held_seller_earnings()` to release matured 7-day seller earnings from escrow into available balances:
  ```sql
  SELECT cron.schedule(
      'release-mature-held-earnings-hourly',
      '0 * * * *',
      $$SELECT public.release_mature_held_seller_earnings()$$
  );
  ```
  **Verification Query:**
  ```sql
  SELECT jobid, jobname, schedule, active FROM cron.job WHERE jobname = 'release-mature-held-earnings-hourly';
  ```

## 2. Client Application Hardening
- [x] **Zero Secrets in Client:** No API keys, JWT secrets, or cloud tokens hardcoded in Flutter source code (`test/task2_zero_secrets_audit_test.dart` passes).
- [x] **Interim Payment Safety Guard:** `onlinePaymentsEnabled = false`. Only Cash on Delivery (COD) active for order placement. JazzCash, Easypaisa, and Card marked with "Coming Soon" chip.
- [x] **Zero Mock Data:** Purged mock stores, fake vouchers, and static GMV calculations. Real data wired to Supabase database and RPCs.
- [x] **File Modularization:** Decomposed large monolithic screens (`buyer_dashboard.dart`, etc.) into maintainable widget parts.
- [x] **Security Headers & CSP:** `vercel.json` configured with strict `Content-Security-Policy`, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`.
- [x] **SEO & Web Manifest:** Configured OpenGraph meta tags, responsive viewport, `web/manifest.json`, and `web/robots.txt`.

## 3. Rollback & Disaster Recovery SOP
1. In the event of an operational anomaly, revert to the previous Git commit tag.
2. If database rollback is needed, run `docs/ROLLBACK_PLAN.md` instructions against the active branch.
3. To disable checkout during emergency maintenance, execute `UPDATE platform_config SET maintenance_mode = true`.
