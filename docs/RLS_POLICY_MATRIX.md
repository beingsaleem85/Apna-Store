# APNA STORE — RLS POLICY MATRIX & SECURITY SPECIFICATION

> **Phase:** 4 — Database Schema Consolidation, Safe SQL Migrations, and RLS Alignment  
> **Status:** Implementation Prepared  

---

## 1. POLICY MATRIX OVERVIEW

| Table | Role | SELECT | INSERT | UPDATE | DELETE | Security Rule / Column Privileges |
|---|---|---|---|---|---|---|
| `user_roles` | `anon` | ❌ | ❌ | ❌ | ❌ | Default Deny |
| `user_roles` | `buyer` | ✅ (Own role) | ❌ | ❌ | ❌ | `user_id = auth.uid()` |
| `user_roles` | `seller` | ✅ (Own role) | ❌ | ❌ | ❌ | `user_id = auth.uid()` |
| `user_roles` | `admin` | ✅ (All) | ❌ (Function) | ❌ (Function) | ❌ | Managed via `assign_user_role()` function |
| `profiles` | `anon` | ❌ | ❌ | ❌ | ❌ | Private profiles policy (Use `public_profile_view`) |
| `profiles` | `buyer` / `seller` | ✅ (Own row) | ✅ (Own ID) | ✅ (Personal) | ❌ | Role fields do not exist in `profiles` |
| `seller_stores` | `anon` / `buyer` | ✅ (Approved) | ❌ | ❌ | ❌ | `is_approved = TRUE` |
| `seller_stores` | `seller` | ✅ (Own store) | ✅ (Own ID) | ✅ (Business) | ❌ | Writable columns restricted via `GRANT UPDATE (...)` |
| `seller_stores` | `admin` | ✅ (All) | ❌ | ✅ (All) | ❌ | Approved via `admin_review_seller_store()` |
| `seller_kyc_documents` | `seller` | ✅ (Own store) | ✅ (Own store) | ❌ | ❌ | `status`, `reviewed_by` protected via `REVOKE UPDATE` |
| `seller_kyc_documents` | `admin` | ✅ (All) | ❌ | ✅ (All) | ❌ | Approved via `admin_review_kyc_document()` |
| `categories` | `anon` / `buyer` / `seller` | ✅ (Active) | ❌ | ❌ | ❌ | `is_active = TRUE` |
| `categories` | `admin` | ✅ (All) | ✅ | ✅ | ✅ | Full management |
| `products` | `anon` / `buyer` | ✅ (Approved) | ❌ | ❌ | ❌ | `approval_status = 'Approved' AND is_active = TRUE` |
| `products` | `seller` | ✅ (Own products)| ✅ (Own store) | ✅ (Safe fields) | ❌ | `approval_status` protected via `REVOKE UPDATE` |
| `products` | `admin` | ✅ (All) | ✅ | ✅ | ✅ | Reviewed via `admin_review_product()` |
| `buyer_orders` | `buyer` | ✅ (Own orders) | ✅ (Own ID) | ❌ | ❌ | Status/Amount updates denied via `REVOKE UPDATE` |
| `buyer_orders` | `seller` | ✅ (Store items) | ❌ | ❌ | ❌ | Read-only order item view |
| `buyer_orders` | `admin` | ✅ (All) | ❌ | ✅ | ❌ | Admin oversight |

---

## 2. SECURITY DEFINER FUNCTIONS INVENTORY (`SET search_path = ''`)
1. `public.get_current_user_role()`: Returns caller role from `user_roles`. `SET search_path = ''`.
2. `public.has_role(required_role app_role)`: Returns boolean. `SET search_path = ''`.
3. `public.is_admin()`: Checks admin/super_admin/owner roles. `SET search_path = ''`.
4. `public.owns_seller_store(target_store_id UUID)`: Verifies store ownership. `SET search_path = ''`.
5. `public.assign_user_role(target_user_id UUID, new_role app_role)`: Restricted admin role assignment. Executed with `PUBLIC, anon` execution revoked.
6. `public.admin_review_seller_store(target_store_id UUID, approve BOOLEAN, new_commission NUMERIC)`: Restricted admin store review function.
7. `public.admin_review_kyc_document(target_kyc_id UUID, new_status TEXT, reason TEXT)`: Restricted admin KYC review function.
8. `public.admin_review_product(target_product_id UUID, approve BOOLEAN)`: Restricted admin product approval function. Verifies caller `public.is_admin()`, validates product existence, prevents seller self-approval, revokes execution from `PUBLIC, anon`.
