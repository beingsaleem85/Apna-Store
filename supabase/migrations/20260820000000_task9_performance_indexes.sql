-- ============================================================================
-- Migration: 20260820000000_task9_performance_indexes.sql
-- Description: Task 9 - Production Database Indexes for Hot Query Optimization
-- ============================================================================

-- 1. Indexing Products Catalog for fast category filtering & home queries
CREATE INDEX IF NOT EXISTS idx_products_category_active 
    ON public.products(category_id, is_active)
    WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_products_seller_created 
    ON public.products(seller_id, created_at DESC);

-- 2. Indexing Orders for Buyer and Seller Dashboards
CREATE INDEX IF NOT EXISTS idx_orders_buyer_created 
    ON public.orders(buyer_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_orders_status_created 
    ON public.orders(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id 
    ON public.order_items(order_id);

CREATE INDEX IF NOT EXISTS idx_order_items_product_id 
    ON public.order_items(product_id);

-- 3. Notifications & Activity Optimization
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread 
    ON public.notifications(user_id, is_read, created_at DESC);

-- 4. Vouchers & Redemptions
CREATE INDEX IF NOT EXISTS idx_vouchers_code_active 
    ON public.vouchers(code, is_active)
    WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_voucher_redemptions_user_voucher 
    ON public.voucher_redemptions(user_id, voucher_id);

-- 5. Support Tickets & Disputes
CREATE INDEX IF NOT EXISTS idx_support_tickets_status_priority 
    ON public.support_tickets(status, priority, created_at DESC);

-- 6. Platform Integrations Provider Lookup
CREATE INDEX IF NOT EXISTS idx_platform_integrations_provider 
    ON public.platform_integrations(provider_key);
