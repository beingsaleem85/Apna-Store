# APNA STORE — SERVER-SIDE SECRETS SETUP GUIDE

> **Security Rule (Non-Negotiable):**  
> Secrets (API keys, private tokens, passwords, service-role keys) must **NEVER** exist in the Flutter client code or database client queries. The Flutter web bundle is downloaded and inspectable by any visitor.  
> All sensitive third-party integration credentials must be securely stored in **Supabase Edge Function Secrets** or **Vault** and accessed only by server-side Edge Functions.

---

## 1. Setting Secrets via Supabase CLI

To configure production or staging credentials, use the official Supabase CLI `secrets set` command:

```bash
supabase secrets set KEY=VALUE [KEY2=VALUE2 ...]
```

To view currently configured secret names (values remain masked):
```bash
supabase secrets list
```

---

## 2. Master Secret Inventory by Provider

### 2.1 JazzCash Gateway
```bash
supabase secrets set \
  JAZZCASH_MERCHANT_ID="your_jazzcash_merchant_id" \
  JAZZCASH_PASSWORD="your_jazzcash_password" \
  JAZZCASH_INTEGRITY_SALT="your_jazzcash_salt_string" \
  JAZZCASH_RETURN_URL="https://your-project.supabase.co/functions/v1/jazzcash-webhook"
```

### 2.2 Easypaisa Mobile Wallet
```bash
supabase secrets set \
  EASYPAISA_STORE_ID="your_easypaisa_store_id" \
  EASYPAISA_HASH_KEY="your_easypaisa_hash_key" \
  EASYPAISA_PAYMENT_URL="https://easypay.easypaisa.com.pk/easypay/Index.jsf"
```

### 2.3 1Link / PayPak / Direct Bill
```bash
supabase secrets set \
  ONELINK_MEMBER_ID="your_1link_member_id" \
  ONELINK_API_SECRET="your_1link_api_secret" \
  ONELINK_CLIENT_CERT_BASE64="your_base64_cert_if_applicable"
```

### 2.4 Stripe / 3D Secure Card Gateway
```bash
supabase secrets set \
  STRIPE_SECRET_KEY="sk_live_..." \
  STRIPE_WEBHOOK_SECRET="whsec_..."
```

### 2.5 TCS Courier Logistics
```bash
supabase secrets set \
  TCS_CLIENT_KEY="your_tcs_client_key" \
  TCS_API_TOKEN="your_tcs_api_token" \
  TCS_COST_CENTER_CODE="your_tcs_cost_center"
```

### 2.6 Leopard Logistics
```bash
supabase secrets set \
  LEOPARD_API_KEY="your_leopard_api_key" \
  LEOPARD_API_PASSWORD="your_leopard_api_password"
```

### 2.7 Trax Logistics Network
```bash
supabase secrets set \
  TRAX_AUTH_TOKEN="your_trax_auth_token"
```

### 2.8 Transactional SMS Gateway
```bash
supabase secrets set \
  SMS_GATEWAY_API_KEY="your_sms_provider_api_key" \
  SMS_GATEWAY_SENDER_ID="APNASTORE"
```

### 2.9 External Cloud Storage (AWS S3)
```bash
supabase secrets set \
  S3_BUCKET_NAME="apna-store-production-media" \
  S3_ACCESS_KEY_ID="your_aws_s3_key_id" \
  S3_SECRET_ACCESS_KEY="your_aws_s3_secret" \
  S3_REGION="ap-south-1"
```

### 2.10 FBR Digital Invoicing & POS Integration
```bash
supabase secrets set \
  FBR_POS_AUTH_BEARER="your_fbr_bearer_token" \
  FBR_POS_POSID="your_registered_fbr_pos_id"
```

---

## 3. How the Admin UI Interacts with Integrations

In the Super Admin Portal (`/super-admin`):
- Admins see integration tiles (`provider_key`, `display_name`, `category`, and status: `Configured` or `Not Configured`).
- Admins can toggle `is_enabled` on or off via the `admin_set_integration_enabled` RPC.
- **No secret strings or API keys are displayed or edited in the Flutter app.**
- Status changes are logged to `public.admin_audit_logs`.
