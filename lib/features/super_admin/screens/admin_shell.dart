import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_breakpoints.dart';
import '../core/auth/admin_auth_guard.dart';
import '../core/theme/admin_theme.dart';
import '../services/super_admin_provider.dart';
import '../../../core/services/app_state_provider.dart';
import '../../../core/widgets/dev_version_banner.dart';
import 'settings/admin_staff_management_screen.dart';
import 'dashboard/executive_dashboard_screen.dart';
import 'sellers/seller_governance_screen.dart';
import 'customers/customer_management_screen.dart';
import 'catalog/category_governance_screen.dart';
import 'catalog/product_moderation_screen.dart';
import 'orders/master_orders_screen.dart';
import 'finance/commission_engine_screen.dart';
import 'finance/payout_ledger_screen.dart';
import 'disputes/dispute_arbitration_screen.dart';
import 'shipping/shipping_governance_screen.dart';
import 'marketing/promotions_cms_screen.dart';
import 'reviews/reviews_moderation_screen.dart';
import 'support/support_desk_screen.dart';
import 'marketing/notifications_broadcast_screen.dart';
import 'security/fraud_security_screen.dart';
import 'analytics/analytics_reports_screen.dart';
import 'cms/cms_content_screen.dart';
import 'settings/platform_config_screen.dart';
import 'ai/ai_copilot_screen.dart';

