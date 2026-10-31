# APNA STORE — ROLLBACK & RECOVERY PLAN

> **Phase:** 4 — Database Schema Consolidation, Safe SQL Migrations, and RLS Alignment  
> **Status:** Active Operational Standard  

---

## 1. RECOVERY STRATEGY
All Phase 4 migrations are strictly additive. In the event of a migration failure:
1. Re-run `supabase db reset` locally to clear transient state and re-apply from migration 0.
2. Legacy table aliases (`sellers`, `seller_store`) are preserved and not destroyed.
3. No destructive `DROP TABLE ... CASCADE` or `DROP SCHEMA` statements exist in migration scripts.

---

## 2. DESTRUCTIVE ACTIONS RESTRICTION
> [!CAUTION]
> Destructive rollbacks (dropping tables or wiping schemas) against remote database environments are strictly prohibited without explicit written authorization and verified offline backups.
