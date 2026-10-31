import 'package:flutter/material.dart';

class SponsoredKeywordItem {
  final String keyword;
  double cpcBid;
  int clicks;
  int conversions;
  double spend;
  double revenue;

  SponsoredKeywordItem({
    required this.keyword,
    required this.cpcBid,
    required this.clicks,
    required this.conversions,
    required this.spend,
    required this.revenue,
  });

  double get roas => spend > 0 ? (revenue / spend) : 0.0;
}

class SellerAdvertisingCampaignScreen extends StatefulWidget {
  const SellerAdvertisingCampaignScreen({super.key});

  @override
  State<SellerAdvertisingCampaignScreen> createState() => _SellerAdvertisingCampaignScreenState();
}

class _SellerAdvertisingCampaignScreenState extends State<SellerAdvertisingCampaignScreen> {
  final TextEditingController _dailyBudgetController = TextEditingController(text: '500');

  final List<SponsoredKeywordItem> _keywords = [
    SponsoredKeywordItem(keyword: 'Unstitched Lawn Suit', cpcBid: 4.5, clicks: 450, conversions: 22, spend: 2025.0, revenue: 65978.0),
    SponsoredKeywordItem(keyword: 'Men Leather Jacket', cpcBid: 6.0, clicks: 300, conversions: 12, spend: 1800.0, revenue: 54000.0),
  ];

  @override
  void dispose() {
    _dailyBudgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Total Telemetry Math
    final double totalSpend = _keywords.fold(0.0, (sum, k) => sum + k.spend);
    final double totalRevenue = _keywords.fold(0.0, (sum, k) => sum + k.revenue);
    final double overallRoas = totalSpend > 0 ? (totalRevenue / totalSpend) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sponsored Ads & Keyword Bidding Studio'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ROAS Telemetry Summary Card
            Card(
              color: const Color(0xFF004D40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.campaign, color: Color(0xFFFDB913), size: 28),
                        SizedBox(width: 12),
                        Text('Campaign Performance & ROAS Telemetry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTelemetryItem('Total Ad Spend', 'Rs. ${totalSpend.toInt()}', Colors.white),
                        _buildTelemetryItem('Ad Revenue Generated', 'Rs. ${totalRevenue.toInt()}', Colors.greenAccent),
                        _buildTelemetryItem('Return on Ad Spend (ROAS)', '${overallRoas.toStringAsFixed(1)}x ROAS', const Color(0xFFFDB913)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Daily Budget Manager
            const Text('Campaign Budget Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dailyBudgetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Daily Budget Limit (Rs.)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Update Budget Limit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004D40),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Daily Ad Budget Limit Updated!')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Keyword Search Bidding Studio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Sponsored Search Keyword Bidding Matrix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Bid on New Keyword'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                  onPressed: () => _showAddKeywordModal(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _keywords.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final k = _keywords[index];

                  return ListTile(
                    leading: const Icon(Icons.search, color: Color(0xFF004D40)),
                    title: Text(k.keyword, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Max CPC: Rs. ${k.cpcBid} | Clicks: ${k.clicks} | Orders: ${k.conversions}', style: const TextStyle(fontSize: 11)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${k.roas.toStringAsFixed(1)}x ROAS', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('Spend: Rs. ${k.spend.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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

  Widget _buildTelemetryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  void _showAddKeywordModal() {
    final TextEditingController kwCtrl = TextEditingController();
    final TextEditingController cpcCtrl = TextEditingController(text: '5.0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bid on Search Keyword', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: kwCtrl,
              decoration: const InputDecoration(labelText: 'Search Keyword (e.g. Lawn 3-Piece)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cpcCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Max Cost Per Click Bid (Rs.)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
            onPressed: () {
              if (kwCtrl.text.isNotEmpty) {
                setState(() {
                  _keywords.add(SponsoredKeywordItem(
                    keyword: kwCtrl.text,
                    cpcBid: double.tryParse(cpcCtrl.text) ?? 5.0,
                    clicks: 0,
                    conversions: 0,
                    spend: 0.0,
                    revenue: 0.0,
                  ));
                });
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Keyword Bid Active!')),
              );
            },
            child: const Text('Start Keyword Ad'),
          ),
        ],
      ),
    );
  }
}