class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({super.key});

  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final superAdminState = Provider.of<SuperAdminProvider>(context);
    final isWeb = MediaQuery.of(context).size.width > 900;

    return Column(
      children: [
        Expanded(
          child: Theme(
            data: SuperAdminTheme.themeData,
            child: Scaffold(
              backgroundColor: SuperAdminTheme.bgDark,
              appBar: !isWeb ? _buildTopAppBar(context, superAdminState) : null,
              drawer: !isWeb ? Drawer(child: _buildSidebarList(context, superAdminState)) : null,
              body: Row(
                children: [
                  if (isWeb)
                    Container(
                      width: 270,
                      color: SuperAdminTheme.sidebarDark,
                      child: _buildSidebarList(context, superAdminState),
                    ),
                  if (isWeb) const VerticalDivider(thickness: 1, width: 1, color: SuperAdminTheme.borderDark),
                  Expanded(
                    child: Column(
                      children: [
                        if (isWeb) _buildTopAppBar(context, superAdminState),
                        Expanded(
                          child: _buildActiveModuleView(superAdminState.activeSection),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildTopAppBar(BuildContext context, SuperAdminProvider adminState) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Global Search Input (Matching Screenshots)
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 40,
                  constraints: const BoxConstraints(maxWidth: 460),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      hintText: 'Search users, sellers, orders, products...',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Top Action Tools (Matching Screenshots)
            IconButton(
              icon: const Badge(
                label: Text('2'),
                child: Icon(Icons.notifications_none_outlined, color: Color(0xFF475569)),
              ),
              tooltip: 'Admin Notifications',
              onPressed: () => adminState.setActiveSection('notifications'),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Color(0xFF475569)),
              tooltip: 'Platform Settings',
              onPressed: () => adminState.setActiveSection('config'),
            ),
            IconButton(
              icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF475569)),
              tooltip: 'Support Desk',
              onPressed: () => adminState.setActiveSection('support'),
            ),

            const SizedBox(width: 8),

            // Language Selector (English / اردو)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Text('English / اردو', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Profile Avatar & Role Selector
            Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0xFF0F172A),
                  child: Icon(Icons.person, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(adminState.adminName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Role: ${adminState.currentRole.name}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  ],
                ),
              ],
            ),

            const SizedBox(width: 16),

            // Quick Action Primary Button
            ElevatedButton.icon(
              onPressed: () => adminState.setActiveSection('products'),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Quick actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),

            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
              tooltip: 'Exit to Customer Website',
              onPressed: () => Navigator.pushReplacementNamed(context, '/'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarList(BuildContext context, SuperAdminProvider adminState) {
    return Container(
      color: const Color(0xFF0B132B), // Deep Dark Navy Sidebar (Matching Screenshots)
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Sidebar Logo Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF0B132B),
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.shopping_cart_rounded, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SuperCart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                      Text('Pakistan', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: const Text('Production', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                ),
              ],
            ),
          ),

          _buildSidebarTile(adminState, 'Overview', Icons.dashboard_outlined, 'dashboard'),
          _buildSidebarTile(adminState, 'Users', Icons.people_alt_outlined, 'staff'),
          _buildSidebarTile(adminState, 'Sellers', Icons.storefront_outlined, 'sellers'),
          _buildSidebarTile(adminState, 'Products', Icons.check_circle_outline, 'products'),
          _buildSidebarTile(adminState, 'Categories', Icons.grid_view_outlined, 'categories'),
          _buildSidebarTile(adminState, 'Brands', Icons.category_outlined, 'brands'),
          _buildSidebarTile(adminState, 'Orders', Icons.shopping_bag_outlined, 'orders'),
          _buildSidebarTile(adminState, 'Returns', Icons.assignment_return_outlined, 'returns'),
          _buildSidebarTile(adminState, 'Disputes', Icons.gavel_outlined, 'disputes'),
          _buildSidebarTile(adminState, 'Payments', Icons.payment_outlined, 'payments'),
          _buildSidebarTile(adminState, 'Payouts', Icons.account_balance_wallet_outlined, 'payouts'),
          _buildSidebarTile(adminState, 'Commissions', Icons.monetization_on_outlined, 'commission'),
          _buildSidebarTile(adminState, 'Promotions', Icons.campaign_outlined, 'promotions'),
          _buildSidebarTile(adminState, 'Advertising', Icons.ads_click_outlined, 'advertising'),
          _buildSidebarTile(adminState, 'Logistics', Icons.local_shipping_outlined, 'shipping'),
          _buildSidebarTile(adminState, 'Content Management', Icons.article_outlined, 'cms'),
          _buildSidebarTile(adminState, 'Reports', Icons.analytics_outlined, 'reports'),
          _buildSidebarTile(adminState, 'Security', Icons.security_outlined, 'fraud'),
          _buildSidebarTile(adminState, 'Audit Logs', Icons.history_outlined, 'audit_logs'),
          _buildSidebarTile(adminState, 'Integrations', Icons.hub_outlined, 'integrations'),
          _buildSidebarTile(adminState, 'Roles & Permissions', Icons.admin_panel_settings_outlined, 'roles'),
          _buildSidebarTile(adminState, 'System Settings', Icons.settings_outlined, 'settings'),
          _buildSidebarTile(adminState, 'Help Center', Icons.help_outline, 'support'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 6),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: SuperAdminTheme.textMuted, letterSpacing: 1),
      ),
    );
  }

  Widget _buildSidebarTile(SuperAdminProvider adminState, String title, IconData icon, String sectionId) {
    final isSelected = adminState.activeSection == sectionId;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected ? Border.all(color: const Color(0xFF10B981).withOpacity(0.3)) : null,
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: Icon(
          icon,
          size: 18,
          color: isSelected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
        onTap: () {
          adminState.setActiveSection(sectionId);
          if (MediaQuery.of(context).size.width <= 900) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildActiveModuleView(String sectionId) {
    return Consumer<AppStateProvider>(
      builder: (context, state, child) {
        switch (sectionId) {
          case 'sellers':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const SellerGovernanceScreen(),
              requiredModule: 'sellers',
              requiredAction: 'view',
            );
          case 'customers':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const CustomerManagementScreen(),
              requiredModule: 'customers',
              requiredAction: 'view',
            );
          case 'categories':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const CategoryGovernanceScreen(key: ValueKey('categories'), initialTabIndex: 0),
              requiredModule: 'catalog',
              requiredAction: 'view',
            );
          case 'brands':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const CategoryGovernanceScreen(key: ValueKey('brands'), initialTabIndex: 1),
              requiredModule: 'catalog',
              requiredAction: 'view',
            );
          case 'products':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const ProductModerationScreen(),
              requiredModule: 'catalog',
              requiredAction: 'view',
            );
          case 'orders':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const MasterOrdersScreen(),
              requiredModule: 'orders',
              requiredAction: 'view',
            );
          case 'commission':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const CommissionEngineScreen(),
              requiredModule: 'finance',
              requiredAction: 'view',
            );
          case 'payments':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const PayoutLedgerScreen(key: ValueKey('payments'), initialTabIndex: 0),
              requiredModule: 'finance',
              requiredAction: 'view',
            );
          case 'payouts':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const PayoutLedgerScreen(key: ValueKey('payouts'), initialTabIndex: 1),
              requiredModule: 'finance',
              requiredAction: 'view',
            );
          case 'returns':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const DisputeArbitrationScreen(key: ValueKey('returns'), initialTabIndex: 0),
              requiredModule: 'disputes',
              requiredAction: 'view',
            );
          case 'disputes':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const DisputeArbitrationScreen(key: ValueKey('disputes'), initialTabIndex: 1),
              requiredModule: 'disputes',
              requiredAction: 'view',
            );
          case 'shipping':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const ShippingGovernanceScreen(),
              requiredModule: 'shipping',
              requiredAction: 'view',
            );
          case 'promotions':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const PromotionsCmsScreen(key: ValueKey('promotions'), initialTabIndex: 0),
              requiredModule: 'marketing',
              requiredAction: 'view',
            );
          case 'advertising':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const PromotionsCmsScreen(key: ValueKey('advertising'), initialTabIndex: 1),
              requiredModule: 'marketing',
              requiredAction: 'view',
            );
          case 'reviews':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const ReviewsModerationScreen(),
              requiredModule: 'reviews',
              requiredAction: 'view',
            );
          case 'support':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const SupportDeskScreen(),
              requiredModule: 'support',
              requiredAction: 'view',
            );
          case 'notifications':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const NotificationsBroadcastScreen(),
              requiredModule: 'marketing',
              requiredAction: 'view',
            );
          case 'fraud':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const FraudSecurityScreen(),
              requiredModule: 'security',
              requiredAction: 'view',
            );
          case 'reports':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const AnalyticsReportsScreen(),
              requiredModule: 'analytics',
              requiredAction: 'view',
            );
          case 'cms':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const CmsContentScreen(),
              requiredModule: 'cms',
              requiredAction: 'view',
            );
          case 'integrations':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const PlatformConfigScreen(key: ValueKey('integrations'), initialTabIndex: 1),
              requiredModule: 'system',
              requiredAction: 'view',
            );
          case 'settings':
          case 'config':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const PlatformConfigScreen(key: ValueKey('settings'), initialTabIndex: 0),
              requiredModule: 'system',
              requiredAction: 'view',
            );
          case 'ai_assistant':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const AiCopilotScreen(),
              requiredModule: 'system',
              requiredAction: 'view',
            );
          case 'staff':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const AdminStaffManagementScreen(key: ValueKey('staff'), initialTabIndex: 0),
              requiredModule: 'system',
              requiredAction: 'view',
            );
          case 'roles':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const AdminStaffManagementScreen(key: ValueKey('roles'), initialTabIndex: 1),
              requiredModule: 'system',
              requiredAction: 'view',
            );
          case 'audit_logs':
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const AdminStaffManagementScreen(key: ValueKey('audit_logs'), initialTabIndex: 2),
              requiredModule: 'system',
              requiredAction: 'view',
            );
          case 'dashboard':
          default:
            return AdminAuthGuard.guardRoute(
              context: context,
              targetScreen: const ExecutiveDashboardScreen(),
              requiredModule: 'dashboard',
              requiredAction: 'view',
            );
        }
      },
    );
  }

  Widget _buildExecutiveDashboardView(AppStateProvider state) {
    final pendingCount = state.stores.where((s) => s.kycStatus == 'Pending' || !s.isApproved).length;
    final approvedCount = state.stores.where((s) => s.kycStatus == 'Approved' && s.isApproved).length;
    final totalProducts = state.products.length;
    final totalOrders = state.orders.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Welcome Header
          Card(
            color: SuperAdminTheme.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: SuperAdminTheme.borderDark)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: SuperAdminTheme.primaryTeal.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.admin_panel_settings, size: 40, color: SuperAdminTheme.secondaryGold),
                  ),
                  const SizedBox(width: 20),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Super Admin Executive Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: SuperAdminTheme.textLight)),
                        SizedBox(height: 4),
                        Text('Real-time platform metrics, merchant approvals, revenue tracking, and governance control.', style: TextStyle(fontSize: 13, color: SuperAdminTheme.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // KPI Overview Cards Grid
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
            children: [
              _buildKpiCard('Total Active Sellers', '$approvedCount Stores', Icons.storefront, Colors.teal),
              _buildKpiCard('Pending Merchant KYC', '$pendingCount Pending', Icons.pending_actions, Colors.amber),
              _buildKpiCard('Catalog Products', '$totalProducts Items', Icons.inventory_2_outlined, Colors.blue),
              _buildKpiCard('Total Platform Orders', '$totalOrders Orders', Icons.shopping_cart_outlined, Colors.purple),
            ],
          ),
          const SizedBox(height: 24),

          // Quick Action Cards
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard('Approve Merchants', Icons.check_circle_outline, () => Provider.of<SuperAdminProvider>(context, listen: false).setActiveSection('sellers')),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickActionCard('Commission Rules', Icons.monetization_on_outlined, () => Provider.of<SuperAdminProvider>(context, listen: false).setActiveSection('commission')),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickActionCard('Payout Ledger', Icons.account_balance_wallet_outlined, () => Provider.of<SuperAdminProvider>(context, listen: false).setActiveSection('payouts')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String val, IconData icon, Color color) {
    return Card(
      color: SuperAdminTheme.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: SuperAdminTheme.borderDark)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: SuperAdminTheme.textMuted, fontWeight: FontWeight.bold)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            Text(val, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: SuperAdminTheme.textLight)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(String title, IconData icon, VoidCallback onTap) {
    return Card(
      color: SuperAdminTheme.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: SuperAdminTheme.borderDark)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: SuperAdminTheme.secondaryGold, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: SuperAdminTheme.textLight)),
              ),
              const Icon(Icons.arrow_forward_ios, size: 12, color: SuperAdminTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderModule(String title, IconData icon, String desc) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Card(
        color: SuperAdminTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: SuperAdminTheme.borderDark)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 32, color: SuperAdminTheme.secondaryGold),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: SuperAdminTheme.textLight)),
                      const SizedBox(height: 4),
                      Text(desc, style: const TextStyle(fontSize: 12, color: SuperAdminTheme.textMuted)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 32, color: SuperAdminTheme.borderDark),
              const Text('Module UI & Services Framework Configured.', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              const Text('Phase Foundation ready for sub-system features implementation.', style: TextStyle(color: SuperAdminTheme.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  void _showAuditLogsModal(BuildContext context, SuperAdminProvider adminState) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: SuperAdminTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: AppBreakpoints.getResponsiveDialogWidth(context, defaultDesktopWidth: 700),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.history, color: SuperAdminTheme.secondaryGold),
                      SizedBox(width: 10),
                      Text('System Audit Trail Logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(color: SuperAdminTheme.borderDark),
              SizedBox(
                height: 350,
                child: ListView.builder(
                  itemCount: adminState.auditLogs.length,
                  itemBuilder: (context, index) {
                    final log = adminState.auditLogs[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: SuperAdminTheme.primaryTeal,
                        child: Text('${index + 1}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                      ),
                      title: Text('${log.actionType} — ${log.targetEntity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      subtitle: Text('${log.details} (${log.timestamp.toString().substring(0, 16)})', style: const TextStyle(color: SuperAdminTheme.textMuted, fontSize: 11)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
