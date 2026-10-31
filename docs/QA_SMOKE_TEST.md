# APNA STORE — PRODUCTION QA SMOKE TEST RUNBOOK

This runbook outlines the complete end-to-end user verification workflow across all three portals (Buyer, Seller, Super Admin).

---

## Smoke Test 1: Buyer Flow (Catalog to Order Placement)
1. **Browse Storefront:**
   - Navigate to `http://127.0.0.1:8080/` (or `http://localhost:8080/`).
   - Verify product grid renders with active items.
   - Verify flash sale section displays active sale or cleanly hides if none active.
2. **Product Details & Cart:**
   - Tap any product to view product details and real customer reviews.
   - Tap **Add to Cart**. Verify cart counter in top header increments.
   - Open Cart dialog and verify subtotal calculation.
3. **Voucher Validation:**
   - Enter an invalid promo code (e.g., `FAKECODE`). Verify error message is returned from server.
   - Enter a valid database voucher. Verify discount is calculated and applied by backend.
4. **Checkout (Payment Guard Verification):**
   - Proceed to Checkout.
   - Confirm JazzCash, Easypaisa, and Debit/Credit Card display "Coming Soon" chip and are disabled.
   - Select **Cash on Delivery (COD)**.
   - Submit order. Verify order number is generated and order status is set to `Pending`.

---

## Smoke Test 2: Seller Portal Flow (Order Fulfillment)
1. **Seller Navigation:**
   - Access `/seller` portal.
   - View pending orders under Orders Dispatch tab.
2. **Order Dispatch:**
   - Select the newly placed COD order.
   - Update order status to `Shipped` and input tracking consignment number.
3. **Buyer Real-Time Tracking Check:**
   - Return to Buyer Orders -> Track Order (`buyer_order_tracking_screen`).
   - Confirm the new `Shipped` tracking event appears on the live timeline.

---

## Smoke Test 3: Super Admin Governance
1. **Access Control (RBAC):**
   - Access `/super-admin` portal.
   - Verify non-admin accounts are rejected with 403 Forbidden.
2. **Commission Engine:**
   - Navigate to Commission Engine. Modify a category commission rate and click **Save Changes**.
   - Verify update persists and audit log records the modification.
3. **Review Moderation:**
   - Navigate to Reviews Moderation. Reject or approve a submitted product review.
4. **Support Desk:**
   - View customer support inquiries and update ticket resolution status.
