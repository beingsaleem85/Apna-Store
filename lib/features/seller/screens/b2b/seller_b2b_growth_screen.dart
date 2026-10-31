import 'package:flutter/material.dart';

class SellerB2bGrowthScreen extends StatefulWidget {
  const SellerB2bGrowthScreen({super.key});

  @override
  State<SellerB2bGrowthScreen> createState() => _SellerB2bGrowthScreenState();
}

class _SellerB2bGrowthScreenState extends State<SellerB2bGrowthScreen> {
  final List<Map<String, String>> _wholesaleTiers = [
    {'tier': 'Tier 1 (Bronze Wholesale)', 'moq': '50 - 199 Units', 'discount': '15% Bulk Discount'},
    {'tier': 'Tier 2 (Gold Wholesale)', 'moq': '200+ Units', 'discount': '25% Bulk Discount'},
  ];

  final List<Map<String, String>> _liveStreams = [
    {'title': 'Ramzan Lawn Collection 2026 Live Showcase', 'date': 'Tomorrow at 8:00 PM', 'status': 'Scheduled'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('B2B Wholesale, Live Commerce & Growth Tools'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // B2B Wholesale Tiered Bulk Pricing Card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('B2B Wholesale MOQ Tiered Pricing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add B2B Tier'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('B2B Wholesale Price Tier Added!')),
                    );
                  },
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
                itemCount: _wholesaleTiers.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final t = _wholesaleTiers[index];
                  return ListTile(
                    leading: const Icon(Icons.store, color: Color(0xFF004D40)),
                    title: Text(t['tier']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Minimum Order Quantity: ${t['moq']}', style: const TextStyle(fontSize: 11)),
                    trailing: Text(t['discount']!, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Live Commerce Stream Host
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Live Stream Shopping Host Studio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.videocam, size: 16),
                  label: const Text('Schedule Live Stream'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Live Stream Scheduled & Notification Sent to Followers!')),
                    );
                  },
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
                itemCount: _liveStreams.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final l = _liveStreams[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.red,
                      child: Icon(Icons.live_tv, color: Colors.white, size: 18),
                    ),
                    title: Text(l['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Schedule: ${l['date']}', style: const TextStyle(fontSize: 11)),
                    trailing: const Chip(label: Text('Scheduled', style: TextStyle(fontSize: 10, color: Colors.white)), backgroundColor: Colors.orange),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Affiliate Link Generator Banner
            Card(
              color: const Color(0xFF004D40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Affiliate Growth & Referral Link Studio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 2),
                        Text('Share store referral links with influencers and offer 5% commission.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDB913), foregroundColor: Colors.black),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Affiliate Referral Link Copied to Clipboard!')),
                        );
                      },
                      child: const Text('Generate Referral Link'),
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
}
