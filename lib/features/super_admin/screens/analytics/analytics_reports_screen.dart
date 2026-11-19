import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';
import '../../../../core/services/app_state_provider.dart';

class CategorySalesData {
  final String categoryName;
  final double gmvShare;
  final int totalOrders;
  final double revenue;
  final double returnRate;

  CategorySalesData({
    required this.categoryName,
    required this.gmvShare,
    required this.totalOrders,
    required this.revenue,
    required this.returnRate,
  });
}

class AnalyticsReportsScreen extends StatefulWidget {
  const AnalyticsReportsScreen({super.key});

  @override
  State<AnalyticsReportsScreen> createState() => _AnalyticsReportsScreenState();
}

class _AnalyticsReportsScreenState extends State<AnalyticsReportsScreen> {
  String _selectedPeriod = 'This Month'; // 'Today', 'This Week', 'This Month', 'This Year'

  final List<CategorySalesData> _categoryBreakdown = [
    CategorySalesData(categoryName: 'Fashion & Apparel', gmvShare: 0.42, totalOrders: 340, revenue: 40803.0, returnRate: 4.2),
    CategorySalesData(categoryName: 'Mobiles & Electronics', gmvShare: 0.30, totalOrders: 185, revenue: 29145.0, returnRate: 2.1),
    CategorySalesData(categoryName: 'Groceries & Household', gmvShare: 0.18, totalOrders: 210, revenue: 17487.0, returnRate: 0.8),
    CategorySalesData(categoryName: 'Home & Living', gmvShare: 0.06, totalOrders: 65, revenue: 5829.0, returnRate: 3.5),
    CategorySalesData(categoryName: 'Health & Beauty Care', gmvShare: 0.03, totalOrders: 42, revenue: 2914.0, returnRate: 1.2),
    CategorySalesData(categoryName: 'Automotive & Motorcycle Accessories', gmvShare: 0.01, totalOrders: 15, revenue: 972.0, returnRate: 1.8),
  ];

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final adminState = Provider.of<SuperAdminProvider>(context);

    // Calculate Platform Financial Totals based on Selected Time Horizon
    double periodMultiplier = 1.0;
    String periodBadge = 'Current Month Aggregate';
    if (_selectedPeriod == 'Today') {
      periodMultiplier = 0.05; // ~5% for daily
      periodBadge = 'Live Today (24 Hours)';
    } else if (_selectedPeriod == 'This Week') {
      periodMultiplier = 0.25; // ~25% for 7 days
      periodBadge = 'Last 7 Days Rolling';
    } else if (_selectedPeriod == 'This Month') {
      periodMultiplier = 1.0;
      periodBadge = 'August 2026 MTD';
    } else if (_selectedPeriod == 'This Year') {
      periodMultiplier = 12.2; // Annual
      periodBadge = 'Full Year 2026 YTD';
    }

