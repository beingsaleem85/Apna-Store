# SUPER ADMIN ROLE-BASED ACCESS CONTROL (RBAC) PERMISSIONS MATRIX

This document defines the roles, module permissions, and granular action privileges for the Apna Store Super Admin System.

---

## 👥 Supported Admin Roles
1. **`Owner`**: Full system control with immutable privileges.
2. **`Super Admin`**: Full platform management except owner transfer.
3. **`Finance Admin`**: Financial ledgers, payouts, commission rules, settlements, refunds.
4. **`Seller Manager`**: Seller onboarding, store verification, merchant compliance, suspensions.
5. **`Customer Support Admin`**: Tickets, customer queries, account assistance, order lookup.
6. **`Catalog Manager`**: Category tree, brand approvals, product moderation.
7. **`Order Manager`**: Order timeline, hold/release, courier tracking, cancellation desk.
8. **`Dispute Manager`**: Return requests, refund arbitration, evidence review.
9. **`Marketing Manager`**: Campaigns, vouchers, homepage banners, notifications.
10. **`Fraud Analyst`**: Abuse detection, risk scoring, blacklists, security logs.
11. **`Reporting Analyst`**: Read-only reports, analytics dashboard, export functions.
12. **`Read-Only Auditor`**: View-only access across all modules for compliance auditing.

---

## 🔒 Permission Matrix Table

| Module | Action Privilege | Owner | Super Admin | Finance Admin | Seller Manager | Support Admin | Catalog Manager | Auditor |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Sellers** | View List / Profile | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| **Sellers** | Approve / Reject Store | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| **Sellers** | Suspend / Ban Seller | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| **Products** | Approve / Moderation | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ |
| **Orders** | Admin Cancel / Hold | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ✅ |
| **Finance** | Approve Payout Batch | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Finance** | Modify Commission | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **Disputes** | Final Refund Decision | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ |
| **Staff** | Manage Admin Users | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Settings** | Marketplace Config | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
