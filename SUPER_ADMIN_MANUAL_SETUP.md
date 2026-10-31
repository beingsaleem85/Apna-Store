# SUPER ADMIN MANUAL SETUP & DEPLOYMENT GUIDE

This document centralizes all manual steps required in Supabase, Firebase, or External Dashboards for the Super Admin System.

---

## 🛠️ Required Manual Dashboard Tasks

### Task 1: Execute Migration Scripts in Supabase SQL Editor
* **Target Service**: Supabase Dashboard -> SQL Editor
* **Files**:
  - `supabase/migrations/20260720000000_super_admin_foundation.sql`
* **Verification**: Run `SELECT * FROM public.admin_audit_logs LIMIT 1;`

### Task 2: Create Storage Buckets
* **Target Service**: Supabase Dashboard -> Storage
* **Buckets**:
  - `admin-cms-assets` (Public)
  - `dispute-evidence-docs` (Private, RLS Protected)

### Task 3: Set Environment Variables
* **Target**: `.env` / Production Build Config
* **Keys**:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `ENABLE_SUPER_ADMIN_MOCK=false`
