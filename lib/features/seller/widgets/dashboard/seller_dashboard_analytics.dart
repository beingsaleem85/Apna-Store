import 'package:flutter/material.dart';
import '../../../../core/services/app_state_provider.dart';

// 1. Executive Store Traffic & Conversion Performance Desk
class SellerPerformanceSummarySection extends StatelessWidget {
  final AppStateProvider state;
  final AppStore store;
  final String activeSellerId;

  const SellerPerformanceSummarySection({
    super.key,
    required this.state,
    required this.store,
    required this.activeSellerId,
  });

  Widget _buildKpiBox(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelRow(String channel, String count, double pct, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(channel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              Text(count, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Store Traffic & Conversion Performance Desk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Track store visitor traffic, page impression rates, add-to-cart conversions, and search funnel metrics.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Performance Traffic Report PDF downloaded!'), backgroundColor: Color(0xFF059669)),
                  );
                },
                icon: const Icon(Icons.download_outlined, size: 14),
                label: const Text('Export Traffic PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: count,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                children: [
                  _buildKpiBox('Store Visitors (30d)', '14,250 Visitors', Icons.people_outline, const Color(0xFF0284C7)),
                  _buildKpiBox('Product Page Views', '48,900 Impressions', Icons.visibility_outlined, const Color(0xFF7C3AED)),
                  _buildKpiBox('Add-To-Cart Rate', '14.5% Rate', Icons.shopping_cart_outlined, const Color(0xFF059669)),
                  _buildKpiBox('Checkout Conversion', '3.2% Conversion', Icons.speed_outlined, const Color(0xFFB45309)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Traffic Source Channels Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Buyer Traffic Source & Acquisition Funnel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 14),
                _buildChannelRow('Organic Search & Marketplace Browsing', '6,800 Visitors (47.7%)', 0.477, const Color(0xFF059669)),
                _buildChannelRow('Apna Store Homepage Recommendation', '4,200 Visitors (29.5%)', 0.295, const Color(0xFF0284C7)),
                _buildChannelRow('Social Media & Direct Links', '2,100 Visitors (14.7%)', 0.147, const Color(0xFF7C3AED)),
                _buildChannelRow('Sponsored Product Ads (CPC)', '1,150 Visitors (8.1%)', 0.081, const Color(0xFFEA580C)),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Category Conversion Performance Table
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Category Level Conversion Performance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 14),

                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Expanded(flex: 3, child: Text('CATEGORY NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('PAGE VIEWS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('ADD TO CART', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('PURCHASES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('CONVERSION RATE', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Rows
                _buildCategoryRow("Men's Fashion & Kurtas", "18,400 Views", "2,800 Carts", "840 Orders", "4.56%"),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _buildCategoryRow("Electronics & Earbuds", "14,200 Views", "1,950 Carts", "420 Orders", "2.95%"),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _buildCategoryRow("Women's Unstitched Lawn", "10,800 Views", "1,400 Carts", "380 Orders", "3.51%"),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _buildCategoryRow("Footwear & Leather Shoes", "5,500 Views", "650 Carts", "190 Orders", "3.45%"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(String cat, String views, String carts, String orders, String conv) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(cat, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
          Expanded(flex: 2, child: Text(views, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
          Expanded(flex: 2, child: Text(carts, style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text(orders, style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text(conv, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
        ],
      ),
    );
  }
}

// 2. Executive Financial Sales & Revenue Statement Desk
class SellerSalesReportsSection extends StatelessWidget {
  final AppStateProvider state;
  final AppStore store;
  final String activeSellerId;

  const SellerSalesReportsSection({
    super.key,
    required this.state,
    required this.store,
    required this.activeSellerId,
  });

  Widget _buildKpiBox(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Financial Sales & Revenue Statement Desk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Analyze total gross revenue, marketplace commission deductions, coupon discounts, and net payouts.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Monthly Financial Statement exported to CSV!'), backgroundColor: Color(0xFF059669)),
                  );
                },
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export Statement CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: count,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                children: [
                  _buildKpiBox('Gross Sales Revenue', 'PKR 485,000 Gross', Icons.payments_outlined, const Color(0xFF0284C7)),
                  _buildKpiBox('Net Seller Payout', 'PKR 436,500 Net', Icons.account_balance_wallet_outlined, const Color(0xFF059669)),
                  _buildKpiBox('Platform Fee (5%)', 'PKR 24,250 Deducted', Icons.receipt_long_outlined, const Color(0xFFB45309)),
                  _buildKpiBox('Voucher Discounts', 'PKR 24,250 Coupons', Icons.local_offer_outlined, const Color(0xFF7C3AED)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Monthly Financial Statement Data Table
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Monthly Sales & Payout Settlement History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 14),

                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Expanded(flex: 3, child: Text('BILLING PERIOD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)))),
                      Expanded(flex: 2, child: Text('GROSS SALES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)))),
                      Expanded(flex: 2, child: Text('FEE (5%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)))),
                      Expanded(flex: 2, child: Text('DISCOUNTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)))),
                      Expanded(flex: 2, child: Text('NET PAYOUT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)))),
                      Expanded(flex: 2, child: Text('SETTLEMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)))),
                      Expanded(flex: 2, child: Text('STATEMENT', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)))),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Monthly Statement Rows
                _buildStatementRow(context, 'August 2026 (Active)', 'PKR 148,000', 'PKR 7,400', 'PKR 3,200', 'PKR 137,400', 'Processing', false),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _buildStatementRow(context, 'July 2026', 'PKR 185,000', 'PKR 9,250', 'PKR 4,500', 'PKR 171,250', 'Settled & Paid', true),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _buildStatementRow(context, 'June 2026', 'PKR 152,000', 'PKR 7,600', 'PKR 3,800', 'PKR 140,600', 'Settled & Paid', true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementRow(BuildContext context, String period, String gross, String fee, String disc, String net, String status, bool isSettled) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(period, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
          Expanded(flex: 2, child: Text(gross, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)))),
          Expanded(flex: 2, child: Text(fee, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
          Expanded(flex: 2, child: Text(disc, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
          Expanded(flex: 2, child: Text(net, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)))),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSettled ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSettled ? const Color(0xFF059669) : const Color(0xFF2563EB),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Downloading statement PDF for $period...'), backgroundColor: const Color(0xFF059669)),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  child: const Text('PDF', style: TextStyle(fontSize: 10, color: Color(0xFF334155))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
