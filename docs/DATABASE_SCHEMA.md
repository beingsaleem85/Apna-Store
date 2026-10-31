# APNA STORE — AUTHORITATIVE DATABASE SCHEMA

> **Phase:** 4 — Database Schema Consolidation, Safe SQL Migrations, and RLS Alignment  
> **Migration File:** [`supabase/migrations/20260805000000_authoritative_schema_and_rls.sql`](file:///c:/Users/X%20COMPUTER/Desktop/apna%20store/supabase/migrations/20260805000000_authoritative_schema_and_rls.sql)  
> **Runtime Status:** Implementation Prepared / Local Container Execution Blocked (Docker/Supabase CLI uninstalled).  

---

## 1. ENUMS & ROLES

### `public.app_role`
- **Values:** `'buyer'`, `'seller'`, `'admin'`, `'super_admin'`, `'owner'`
- **Default for New Users:** `'buyer'` (Enforced server-side via `handle_new_user()` trigger).

---

## 2. CANONICAL TABLES & VIEWS

### 2.1 `public.user_roles`
- **Purpose:** Server-controlled role source of truth.
- **Columns:**
  - `id`: `UUID PRIMARY KEY DEFAULT gen_random_uuid()`
  - `user_id`: `UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`
  - `role`: `public.app_role NOT NULL DEFAULT 'buyer'`
  - `granted_at`: `TIMESTAMPTZ NOT NULL DEFAULT NOW()`
  - `granted_by`: `UUID REFERENCES auth.users(id)`
- **Constraints:** `UNIQUE (user_id, role)`

### 2.2 `public.profiles`
- **Purpose:** Private user profile information.
- **Columns:**
  - `id`: `UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE`
  - `full_name`: `TEXT NOT NULL DEFAULT ''`
  - `email`: `TEXT NOT NULL DEFAULT ''`
  - `mobile_number`: `TEXT DEFAULT ''`
  - `avatar_url`: `TEXT DEFAULT ''`
  - `created_at`: `TIMESTAMPTZ NOT NULL DEFAULT NOW()`
  - `updated_at`: `TIMESTAMPTZ NOT NULL DEFAULT NOW()`

### 2.3 `public.public_profile_view`
- **Purpose:** Read-only marketplace public view (`WITH (security_invoker = true)`). Exposes non-sensitive fields only (`id`, `full_name`, `avatar_url`).

### 2.4 `public.seller_stores`
- **Purpose:** Canonical store profiles and financial settings.
- **Columns:**
  - `id`: `UUID PRIMARY KEY DEFAULT gen_random_uuid()`
  - `owner_id`: `UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`
  - `shop_name`: `TEXT NOT NULL`
  - `shop_slug`: `TEXT UNIQUE NOT NULL`
  - `business_name`: `TEXT DEFAULT ''`
  - `business_address`: `TEXT DEFAULT ''`
  - `city`: `TEXT DEFAULT ''`
  - `country`: `TEXT DEFAULT 'Pakistan'`
  - `category`: `TEXT DEFAULT ''`
  - `shop_description`: `TEXT DEFAULT ''`
  - `shop_logo`: `TEXT DEFAULT ''`
  - `shop_banner`: `TEXT DEFAULT ''`
  - `is_approved`: `BOOLEAN NOT NULL DEFAULT FALSE`
  - `kyc_status`: `TEXT NOT NULL DEFAULT 'Pending' CHECK (kyc_status IN ('Pending', 'Approved', 'Rejected'))`
  - `commission_rate`: `NUMERIC(5,2) NOT NULL DEFAULT 10.00 CHECK (commission_rate >= 0.00 AND commission_rate <= 100.00)`
  - `balance`: `NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0.00)`
  - `pending_payout`: `NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (pending_payout >= 0.00)`
  - `last_payout`: `NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (last_payout >= 0.00)`
  - `created_at`: `TIMESTAMPTZ NOT NULL DEFAULT NOW()`
  - `updated_at`: `TIMESTAMPTZ NOT NULL DEFAULT NOW()`

### 2.5 `public.seller_kyc_documents`
- **Purpose:** Seller identity and business verification documents.
- **Columns:**
  - `id`: `UUID PRIMARY KEY DEFAULT gen_random_uuid()`
  - `seller_store_id`: `UUID NOT NULL REFERENCES public.seller_stores(id) ON DELETE CASCADE`
  - `document_type`: `TEXT NOT NULL`
  - `document_url`: `TEXT NOT NULL`
  - `cnic_number`: `TEXT DEFAULT ''`
  - `ntn_number`: `TEXT DEFAULT ''`
  - `status`: `TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected'))`
  - `submitted_by`: `UUID REFERENCES auth.users(id)`
  - `reviewed_by`: `UUID REFERENCES auth.users(id)`
  - `reviewed_at`: `TIMESTAMPTZ`
  - `rejection_reason`: `TEXT`
  - `submitted_at`: `TIMESTAMPTZ NOT NULL DEFAULT NOW()`
  - `updated_at`: `TIMESTAMPTZ NOT NULL DEFAULT NOW()`

### 2.6 `public.categories`
- **Purpose:** Product classification taxonomy.
- **Columns:**
  - `id`: `UUID PRIMARY KEY DEFAULT gen_random_uuid()`
  - `name`: `TEXT UNIQUE NOT NULL`
  - `slug`: `TEXT UNIQUE NOT NULL`
  - `icon`: `TEXT DEFAULT ''`
  - `banner_url`: `TEXT DEFAULT ''`
  - `is_active`: `BOOLEAN NOT NULL DEFAULT TRUE`
  - `display_order`: `INT NOT NULL DEFAULT 0`
  - `created_at`: `TIMESTAMPTZ NOT NULL DEFAULT NOW()`
  - `updated_at`: `TIMESTAMPTZ NOT NULL DEFAULT NOW()`

### 2.7 `public.products`
- **Purpose:** Product listings catalog.
- **Columns:**
  - `id`: `UUID PRIMARY KEY DEFAULT gen_random_uuid()`
  - `seller_store_id`: `UUID NOT NULL REFERENCES public.seller_stores(id) ON DELETE CASCADE`
  - `category_id`: `UUID REFERENCES public.categories(id) ON DELETE SET NULL`
  - `name`: `TEXT NOT NULL`
  - `description`: `TEXT DEFAULT ''`
  - `price`: `NUMERIC(12,2) NOT NULL CHECK (price >= 0.00)`
  - `sale_price`: `NUMERIC(12,2) CHECK (sale_price IS NULL OR sale_price >= 0.00)`
  - `rating`: `NUMERIC(3,2) NOT NULL DEFAULT 5.00 CHECK (rating >= 0.00 AND rating <= 5.00)`
  - `stock_quantity`: `INT NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0)`
  - `image_url`: `TEXT NOT NULL DEFAULT ''`
  - `category`: `TEXT DEFAULT ''`
  - `approval_status`: `TEXT NOT NULL DEFAULT 'Approved' CHECK (approval_status IN ('Pending', 'Approved', 'Rejected'))`
  - `is_active`: `BOOLEAN NOT NULL DEFAULT TRUE`
  - `created_at`: `TIMESTAMPTZ NOT NULL DEFAULT NOW()`
  - `updated_at`: `TIMESTAMPTZ NOT NULL DEFAULT NOW()`

### 2.8 `public.buyer_orders`
- **Purpose:** Order records (Temporary compatibility table for Phase 3/4; normalized relational design assigned to Phase 8).
- **Columns:**
  - `id`: `TEXT PRIMARY KEY`
  - `customer_user_id`: `UUID REFERENCES auth.users(id) ON DELETE SET NULL`
  - `customer_name`: `TEXT NOT NULL`
  - `customer_email`: `TEXT NOT NULL`
  - `amount`: `NUMERIC(12,2) NOT NULL CHECK (amount >= 0.00)`
  - `payment_method`: `TEXT NOT NULL`
  - `items`: `JSONB NOT NULL DEFAULT '[]'::jsonb`
  - `status`: `TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'))`
  - `created_at`: `TIMESTAMPTZ NOT NULL DEFAULT NOW()`
  - `updated_at`: `TIMESTAMPTZ NOT NULL DEFAULT NOW()`

---

## 3. LEGACY TABLES & QUARANTINE PLAN
- `public.sellers`: Deprecated alias. Preflight assertions log legacy existence for manual review.
- `public.seller_store`: Deprecated alias. Preflight assertions log legacy existence for manual review.
- Legacy `profiles.role` column values are flagged for manual admin verification before user_roles migration.
