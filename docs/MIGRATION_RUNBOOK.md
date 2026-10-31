# APNA STORE — MIGRATION RUNBOOK

> **Phase:** 4 — Database Schema Consolidation, Safe SQL Migrations, and RLS Alignment  
> **Status:** Local Execution Blocked (Docker / Supabase CLI uninstalled)  

---

## 1. PRE-REQUISITES (LOCAL ENVIRONMENT ONLY)
To execute local database migrations when tooling becomes available:
- Install Docker Desktop
- Install Supabase CLI (`winget install Supabase.CLI` or `scoop install supabase`)

---

## 2. FUTURE LOCAL-ONLY EXECUTION STEPS
```bash
# 1. Initialize local configuration if config.toml missing
supabase init

# 2. Start local Supabase containers
supabase start

# 3. Reset local database container and execute ordered migration chain
supabase db reset --local

# 4. Check local migration list and status
supabase migration list

# 5. Execute static database linting
supabase db lint --local

# 6. Run prepared local pgTAP security tests
supabase test db
```

---

## 3. PROHIBITED COMMANDS & REMOTE DEPLOYMENT POLICY
> [!CAUTION]
> **STRICT RULE:** Never execute `supabase db reset --linked` or `supabase db push` against a remote or production Supabase project without explicit authorization from the user.
