import 'package:flutter/material.dart';

class VoucherItem {
  final String code;
  final String title;
  final String discount;
  final String minOrder;
  final String expiry;
  bool isCollected;

  VoucherItem({
    required this.code,
    required this.title,
    required this.discount,
    required this.minOrder,
    required this.expiry,
    this.isCollected = false,
  });
}

class BuyerCampaignVouchersScreen extends StatefulWidget {
  const BuyerCampaignVouchersScreen({super.key});

  @override
  State<BuyerCampaignVouchersScreen> createState() => _BuyerCampaignVouchersScreenState();
}

class _BuyerCampaignVouchersScreenState extends State<BuyerCampaignVouchersScreen> {
  final List<VoucherItem> _vouchers = [
    VoucherItem(
      code: 'RAMZAN2026',
      title: 'Ramzan Mubarak Special Voucher',
      discount: 'Rs. 1,000 OFF',
      minOrder: 'Min. Order Rs. 5,000',
      expiry: 'Expires in 3 Days',
    ),
    VoucherItem(
      code: 'GULAHMED200',
      title: 'Gul Ahmed Store Voucher',
      discount: 'Rs. 200 OFF',
      minOrder: 'Min. Order Rs. 2,000',
      expiry: 'Expires Today',
    ),
    VoucherItem(
      code: 'FREESHIP50',
      title: 'Free Shipping Campaign Voucher',
      discount: 'Free Delivery',
      minOrder: 'Min. Order Rs. 1,500',
      expiry: 'Expires in 7 Days',
    ),
  ];

  final List<Map<String, dynamic>> _flashDeals = [
    {
      'title': 'Anker 20,000mAh Power Bank',
      'price': 'Rs. 4,499',
      'oldPrice': 'Rs. 8,999',
      'discount': '50% OFF',
      'soldPct': 0.78,
      'soldText': '78% Claimed - 12 Left',
      'icon': Icons.battery_charging_full,
    },
    {
      'title': 'Air Jordan Retro Sneakers',
      'price': 'Rs. 6,999',
      'oldPrice': 'Rs. 12,000',
      'discount': '42% OFF',
      'soldPct': 0.92,
      'soldText': '92% Claimed - 3 Left',
      'icon': Icons.dry_cleaning,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mega Sale & Voucher Campaign Hub'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mega Campaign Hero Banner Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF004D40), Color(0xFF00796B)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFFDB913), borderRadius: BorderRadius.circular(20)),
                    child: const Text('🌙 RAMZAN BLESSED SHOPPING FESTIVAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black)),
                  ),
                  const SizedBox(height: 10),
                  const Text('UP TO 70% OFF ON ALL STORES', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  const Text('Collect mega vouchers & unlock free doorstep shipping nationwide.', style: TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live Flash Sale Countdown Ticker Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.red, width: 1.5)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt, color: Colors.red, size: 24),
                            SizedBox(width: 6),
                            Text('LIVE FLASH SALE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                          child: const Text('⏰ Ends in 04h : 18m : 32s', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.red)),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _flashDeals.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final d = _flashDeals[index];
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.red.shade50,
                              child: Icon(d['icon'] as IconData, color: Colors.red),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Row(
                                    children: [
                                      Text(d['price'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                                      const SizedBox(width: 8),
                                      Text(d['oldPrice'] as String, style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 11)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  LinearProgressIndicator(
                                    value: d['soldPct'] as double,
                                    backgroundColor: Colors.grey.shade200,
                                    color: Colors.red,
                                    minHeight: 5,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(d['soldText'] as String, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Flash Deal Added to Cart!')),
                                );
                              },
                              child: const Text('Buy Now', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Voucher Collector Hub
            const Text('Collect Platform & Store Vouchers:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _vouchers.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final v = _vouchers[index];

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_number, color: Color(0xFFFDB913), size: 30),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('${v.discount} | ${v.minOrder}', style: const TextStyle(fontSize: 11, color: Color(0xFF004D40), fontWeight: FontWeight.bold)),
                              Text(v.expiry, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: v.isCollected ? Colors.grey : const Color(0xFF004D40),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            setState(() => v.isCollected = !v.isCollected);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(v.isCollected ? 'Voucher Code ${v.code} Collected!' : 'Voucher Removed')),
                            );
                          },
                          child: Text(v.isCollected ? 'Collected ✓' : 'Collect'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Bank Partner Discount Offers Card
            Card(
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.blue)),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.credit_card, color: Colors.blue, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bank Partner Instant Discounts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                          Text('HBL: 15% Cashback | Meezan Bank: 20% Instant Discount on Debit Cards.', style: TextStyle(fontSize: 11, color: Colors.black87)),
                        ],
                      ),
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
