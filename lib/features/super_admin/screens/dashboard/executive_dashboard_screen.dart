import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/admin_theme.dart';
import '../../services/super_admin_provider.dart';
import '../../../../core/services/app_state_provider.dart';

class ExecutiveDashboardScreen extends StatefulWidget {
  const ExecutiveDashboardScreen({super.key});

  @override
  State<ExecutiveDashboardScreen> createState() => _ExecutiveDashboardScreenState();
}

class _ExecutiveDashboardScreenState extends State<ExecutiveDashboardScreen> {
  String _selectedTimeRange = 'This Month'; // 'Today', 'This Week', 'This Month', 'YTD'

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateProvider>(context);
    final adminState = Provider.of<SuperAdminProvider>(context);
    final isWeb = MediaQuery.of(context).size.width > 900;

    final pendingCount = state.stores.where((s) => s.kycStatus == 'Pending' || !s.isApproved).length;
    final approvedCount = state.stores.where((s) => s.kycStatus == 'Approved' && s.isApproved).length;
    final totalProducts = state.products.length;
    final totalOrders = state.orders.length;

    // Financial Metrics Calculation
    final double gmv = state.orders.fold(0.0, (sum, o) => sum + o.productPrice);
    final double commissionRevenue = gmv * 0.10; // 10% platform commission
    final double pendingPayouts = gmv * 0.90; // 90% payable to merchants

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumbs & Header Title (Matching Panel 1)
          const Text('Breadcrumbs > Dashboard', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Executive Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
            ],
          ),
          const SizedBox(height: 20),

          // 10 Executive Metric Cards Grid (Matching Panel 1)
          GridView.count(
            crossAxisCount: isWeb ? 5 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildKpiCard('Gross Merchandise Value', 'PKR 85,230,100', '▲ PKR 85,230,100', const Color(0xFF10B981)),
              _buildKpiCard('Total Revenue', 'PKR ${gmv > 0 ? gmv.toInt() : "12,450,600"}', '▲ PKR 12,450,600', const Color(0xFF10B981)),
              _buildKpiCard('Platform Commission', 'PKR 2,150,300', '▲ PKR 2,150,300', const Color(0xFF10B981)),
              _buildKpiCard('Active Buyers', '180,450', '▲ Platform Data', const Color(0xFF3B82F6)),
              _buildKpiCard('Active Sellers', '$approvedCount', '▲ Active Stores', const Color(0xFF3B82F6)),
              _buildKpiCard('Orders Today', '$totalOrders', '▲ PKR 2,040,000', const Color(0xFF10B981)),
              _buildKpiCard('Conversion Rate', '3.2%', '▲ 3.05% Orders', const Color(0xFF10B981)),
              _buildKpiCard('Refund Rate', '1.1%', '▼ 1.1% Orders', const Color(0xFFEF4444)),
              _buildKpiCard('Pending Seller Approvals', '$pendingCount', '▼ Filed Orders', const Color(0xFFF59E0B)),
              _buildKpiCard('Open Disputes', '15', '▼ Failed Payments', const Color(0xFFEF4444)),
            ],
          ),
          const SizedBox(height: 24),

          // Analytics Charts Row (Matching Panel 1)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Revenue & Order Trend
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
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
                          const Text('Revenue & Order Trend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Text('Revenue ∨', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 160,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildBarChartItem('Jan', 0.4),
                            _buildBarChartItem('Feb', 0.55),
                            _buildBarChartItem('Mar', 0.7),
                            _buildBarChartItem('Apr', 0.65),
                            _buildBarChartItem('May', 0.85),
                            _buildBarChartItem('Jun', 0.95),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Category Performance
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Category Performance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 16),
                      _buildCategoryShareRow('Revenue', '85%', const Color(0xFF10B981)),
                      _buildCategoryShareRow('Category', '70%', const Color(0xFF3B82F6)),
                      _buildCategoryShareRow('Mairs', '55%', const Color(0xFF0EA5E9)),
                      _buildCategoryShareRow('Pantassos', '40%', const Color(0xFF14B8A6)),
                      _buildCategoryShareRow('Csowkromers', '30%', const Color(0xFF6366F1)),
                      _buildCategoryShareRow('Other', '20%', const Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // System Uptime Card
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('System Uptime', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 16),
                      _buildUptimeRow('Pending Seller', '8', '28'),
                      _buildUptimeRow('Open Disputes', '5', '15'),
                      _buildUptimeRow('Failed Payments', '3', '8'),
                      _buildUptimeRow('System Uptime', '8', '99.9%'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Geographic Order Heat Map & Critical Alerts Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Heatmap Card
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Geographic Order Heat map', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 16),
                      Container(
                        height: 220,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map_outlined, size: 48, color: Color(0xFF10B981)),
                              SizedBox(height: 8),
                              Text('Pakistan Order Distribution Heatmap', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              Text('Karachi • Lahore • Islamabad • Faisalabad • Peshawar', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Critical Alerts Card
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(20),
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
                          const Text('Critical Alerts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Text('Here ∨', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildAlertTile('Failed payment: Order #23456', '3 min ago'),
                      _buildAlertTile('Failed payment: Order #23456', '2 min ago'),
                      _buildAlertTile('Failed payment: Order #23456', '2 min ago'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Health Score Card
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Platform Health Score', style: TextStyle(fontSize: 15, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      const Text('96%', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(value: 0.96, color: Color(0xFF10B981), backgroundColor: Color(0xFFE2E8F0)),
                      const SizedBox(height: 20),
                      const Text('Quick Actions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 8),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981)),
                        title: const Text('Approvals Approvals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                        onTap: () => adminState.setActiveSection('sellers'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String val, String subtext, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              val,
              style: const TextStyle(fontSize: 20, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildUptimeRow(String title, String greenVal, String totalVal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          Row(
            children: [
              Text(greenVal, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
              const SizedBox(width: 12),
              Text(totalVal, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertTile(String title, String time) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const Text('Failed payment: order error on payment gateway.', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Text(time, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildBarChartItem(String month, double heightFactor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 28,
          height: 140 * heightFactor,
          decoration: BoxDecoration(
            color: SuperAdminTheme.primaryTeal,
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [SuperAdminTheme.primaryTeal, SuperAdminTheme.secondaryGold],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(month, style: const TextStyle(fontSize: 11, color: SuperAdminTheme.textMuted)),
      ],
    );
  }

  Widget _buildCategoryShareRow(String name, String percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
              Text(percentage, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: double.parse(percentage.replaceAll('%', '')) / 100,
            backgroundColor: SuperAdminTheme.bgDark,
            color: color,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}
