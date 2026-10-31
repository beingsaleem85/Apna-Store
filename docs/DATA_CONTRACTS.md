# APNA STORE — DATA CONTRACTS INVENTORY

> **Phase:** 4 — Database Schema Consolidation, Safe SQL Migrations, and RLS Alignment  
> **Status:** Authoritative Local Specification  

---

## 1. CANONICAL DATABASE DTO CONTRACTS

### 1.1 Role Contract (`user_roles`)
- **Table Name:** `user_roles`
- **Field Mappings:**
  | Dart Property / Concept | Database Column | Type | Nullable |
  |---|---|---|---|
  | `id` | `id` | `UUID` | No |
  | `userId` | `user_id` | `UUID` | No |
  | `role` | `role` | `app_role (enum)` | No |
  | `grantedAt` | `granted_at` | `DateTime` | No |
  | `grantedBy` | `granted_by` | `UUID` | Yes |
- **Security Rule:** Roles are managed exclusively via `user_roles` table and `assign_user_role` function. Client signup metadata cannot set roles.

### 1.2 User Profile Contract (`profiles`)
- **DTO Class:** [`ProfileDto`](file:///c:/Users/X%20COMPUTER/Desktop/apna%20store/lib/core/models/dtos/profile_dto.dart)
- **Table Name:** `profiles`
- **Field Mappings:**
  | Dart Property | Database Column | Type | Nullable |
  |---|---|---|---|
  | `id` | `id` | `UUID / String` | No |
  | `fullName` | `full_name` | `String` | No |
  | `email` | `email` | `String` | No |
  | `mobileNumber` | `mobile_number` | `String` | Yes |
  | `avatarUrl` | `avatar_url` | `String` | Yes |
  | `createdAt` | `created_at` | `DateTime` | Yes |
  | `updatedAt` | `updated_at` | `DateTime` | Yes |

### 1.3 Seller Store Contract (`seller_stores`)
- **DTO Class:** [`SellerStoreDto`](file:///c:/Users/X%20COMPUTER/Desktop/apna%20store/lib/core/models/dtos/seller_store_dto.dart)
- **Table Name:** `seller_stores`
- **Field Mappings:**
  | Dart Property | Database Column | Type | Nullable |
  |---|---|---|---|
  | `id` | `id` | `UUID / String` | No |
  | `userId` / `ownerId` | `owner_id` (and `user_id` alias) | `UUID / String` | No |
  | `shopName` | `shop_name` | `String` | No |
  | `shopSlug` | `shop_slug` | `String` | No |
  | `businessName` | `business_name` | `String` | Yes |
  | `businessAddress` | `business_address` | `String` | Yes |
  | `city` | `city` | `String` | Yes |
  | `country` | `country` | `String` | Yes |
  | `category` | `category` | `String` | Yes |
  | `shopDescription` | `shop_description` | `String` | Yes |
  | `shopLogo` | `shop_logo` | `String` | Yes |
  | `shopBanner` | `shop_banner` | `String` | Yes |
  | `isApproved` | `is_approved` | `bool` | No |
  | `kycStatus` | `kyc_status` | `String` | No |
  | `commissionRate` | `commission_rate` | `double` | No |
  | `balance` | `balance` | `double` | No |
  | `pendingPayout` | `pending_payout` | `double` | No |
  | `lastPayout` | `last_payout` | `double` | No |
  | `createdAt` | `created_at` | `DateTime` | Yes |
  | `updatedAt` | `updated_at` | `DateTime` | Yes |
- **Security Rule:** Strictly zero password fields. Credentials exist only as short-lived ephemeral input parameters during auth requests.

### 1.4 Product Contract (`products`)
- **DTO Class:** [`ProductDto`](file:///c:/Users/X%20COMPUTER/Desktop/apna%20store/lib/core/models/dtos/product_dto.dart)
- **Table Name:** `products`
- **Field Mappings:**
  | Dart Property | Database Column | Type | Nullable |
  |---|---|---|---|
  | `id` | `id` | `UUID / String` | No |
  | `name` | `name` | `String` | No |
  | `price` | `price` | `double` | No |
  | `rating` | `rating` | `double` | No |
  | `imageUrl` | `image_url` | `String` | No |
  | `sellerId` / `sellerStoreId` | `seller_store_id` (and `seller_id`) | `UUID / String` | No |
  | `description` | `description` | `String` | Yes |
  | `stock` | `stock_quantity` | `int` | No |
  | `category` | `category` | `String` | Yes |
  | `approvalStatus` | `approval_status` | `String` | No |
  | `createdAt` | `created_at` | `DateTime` | Yes |

### 1.5 Category Contract (`categories`)
- **DTO Class:** [`CategoryDto`](file:///c:/Users/X%20COMPUTER/Desktop/apna%20store/lib/core/models/dtos/category_dto.dart)
- **Table Name:** `categories`
- **Field Mappings:**
  | Dart Property | Database Column | Type | Nullable |
  |---|---|---|---|
  | `id` | `id` | `UUID / String` | No |
  | `name` | `name` | `String` | No |
  | `icon` | `icon` | `String` | Yes |
  | `bannerUrl` | `banner_url` | `String` | Yes |

### 1.6 Order Contract (`buyer_orders`)
- **DTO Class:** [`OrderDto`](file:///c:/Users/X%20COMPUTER/Desktop/apna%20store/lib/core/models/dtos/order_dto.dart)
- **Table Name:** `buyer_orders`
- **Field Mappings:**
  | Dart Property | Database Column | Type | Nullable |
  |---|---|---|---|
  | `id` | `id` | `UUID / String` | No |
  | `customerName` | `customer_name` | `String` | No |
  | `customerEmail` | `customer_email` | `String` | No |
  | `amount` | `amount` | `double` | No |
  | `paymentMethod` | `payment_method` | `String` | No |
  | `items` | `items` | `List<Map<String, dynamic>>` | No |
  | `status` | `status` | `String` | No |
  | `createdAt` | `created_at` | `DateTime` | Yes |

### 1.7 KYC Document Contract (`seller_kyc_documents`)
- **DTO Class:** [`KycDocumentDto`](file:///c:/Users/X%20COMPUTER/Desktop/apna%20store/lib/core/models/dtos/kyc_dto.dart)
- **Table Name:** `seller_kyc_documents`
- **Field Mappings:**
  | Dart Property | Database Column | Type | Nullable |
  |---|---|---|---|
  | `id` | `id` | `UUID / String` | No |
  | `sellerStoreId` / `sellerId` | `seller_store_id` | `UUID / String` | No |
  | `documentType` | `document_type` | `String` | No |
  | `documentUrl` | `document_url` | `String` | No |
  | `status` | `status` | `String` | No |
  | `submittedAt` | `submitted_at` | `DateTime` | Yes |

---

## 2. DEPRECATED / INCOMPATIBLE CONTRACTS REMOVED
- **Legacy alias table names (`sellers`, `seller_store`):** Consolidated into canonical `seller_stores`.
- **Client-driven role metadata (`raw_user_meta_data->>'role'`):** Superseded by protected `user_roles` table.
