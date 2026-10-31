import 'package:flutter/material.dart';

class SellerDashboardSidebar extends StatelessWidget {
  final String activeSection;
  final ValueChanged<String> onSelectSection;
  final Color goldColor;

  const SellerDashboardSidebar({
    super.key,
    required this.activeSection,
    required this.onSelectSection,
    required this.goldColor,
  });

  Widget _buildSidebarTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String sectionId,
  }) {
    final isSel = activeSection == sectionId;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSel ? goldColor.withOpacity(0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          dense: true,
          leading: Icon(icon, color: isSel ? goldColor : Colors.white70, size: 20),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
              color: isSel ? goldColor : Colors.white.withOpacity(0.9),
            ),
          ),
          onTap: () {
            onSelectSection(sectionId);
            if (MediaQuery.of(context).size.width <= 600) {
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }

  Widget _buildExpandableSidebarTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
    required String defaultSectionId,
    bool initiallyExpanded = false,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon, color: goldColor, size: 20),
          title: InkWell(
            onTap: () => onSelectSection(defaultSectionId),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ),
          iconColor: goldColor,
          collapsedIconColor: Colors.white70,
          childrenPadding: const EdgeInsets.only(left: 12),
          onExpansionChanged: (expanded) {
            onSelectSection(defaultSectionId);
          },
          children: children,
        ),
      ),
    );
  }

  Widget _buildSidebarSubTile(BuildContext context, String title, String sectionId) {
    final isSel = activeSection == sectionId;
    return Container(
      margin: const EdgeInsets.only(left: 8, right: 8, top: 2, bottom: 2),
      decoration: BoxDecoration(
        color: isSel ? const Color(0xFFFDB913).withOpacity(0.25) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: isSel ? Border.all(color: const Color(0xFFFDB913).withOpacity(0.6), width: 1) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
              color: isSel ? const Color(0xFFFDB913) : Colors.white.withOpacity(0.85),
            ),
          ),
          onTap: () {
            onSelectSection(sectionId);
            if (MediaQuery.of(context).size.width <= 600) {
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF0B132B),
            border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.storefront_rounded, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Primrose Store',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                        Text(
                          'Seller Center',
                          style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Dashboard
        _buildSidebarTile(
          context: context,
          title: 'Dashboard',
          icon: Icons.dashboard_outlined,
          sectionId: 'dashboard',
        ),
        // Products
        _buildExpandableSidebarTile(
          context: context,
          title: 'Products',
          icon: Icons.shopping_bag_outlined,
          defaultSectionId: 'products_manage',
          initiallyExpanded: activeSection.startsWith('products'),
          children: [
            _buildSidebarSubTile(context, 'Product List', 'products_manage'),
            _buildSidebarSubTile(context, 'Add Product', 'products_add'),
            _buildSidebarSubTile(context, 'Variations', 'products_variations'),
          ],
        ),
        // Orders
        _buildExpandableSidebarTile(
          context: context,
          title: 'Orders',
          icon: Icons.shopping_cart_outlined,
          defaultSectionId: 'orders_manage',
          initiallyExpanded: activeSection.startsWith('orders'),
          children: [
            _buildSidebarSubTile(context, 'Manage Orders', 'orders_manage'),
            _buildSidebarSubTile(context, 'Returns & Disputes', 'orders_returns'),
          ],
        ),
        // Customers
        _buildExpandableSidebarTile(
          context: context,
          title: 'Customers',
          icon: Icons.people_outline,
          defaultSectionId: 'customers_chat',
          initiallyExpanded: activeSection.startsWith('customers'),
          children: [
            _buildSidebarSubTile(context, 'Customer List', 'customers_list'),
            _buildSidebarSubTile(context, 'Customer Messages', 'customers_chat'),
          ],
        ),
        // Inventory
        _buildExpandableSidebarTile(
          context: context,
          title: 'Inventory',
          icon: Icons.inventory_2_outlined,
          defaultSectionId: 'inventory_alerts',
          initiallyExpanded: activeSection.startsWith('inventory'),
          children: [
            _buildSidebarSubTile(context, 'Stock Alert', 'inventory_alerts'),
            _buildSidebarSubTile(context, 'Warehouse', 'inventory_warehouse'),
          ],
        ),
        // Marketing
        _buildExpandableSidebarTile(
          context: context,
          title: 'Marketing',
          icon: Icons.campaign_outlined,
          defaultSectionId: 'marketing_ads',
          initiallyExpanded: activeSection.startsWith('marketing'),
          children: [
            _buildSidebarSubTile(context, 'Ads Manager', 'marketing_ads'),
            _buildSidebarSubTile(context, 'Vouchers & Coupons', 'marketing_vouchers'),
          ],
        ),
        // Analytics
        _buildExpandableSidebarTile(
          context: context,
          title: 'Analytics',
          icon: Icons.analytics_outlined,
          defaultSectionId: 'analytics_performance',
          initiallyExpanded: activeSection.startsWith('analytics'),
          children: [
            _buildSidebarSubTile(context, 'Performance Summary', 'analytics_performance'),
            _buildSidebarSubTile(context, 'Sales Reports', 'analytics_reports'),
          ],
        ),
        // Finance
        _buildExpandableSidebarTile(
          context: context,
          title: 'Finance',
          icon: Icons.account_balance_wallet_outlined,
          defaultSectionId: 'finance_wallet',
          initiallyExpanded: activeSection.startsWith('finance'),
          children: [
            _buildSidebarSubTile(context, 'Wallet & Payouts', 'finance_wallet'),
            _buildSidebarSubTile(context, 'Transaction History', 'finance_history'),
          ],
        ),
        // Reviews
        _buildExpandableSidebarTile(
          context: context,
          title: 'Reviews',
          icon: Icons.rate_review_outlined,
          defaultSectionId: 'reviews_product',
          initiallyExpanded: activeSection.startsWith('reviews'),
          children: [
            _buildSidebarSubTile(context, 'Product Reviews', 'reviews_product'),
            _buildSidebarSubTile(context, 'Store Rating', 'reviews_rating'),
          ],
        ),
        // Store
        _buildExpandableSidebarTile(
          context: context,
          title: 'Store',
          icon: Icons.storefront_outlined,
          defaultSectionId: 'store_settings',
          initiallyExpanded: activeSection.startsWith('store'),
          children: [
            _buildSidebarSubTile(context, 'Store Settings', 'store_settings'),
            _buildSidebarSubTile(context, 'Store Design', 'store_design'),
          ],
        ),
        // Settings
        _buildExpandableSidebarTile(
          context: context,
          title: 'Settings',
          icon: Icons.settings_outlined,
          defaultSectionId: 'settings_account',
          initiallyExpanded: activeSection.startsWith('settings'),
          children: [
            _buildSidebarSubTile(context, 'Account Settings', 'settings_account'),
            _buildSidebarSubTile(context, 'Shipping Settings', 'settings_shipping'),
          ],
        ),
        // Support
        _buildExpandableSidebarTile(
          context: context,
          title: 'Support',
          icon: Icons.support_agent_outlined,
          defaultSectionId: 'support_tickets',
          initiallyExpanded: activeSection.startsWith('support'),
          children: [
            _buildSidebarSubTile(context, 'Help Tickets', 'support_tickets'),
            _buildSidebarSubTile(context, 'KYC Verification', 'support_kyc'),
          ],
        ),
      ],
    );
  }
}
