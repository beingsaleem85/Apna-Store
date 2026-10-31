import 'package:flutter/material.dart';

class SellerPromotionsCampaignScreen extends StatefulWidget {
  const SellerPromotionsCampaignScreen({super.key});

  @override
  State<SellerPromotionsCampaignScreen> createState() => _SellerPromotionsCampaignScreenState();
}

class _SellerPromotionsCampaignScreenState extends State<SellerPromotionsCampaignScreen> {
  final List<Map<String, String>> _campaigns = [
    {'title': '11.11 Grand Shopping Festival 2026', 'discount': 'Min 15% OFF Required', 'status': 'Open for Registration'},
    {'title': 'Ramzan Shopping Special 2026', 'discount': 'Free Delivery + 10% OFF', 'status': 'Upcoming'},
  ];

  final List<Map<String, String>> _vouchers = [
    {'code': 'SHOP200', 'discount': 'Rs. 200 OFF', 'minOrder': 'Rs. 2,000', 'usage': '45 / 100 Used'},
    {'code': 'RAMZAN15', 'discount': '15% OFF', 'minOrder': 'Rs. 3,500', 'usage': '12 / 50 Used'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promotions, Vouchers & Campaign Hub'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform Mega Campaigns Registration Header
            const Text('Official Platform Mega Sales & Flash Campaigns', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _campaigns.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final c = _campaigns[index];
                  final isOpen = c['status'] == 'Open for Registration';

                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFDB913),
                      child: Icon(Icons.local_fire_department, color: Colors.black),
                    ),
                    title: Text(c['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Criteria: ${c['discount']} | Status: ${c['status']}', style: const TextStyle(fontSize: 11)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOpen ? const Color(0xFF004D40) : Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: isOpen
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Registered products for ${c['title']}!')),
                              );
                            }
                          : null,
                      child: Text(isOpen ? 'Register SKUs' : 'Upcoming', style: const TextStyle(fontSize: 11)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Store Vouchers Studio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Store Discount Vouchers & Coupons', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create New Store Voucher'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                  onPressed: () => _showCreateVoucherModal(),
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
                itemCount: _vouchers.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final v = _vouchers[index];

                  return ListTile(
                    leading: const Icon(Icons.confirmation_num, color: Color(0xFF004D40)),
                    title: Text('Voucher Code: ${v['code']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Discount: ${v['discount']} (Min Order: ${v['minOrder']})', style: const TextStyle(fontSize: 11)),
                    trailing: Text(v['usage']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Bundle Deals & Flexi-Combo Banner
            Card(
              color: Colors.amber.shade800,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Flexi-Combo & Buy 2 Get 1 Free Bundle Deals', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 2),
                        Text('Increase average order value by bundling complementary items.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Flexi-Combo Rule Created!')),
                        );
                      },
                      child: const Text('Create Bundle Rule'),
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

  void _showCreateVoucherModal() async {
    final TextEditingController codeCtrl = TextEditingController();
    final TextEditingController amountCtrl = TextEditingController();

    try {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Create New Store Voucher', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Voucher Code (e.g. SUMMER100)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Discount Amount / Percentage', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
              onPressed: () {
                if (codeCtrl.text.isNotEmpty) {
                  if (mounted) {
                    setState(() {
                      _vouchers.add({
                        'code': codeCtrl.text.toUpperCase(),
                        'discount': 'Rs. ${amountCtrl.text} OFF',
                        'minOrder': 'Rs. 1,500',
                        'usage': '0 / 100 Used',
                      });
                    });
                  }
                }
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New Store Voucher Created!')),
                  );
                }
              },
              child: const Text('Create Voucher'),
            ),
          ],
        ),
      );
    } finally {
      codeCtrl.dispose();
      amountCtrl.dispose();
    }
  }
}
