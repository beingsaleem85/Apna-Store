# First Owner Bootstrap Guide (One-Time Execution)

> [!IMPORTANT]
> This SQL script must be executed **only** via the Supabase Dashboard SQL Editor as the database superuser (`postgres`). It should **never** be exposed in client code or application RPCs.

---

### Step 1: Assign First Owner Account

Replace `'YOUR_USER_UUID_HERE'` with your actual `auth.users.id`:

```sql
-- 1. Elevate first user to Owner
INSERT INTO public.user_roles (user_id, role, staff_role, granted_at)
VALUES (
    'YOUR_USER_UUID_HERE'::uuid,
    'owner'::public.app_role,
    'owner'::public.admin_staff_role,
    NOW()
)
ON CONFLICT (user_id, role)
DO UPDATE SET
    staff_role = 'owner'::public.admin_staff_role,
    granted_at = NOW();

-- 2. Ensure profile exists and has owner role reflected
UPDATE public.profiles
SET role = 'owner'::public.app_role,
    updated_at = NOW()
WHERE id = 'YOUR_USER_UUID_HERE'::uuid;
```

---

### Step 2: Verification Query

Run this query to inspect all administrative and staff role holders:

```sql
SELECT 
    ur.user_id,
    u.email,
    p.full_name,
    ur.role::text AS app_role,
    COALESCE(ur.staff_role::text, 'NO_STAFF_ROLE') AS staff_role,
    ur.granted_at
FROM public.user_roles ur
JOIN auth.users u ON u.id = ur.user_id
LEFT JOIN public.profiles p ON p.id = ur.user_id
WHERE ur.role IN ('owner'::public.app_role, 'super_admin'::public.app_role, 'admin'::public.app_role)
ORDER BY 
    CASE ur.role
        WHEN 'owner'::public.app_role THEN 1
        WHEN 'super_admin'::public.app_role THEN 2
        ELSE 3
    END,
    ur.granted_at DESC;
```

---

### Step 3: Unassigned Legacy Admins Inspection & Reassignment

During migration `20260829000000`, PostgreSQL logs `NOTICE` entries:
```
NOTICE: UNASSIGNED_LEGACY_ADMIN: user_id=..., email=...
```

To view all legacy admins who currently hold `role = 'admin'` but lack a `staff_role`:

```sql
SELECT ur.user_id, u.email, ur.role, ur.staff_role
FROM public.user_roles ur
JOIN auth.users u ON u.id = ur.user_id
WHERE ur.role = 'admin'::public.app_role
  AND ur.staff_role IS NULL;
```

#### Reassigning Staff Roles Safely Without Lockout:

Once you are established as `owner` via Step 1, you can assign any staff role using `admin_assign_staff_role`:

```sql
-- Example: Assign financeAdmin to a legacy admin
SELECT public.admin_assign_staff_role(
    'TARGET_USER_UUID'::uuid,
    'financeAdmin'::public.admin_staff_role
);

-- Example: Assign disputeManager
SELECT public.admin_assign_staff_role(
    'TARGET_USER_UUID'::uuid,
    'disputeManager'::public.admin_staff_role
);

-- Example: Elevate a co-administrator to superAdmin
SELECT public.admin_assign_staff_role(
    'TARGET_USER_UUID'::uuid,
    'superAdmin'::public.admin_staff_role
);
```

#### Lockout Prevention:
- Default deny only affects unassigned `role = 'admin'` users.
- Because `owner` and `super_admin` maintain bypass authority in `public.has_permission`, establishing the owner via Step 1 ensures zero disruption to administrative governance.
