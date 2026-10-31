# SUPER ADMIN SYSTEM ARCHITECTURE

This document describes the architectural design, directory structure, security layers, and data flow for the Super Admin Web & Mobile System.

---

## 🏗️ Directory Layout Pattern (`lib/features/super_admin/`)

```text
lib/features/super_admin/
├── core/
│   ├── auth/              # Admin Authentication, Guard, Session
│   ├── permissions/       # RBAC Evaluator & Roles Matrix
│   ├── theme/             # Dark Slate & High-Contrast Admin Theme
│   └── widgets/           # Reusable Data Table, Pagination, Filters, Modals, Badges
├── models/                # Super Admin Data Models (Staff, AuditLog, Commission, Payout, Dispute)
├── services/              # Supabase Admin Service & State Management
└── screens/               # Feature Modules
    ├── admin_shell.dart   # Main Responsive Shell (Sidebar + Header + Body)
    ├── auth/              # Super Admin Login Screen
    ├── dashboard/         # Executive Dashboard Screen
    ├── sellers/           # Seller Directory & KYC Approval Desk
    ├── customers/         # Customer Management & Wallet Desk
    ├── catalog/           # Category & Product Moderation Queue
    ├── orders/            # Master Order Table & Cancellation Desk
    ├── finance/           # Commission Rules & Payout Ledger
    ├── disputes/          # Returns & Dispute Resolution
    ├── marketing/         # Campaign & Banner CMS
    ├── support/           # Help Tickets Desk
    ├── fraud/             # Risk & Compliance Security Suite
    ├── reports/           # Reports & CSV/PDF Export Engine
    └── settings/          # Platform Settings & Admin Staff Manager
```

---

## 🔒 Security Architecture (Defense in Depth)

1. **Flutter Guard Layer**: `AdminAuthGuard` checks logged-in admin user role & granular permission token before allowing route transition.
2. **State Service Layer**: `SuperAdminProvider` evaluates `hasPermission(AdminModule.sellers, AdminAction.approve)` on every action method.
3. **Database RLS Layer**: PostgreSQL Policies check `(SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'super_admin')`.
4. **Audit Trail Layer**: Every write/update operation logs `admin_id`, `action_type`, `target_entity_id`, `old_values`, `new_values`, `ip_address`, `timestamp` into `public.admin_audit_logs`.
