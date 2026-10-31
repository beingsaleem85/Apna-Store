import 'package:flutter/material.dart';

class SellerExecutiveDashboardScreen extends StatefulWidget {
  const SellerExecutiveDashboardScreen({super.key});

  @override
  State<SellerExecutiveDashboardScreen> createState() => _SellerExecutiveDashboardScreenState();
}

class _SellerExecutiveDashboardScreenState extends State<SellerExecutiveDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Executive Seller Dashboard'),
        backgroundColor: const Color(0xFF004D40),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dashboard Telemetry Refreshed!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today Sales & Net Earnings Row
            Row(
              children: [
                _buildSummaryCard("Today's Gross Sales", "Rs. 45,200", "18 Orders Today", Colors.amber.shade800),
                const SizedBox(width: 12),
                _buildSummaryCard("Net Payable Earnings", "Rs. 40,680", "10% Commission Deducted", const Color(0xFF004D40)),
                const SizedBox(width: 12),
                _buildSummaryCard("Pending Orders Action", "4 Orders", "SLA: Pack within 12h", Colors.redAccent),
              ],
            ),
            const SizedBox(height: 24),

            // Order Status Pipeline Grid
            const Text('Order Fulfillment Pipeline Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Row(
              children: [
                _buildPipelineBadge('New Pending', '4', Colors.orange),
                const SizedBox(width: 8),
                _buildPipelineBadge('Processing', '6', Colors.blue),
                const SizedBox(width: 8),
                _buildPipelineBadge('Ready to Ship', '3', Colors.purple),
                const SizedBox(width: 8),
                _buildPipelineBadge('Delivered', '85', Colors.green),
                const SizedBox(width: 8),
                _buildPipelineBadge('Cancelled', '2', Colors.red),
                const SizedBox(width: 8),
                _buildPipelineBadge('Returns', '1', Colors.grey),
              ],
            ),
            const SizedBox(height: 24),

            // Performance & Health Meters Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Store Performance & Response Rate Metrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricMeter('Chat Response Rate', '98%', Colors.green),
                        _buildMetricMeter('Shipping Response Rate', '96%', Colors.green),
                        _buildMetricMeter('Cancellation Rate', '1.2%', Colors.green),
                        _buildMetricMeter('Account Health Score', '95 / 100', const Color(0xFF004D40)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Low Stock & Out of Stock Alert Card
            Card(
              color: Colors.red.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Inventory Low Stock & Out of Stock Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    const ListTile(
                      dense: true,
                      leading: Icon(Icons.inventory_2_outlined, color: Colors.orange),
                      title: Text('Embroidered Lawn Unstitched 3-Piece', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('SKU: LAWN-2026-BLK'),
                      trailing: Text('2 Units Left', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                    const Divider(),

                    const ListTile(
                      dense: true,
                      leading: Icon(Icons.error_outline, color: Colors.red),
                      title: Text('Men Leather Jacket Winter Special', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('SKU: JKT-LTHR-BRN'),
                      trailing: Text('OUT OF STOCK', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, String sub, Color color) {
    return Expanded(
      child: Card(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text(sub, style: const TextStyle(fontSize: 10, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPipelineBadge(String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricMeter(String title, String val, Color color) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }
}
