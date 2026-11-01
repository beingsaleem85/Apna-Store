import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';
import '../../../../core/services/app_state_provider.dart';

class CommissionRule {
  final String id;
  String categoryName;
  double commissionRate;
  double minOrderAmount;

  CommissionRule({
    required this.id,
    required this.categoryName,
    required this.commissionRate,
    required this.minOrderAmount,
  });
}

class CommissionEngineScreen extends StatefulWidget {
  const CommissionEngineScreen({super.key});

  @override
  State<CommissionEngineScreen> createState() => _CommissionEngineScreenState();
}

class _CommissionEngineScreenState extends State<CommissionEngineScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  double _globalCommissionRate = 10.0;
  final TextEditingController _searchController = TextEditingController();

  final List<CommissionRule> _rules = [
    CommissionRule(id: 'RULE-CAT-01', categoryName: 'Fashion & Apparel', commissionRate: 12.0, minOrderAmount: 0.0),
    CommissionRule(id: 'RULE-CAT-02', categoryName: 'Mobiles & Electronics', commissionRate: 5.0, minOrderAmount: 0.0),
    CommissionRule(id: 'RULE-CAT-03', categoryName: 'Groceries & Household', commissionRate: 3.5, minOrderAmount: 0.0),
    CommissionRule(id: 'RULE-CAT-04', categoryName: 'Home & Living', commissionRate: 8.0, minOrderAmount: 0.0),
    CommissionRule(id: 'RULE-CAT-05', categoryName: 'Health & Beauty', commissionRate: 10.0, minOrderAmount: 0.0),
    CommissionRule(id: 'RULE-CAT-06', categoryName: 'Automotive & Tools', commissionRate: 7.5, minOrderAmount: 0.0),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchCommissionRules();
  }

  Future<void> _fetchCommissionRules() async {
    try {
      final res = await Supabase.instance.client
          .from('commission_rules')
          .select()
          .order('category_name');
      if (res.isNotEmpty && mounted) {
        setState(() {
          _rules.clear();
          for (final r in res) {
            _rules.add(CommissionRule(
              id: r['id'].toString(),
              categoryName: r['category_name'].toString(),
              commissionRate: ((r['commission_rate'] as num?) ?? 10.0).toDouble(),
              minOrderAmount: ((r['min_order_amount'] as num?) ?? 0.0).toDouble(),
            ));
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final adminState = Provider.of<SuperAdminProvider>(context);

    // Platform Revenue Analytics Calculation
    final double totalGmv = appState.orders.fold(0.0, (sum, o) => sum + o.productPrice);
    final double totalCommissionEarned = appState.orders.fold(0.0, (sum, o) => sum + o.commissionDeducted);
    final double netMerchantPayable = totalGmv - totalCommissionEarned;

    // Filter Stores for Merchant Directory
    final filteredStores = appState.stores.where((s) {
      final name = s.shopName.toLowerCase();
      final owner = (s.fullName ?? s.businessName ?? '').toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || owner.contains(_searchQuery.toLowerCase());
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumbs & Header
          const Text('Breadcrumbs > Finance > Commission Engine', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Commission & Revenue Engine', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download, size: 16),
                    onPressed: () {
                      SuperAdminDialogs.showToast(context, 'Exporting commission & fee ledgers to CSV...');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    label: const Text('Export Ledger', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: () => _showAddRuleModal(adminState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    label: const Text('Add Category Rule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4 Revenue Metric Cards
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showEditGlobalRateModal(adminState),
                  child: _buildMetricCard(
                    title: 'Global Default Take-Rate',
                    value: '$_globalCommissionRate%',
                    subtitle: 'Click to Edit Rate ✏️',
                    icon: Icons.percent_rounded,
                    iconColor: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Platform Fee Collected',
                  value: 'PKR ${totalCommissionEarned.toInt()}',
                  subtitle: 'Earned Marketplace Revenue',
                  icon: Icons.monetization_on_outlined,
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Gross Platform GMV',
                  value: 'PKR ${totalGmv.toInt()}',
                  subtitle: 'Total Marketplace Sales',
                  icon: Icons.bar_chart_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFF3E8FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Net Merchant Payable',
                  value: 'PKR ${netMerchantPayable.toInt()}',
                  subtitle: 'Pending Payouts Queue',
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Feature Sub-Tabs
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF334155),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.category_outlined, size: 18), text: 'Category-Level Tier Rules'),
                Tab(icon: Icon(Icons.storefront_outlined, size: 18), text: 'Merchant-Wise Commission Directory (All Sellers)'),
                Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Order Fee Audit Ledger'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Views
          SizedBox(
            height: 520,
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Category Rules
                _buildCategoryRulesTab(adminState),

                // TAB 2: Merchant Directory (ALL SELLERS SHOWN HERE)
                _buildMerchantDirectoryTab(filteredStores, adminState),

                // TAB 3: Order Fee Ledger
                _buildOrderFeeLedgerTab(appState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: CATEGORY RULES ---
  Widget _buildCategoryRulesTab(SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Category-Level Commission Tier Rules', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text('${_rules.length} Rules Configured', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Category Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Commission Rate (%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Min Order Threshold', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: _rules.length,
                itemBuilder: (ctx, i) {
                  final rule = _rules[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                                child: const Icon(Icons.category, size: 16, color: Color(0xFF2563EB)),
                              ),
                              const SizedBox(width: 10),
                              Text(rule.categoryName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                              child: Text('${rule.commissionRate}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(rule.minOrderAmount == 0.0 ? 'No Min (Rs. 0)' : 'Rs. ${rule.minOrderAmount.toInt()}', style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
                        ),
                        Expanded(
                          child: IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 18),
                            onPressed: () => _showEditRuleModal(rule, adminState),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 2: ALL SELLERS DIRECTORY ---
  Widget _buildMerchantDirectoryTab(List<AppStore> stores, SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('All Registered Merchants & Individual Commission Take-Rates', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text('${stores.length} Sellers Listed', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Merchant Store & Owner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Assigned Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Available Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Pending Payout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(child: Text('Edit Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: stores.length,
                itemBuilder: (ctx, i) {
                  final store = stores[i];
                  final owner = store.fullName ?? store.businessName ?? 'Merchant';
                  final isCustom = store.commissionRate != 10.0;
                  final availableBalance = store.balance;
                  final pendingPayout = store.pendingPayout;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        // Store info
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFF0F172A),
                                child: Text(store.shopName.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(store.shopName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text('Owner: $owner', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Assigned Rate
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCustom ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${store.commissionRate}% ${isCustom ? "(Custom Deal)" : "(Standard)"}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isCustom ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Available Balance
                        Expanded(
                          flex: 2,
                          child: Text('PKR ${availableBalance.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 12)),
                        ),

                        // Pending Payout
                        Expanded(
                          flex: 2,
                          child: Text('PKR ${pendingPayout.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 12)),
                        ),

                        // Edit Rate Button
                        Expanded(
                          child: IconButton(
                            icon: const Icon(Icons.edit_note, color: Color(0xFF2563EB), size: 22),
                            tooltip: 'Customize Commission for ${store.shopName}',
                            onPressed: () => _showEditStoreRateModal(store, adminState),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 3: ORDER FEE LEDGER ---
  Widget _buildOrderFeeLedgerTab(AppStateProvider appState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Live Order-by-Order Commission Deduction Ledger', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text('${appState.orders.length} Processed Orders', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('Order ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 3, child: Text('Product & Seller', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Sale Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Platform Fee Cut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Seller Net Payout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: appState.orders.length,
                itemBuilder: (ctx, i) {
                  final o = appState.orders[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text('#${o.id}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 13)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.productName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('Seller: ${o.sellerId}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('PKR ${o.productPrice.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 12)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('PKR ${o.commissionDeducted.toInt()} (10%)', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 12)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('PKR ${o.finalPayout.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditGlobalRateModal(SuperAdminProvider adminState) async {
    final controller = TextEditingController(text: _globalCommissionRate.toString());
    try {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Edit Global Default Commission Rate', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This percentage is deducted from every sale across the platform as marketplace revenue.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Global Commission Take-Rate (%)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () {
                final newRate = double.tryParse(controller.text);
                if (newRate != null) {
                  if (mounted) setState(() => _globalCommissionRate = newRate);
                  adminState.logAuditAction('COMMISSION_GLOBAL_UPDATE', 'Global Rate', 'Updated global default commission rate to $newRate%.');
                  Navigator.pop(ctx);
                  if (mounted) SuperAdminDialogs.showToast(context, 'Global Commission Rate Updated to $newRate%');
                }
              },
              child: const Text('Save Rate'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  void _showEditRuleModal(CommissionRule rule, SuperAdminProvider adminState) async {
    final controller = TextEditingController(text: rule.commissionRate.toString());
    try {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Edit Commission — ${rule.categoryName}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Set specific commission percentage for all products under ${rule.categoryName}.', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Category Commission Rate (%)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () async {
                final newRate = double.tryParse(controller.text);
                if (newRate != null) {
                  if (mounted) setState(() => rule.commissionRate = newRate);
                  try {
                    await Supabase.instance.client.rpc('admin_update_commission_rule', params: {
                      'p_category_name': rule.categoryName,
                      'p_rate': newRate,
                      'p_min_order': rule.minOrderAmount,
                    });
                  } catch (_) {}
                  adminState.logAuditAction('COMMISSION_RULE_UPDATE', rule.categoryName, 'Updated category commission rate to $newRate%.');
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) SuperAdminDialogs.showToast(context, 'Category Rate Updated!');
                }
              },
              child: const Text('Save Rate'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  void _showAddRuleModal(SuperAdminProvider adminState) async {
    final catController = TextEditingController();
    final rateController = TextEditingController(text: '10.0');
    try {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Add New Category Commission Rule', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: catController,
                style: const TextStyle(color: Color(0xFF0F172A)),
                decoration: const InputDecoration(labelText: 'Category Name (e.g. Sports & Fitness)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                decoration: const InputDecoration(labelText: 'Commission Rate (%)', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () {
                final catName = catController.text.trim();
                final rate = double.tryParse(rateController.text.trim());
                if (catName.isNotEmpty && rate != null) {
                  setState(() {
                    _rules.add(CommissionRule(id: 'RULE-CAT-0${_rules.length + 1}', categoryName: catName, commissionRate: rate, minOrderAmount: 0.0));
                  });
                  adminState.logAuditAction('COMMISSION_RULE_ADD', catName, 'Added new category rule: $rate%');
                  Navigator.pop(ctx);
                  SuperAdminDialogs.showToast(context, 'Category rule for $catName added successfully!');
                }
              },
              child: const Text('Add Rule'),
            ),
          ],
        ),
      );
    } finally {
      catController.dispose();
      rateController.dispose();
    }
  }

  void _showEditStoreRateModal(AppStore store, SuperAdminProvider adminState) async {
    final controller = TextEditingController(text: store.commissionRate.toString());
    try {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Custom Deal — ${store.shopName}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Set custom commission percentage for ${store.shopName}. All future sales from this merchant will be charged this specific rate.', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Custom Commission Rate (%)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () {
                final newRate = double.tryParse(controller.text);
                if (newRate != null) {
                  if (mounted) setState(() => store.commissionRate = newRate);
                  adminState.logAuditAction('STORE_COMMISSION_OVERRIDE', store.shopName, 'Updated custom rate to $newRate%.');
                  Navigator.pop(ctx);
                  if (mounted) SuperAdminDialogs.showToast(context, 'Custom Commission for ${store.shopName} updated to $newRate%!');
                }
              },
              child: const Text('Save Custom Deal'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }
}