    final double grossGmv = appState.orders.fold(0.0, (sum, o) => sum + o.productPrice);
    final double platformCommission = appState.orders.fold(0.0, (sum, o) => sum + o.commissionDeducted);
    final double salesTaxFbr = platformCommission * 0.18; // 18% Sales Tax on Platform Commission
    final double withholdingTax = grossGmv * 0.02; // 2% WHT on Gross Marketplace Sales

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Executive Breadcrumb & Header
          const Text('Breadcrumbs > Reports > Analytics & Tax Center', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Analytics, Tax & Export Center', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('Financial intelligence, Pakistani FBR/PRA tax compliance, and automated ledger exports.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    onPressed: () => _showFbrTaxReportModal(grossGmv, platformCommission, salesTaxFbr, withholdingTax, adminState),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    label: const Text('FBR Tax Compliance Audit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.table_view_rounded, size: 16),
                    onPressed: () => _showExportLedgerModal(adminState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    label: const Text('Export Excel Ledger', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Period Filter Bar
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text('Report Horizon: $_selectedPeriod', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  Row(
                    children: ['Today', 'This Week', 'This Month', 'This Year'].map((period) {
                      final isSel = _selectedPeriod == period;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: ChoiceChip(
                          label: Text(period, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : const Color(0xFF64748B))),
                          selected: isSel,
                          selectedColor: const Color(0xFF0F172A),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onSelected: (val) => setState(() => _selectedPeriod = period),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Financial & Tax Summary Metrics Grid
          Row(
            children: [
              _buildMetricCard(
                title: 'Gross Platform GMV',
                value: 'Rs. ${grossGmv.toInt()}',
                sub: periodBadge,
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFF2563EB),
                bgColor: const Color(0xFFEFF6FF),
              ),
              const SizedBox(width: 14),
              _buildMetricCard(
                title: 'Platform Net Commission',
                value: 'Rs. ${platformCommission.toInt()}',
                sub: 'Platform fee income',
                icon: Icons.monetization_on_outlined,
                iconColor: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
              ),
              const SizedBox(width: 14),
              _buildMetricCard(
                title: 'FBR Sales Tax (18%)',
                value: 'Rs. ${salesTaxFbr.toInt()}',
                sub: 'Federal tax on commission',
                icon: Icons.receipt_long_outlined,
                iconColor: const Color(0xFF7C3AED),
                bgColor: const Color(0xFFF3E8FF),
              ),
              const SizedBox(width: 14),
              _buildMetricCard(
                title: 'Withholding Tax (2%)',
                value: 'Rs. ${withholdingTax.toInt()}',
                sub: 'WHT on merchant sales',
                icon: Icons.account_balance_outlined,
                iconColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFEF3C7),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2-Column Row: Data Export Desk + Provincial Tax Authorities
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Data Export & Compliance Desk (Flex 7)
              Expanded(
                flex: 7,
                child: Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Data Export & Compliance Audit Desk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 4),
                        const Text('Download official CSV and Excel reports for bank reconciliation, FBR tax filing, and auditing.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        const SizedBox(height: 16),

                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildExportButton(
                              icon: Icons.download_for_offline_outlined,
                              label: 'Export Master Orders (CSV)',
                              onPressed: () {
                                adminState.logAuditAction('EXPORT_ORDERS', 'Orders Dataset', 'Exported orders CSV report.');
                                SuperAdminDialogs.showToast(context, 'Exporting Master Orders CSV (342 Records)...');
                              },
                            ),
                            _buildExportButton(
                              icon: Icons.storefront_outlined,
                              label: 'Export Merchant Directory (CSV)',
                              onPressed: () {
                                adminState.logAuditAction('EXPORT_SELLERS', 'Sellers Dataset', 'Exported sellers directory CSV report.');
                                SuperAdminDialogs.showToast(context, 'Exporting Sellers Directory CSV (56 Merchants)...');
                              },
                            ),
                            _buildExportButton(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Export Settlement Payout Ledger',
                              onPressed: () {
                                adminState.logAuditAction('EXPORT_PAYOUTS', 'Payouts Dataset', 'Exported payouts ledger CSV report.');
                                SuperAdminDialogs.showToast(context, 'Exporting Payouts Ledger CSV (Rs. 1.25M Disbursed)...');
                              },
                            ),
                            _buildExportButton(
                              icon: Icons.receipt_long_outlined,
                              label: 'Export FBR Sales Tax Report (PDF)',
                              onPressed: () {
                                adminState.logAuditAction('EXPORT_TAX_LOG', 'FBR Tax Report', 'Exported FBR tax PDF report.');
                                SuperAdminDialogs.showToast(context, 'Generating FBR Annexure-C Tax Audit PDF...');
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Right: Provincial Tax Authority Breakdown (Flex 5)
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.gavel_rounded, color: Color(0xFF2563EB), size: 18),
                          SizedBox(width: 8),
                          Text('Pakistani Revenue Authorities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildTaxRow('Federal (FBR Sales Tax)', '18.0%', 'National E-Commerce'),
                      _buildTaxRow('Punjab (PRA Punjab)', '16.0%', 'Lahore & Metro Hubs'),
                      _buildTaxRow('Sindh (SRB Sindh)', '13.0%', 'Karachi Digital Goods'),
                      _buildTaxRow('KPK (KPRA Authority)', '15.0%', 'Peshawar & Northern'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Category Revenue Share & Growth Breakdown
          Card(
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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Top Categories GMV Performance Share', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text('Top revenue generating root categories vs aggregated miscellaneous catalog.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.list_alt_rounded, size: 16),
                        label: const Text('View All Categories Drilldown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => _showAllCategoriesModal(grossGmv),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _buildCategoryProgressRow('Fashion & Apparel', 0.42, '42% Share (Rs. ${(grossGmv * 0.42).toInt()})', const Color(0xFF2563EB)),
                  const SizedBox(height: 14),
                  _buildCategoryProgressRow('Mobiles & Electronics', 0.30, '30% Share (Rs. ${(grossGmv * 0.30).toInt()})', const Color(0xFF10B981)),
                  const SizedBox(height: 14),
                  _buildCategoryProgressRow('Groceries & Household', 0.18, '18% Share (Rs. ${(grossGmv * 0.18).toInt()})', const Color(0xFFD97706)),
                  const SizedBox(height: 14),
                  _buildCategoryProgressRow('Home & Living', 0.06, '6% Share (Rs. ${(grossGmv * 0.06).toInt()})', const Color(0xFF7C3AED)),
                  const SizedBox(height: 14),
                  _buildCategoryProgressRow('Other Catalog Sub-Categories (Combined 100+)', 0.04, '4% Share (Rs. ${(grossGmv * 0.04).toInt()})', const Color(0xFF64748B)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxRow(String authority, String rate, String jurisdiction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(authority, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                child: Text(rate, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ),
              const SizedBox(width: 6),
              Text(jurisdiction, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton({required IconData icon, required String label, required VoidCallback onPressed}) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildCategoryProgressRow(String category, double pct, String label, Color barColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(category, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13)),
            Text(label, style: TextStyle(color: barColor, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // MODALS WITH CLEAN LIGHT THEME (NO CONTRAST BUGS)
  // ==========================================
  void _showFbrTaxReportModal(double gmv, double comm, double salesTax, double wht, SuperAdminProvider adminState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 24),
            SizedBox(width: 10),
            Text('FBR Sales Tax & WHT Compliance Audit', style: TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Official Pakistani Tax Ledger for Annexure-C Monthly Filing.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  children: [
                    _buildModalSummaryRow('Gross Marketplace GMV', 'PKR ${gmv.toInt()}'),
                    const Divider(height: 16),
                    _buildModalSummaryRow('Platform Commission Income', 'PKR ${comm.toInt()}'),
                    const Divider(height: 16),
                    _buildModalSummaryRow('FBR 18% Output Sales Tax', 'PKR ${salesTax.toInt()}'),
                    const Divider(height: 16),
                    _buildModalSummaryRow('Section 236G/H WHT (2% Gross)', 'PKR ${wht.toInt()}'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('NTN: 8941029-4 • STRN: 3277876129841 • Registered: Lahore RTO', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton.icon(
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Download FBR Tax Return (PDF)'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () {
              adminState.logAuditAction('FBR_PDF_DOWNLOAD', 'Tax Center', 'Downloaded FBR Annexure-C Tax Return PDF.');
              Navigator.pop(ctx);
              SuperAdminDialogs.showToast(context, 'FBR Tax Return PDF Generated and Downloaded!');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModalSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showExportLedgerModal(SuperAdminProvider adminState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.table_view_rounded, color: Color(0xFF059669), size: 24),
            SizedBox(width: 10),
            Text('Export Master Financial Ledger', style: TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select datasets to include in the Excel multi-sheet workbook:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            SizedBox(height: 14),
            ListTile(
              dense: true,
              leading: Icon(Icons.check_box_rounded, color: Color(0xFF059669)),
              title: Text('Sheet 1: Master Customer Orders & Payment Gateway Transactions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              dense: true,
              leading: Icon(Icons.check_box_rounded, color: Color(0xFF059669)),
              title: Text('Sheet 2: Merchant Payout Balances & Bank Disbursals', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              dense: true,
              leading: Icon(Icons.check_box_rounded, color: Color(0xFF059669)),
              title: Text('Sheet 3: FBR Sales Tax & 2% Withholding Tax Annexure', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton.icon(
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: const Text('Download .XLSX Workbook'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            onPressed: () {
              adminState.logAuditAction('EXCEL_LEDGER_EXPORT', 'Master Ledger', 'Exported full 3-sheet financial workbook.');
              Navigator.pop(ctx);
              SuperAdminDialogs.showToast(context, 'Master Financial Ledger (.XLSX) Downloaded Successfully!');
            },
          ),
        ],
      ),
    );
  }

  void _showAllCategoriesModal(double grossGmv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.category_outlined, color: Color(0xFF2563EB), size: 24),
            SizedBox(width: 10),
            Text('Complete Category Catalog Sales Drilldown', style: TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 650,
          height: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Detailed performance metrics for all catalog root categories and sub-branches.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 12),

              // Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('Category Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                    Expanded(flex: 2, child: Text('Share (%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                    Expanded(flex: 2, child: Text('Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                    Expanded(flex: 2, child: Text('GMV (PKR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                    Expanded(flex: 2, child: Text('Return SLA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              Expanded(
                child: ListView.builder(
                  itemCount: _categoryBreakdown.length,
                  itemBuilder: (context, index) {
                    final item = _categoryBreakdown[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text(item.categoryName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
                          Expanded(flex: 2, child: Text('${(item.gmvShare * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 12))),
                          Expanded(flex: 2, child: Text('${item.totalOrders} Orders', style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
                          Expanded(flex: 2, child: Text('PKR ${(grossGmv * item.gmvShare).toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 12))),
                          Expanded(flex: 2, child: Text('${item.returnRate}%', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
