import 'package:flutter/material.dart';

class CustomerReviewItem {
  final String id;
  final String customerName;
  final String productTitle;
  final int rating;
  final String comment;
  final String date;
  final bool hasPhoto;
  String? sellerReply;

  CustomerReviewItem({
    required this.id,
    required this.customerName,
    required this.productTitle,
    required this.rating,
    required this.comment,
    required this.date,
    required this.hasPhoto,
    this.sellerReply,
  });
}

class SellerReviewManagementScreen extends StatefulWidget {
  const SellerReviewManagementScreen({super.key});

  @override
  State<SellerReviewManagementScreen> createState() => _SellerReviewManagementScreenState();
}

class _SellerReviewManagementScreenState extends State<SellerReviewManagementScreen> {
  String _activeTab = 'All Reviews';
  bool _voucherBoosterEnabled = true;

  final List<CustomerReviewItem> _reviews = [
    CustomerReviewItem(
      id: 'REV-101',
      customerName: 'Fatima Zafar',
      productTitle: 'Embroidered Lawn 3-Piece Suit',
      rating: 5,
      comment: 'Excellent fabric quality and color accuracy! Delivered in 2 days.',
      date: '18 July 2026',
      hasPhoto: true,
      sellerReply: 'Thank you Fatima! We appreciate your support!',
    ),
    CustomerReviewItem(
      id: 'REV-102',
      customerName: 'Bilal Hassan',
      productTitle: 'Men Leather Jacket (Brown)',
      rating: 1,
      comment: 'Size is completely different from size chart. Disappointed.',
      date: '19 July 2026',
      hasPhoto: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _reviews.where((r) {
      if (_activeTab == '5 Stars') return r.rating == 5;
      if (_activeTab == '1 Star Bad') return r.rating == 1;
      if (_activeTab == 'Photo Reviews') return r.hasPhoto;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Management & Store Rating Booster'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rating Overview & Voucher Booster Card
            Card(
              color: const Color(0xFF004D40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Store Rating Score', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Text('4.8', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                            SizedBox(width: 8),
                            Icon(Icons.star, color: Color(0xFFFDB913), size: 24),
                            Text(' (142 Verified Reviews)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Review Incentive Booster', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const Text('Auto-send Rs. 50 voucher for photo reviews', style: TextStyle(color: Colors.white70, fontSize: 10)),
                        Switch(
                          value: _voucherBoosterEnabled,
                          activeColor: const Color(0xFFFDB913),
                          onChanged: (val) => setState(() => _voucherBoosterEnabled = val),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All Reviews', '5 Stars', '1 Star Bad', 'Photo Reviews'].map((tab) {
                  final isSel = _activeTab == tab;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(tab, style: TextStyle(color: isSel ? Colors.white : Colors.black87, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                      selected: isSel,
                      selectedColor: const Color(0xFF004D40),
                      onSelected: (val) => setState(() => _activeTab = tab),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Reviews List
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text('No reviews found in this filter.')),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final rev = filtered[index];

                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(rev.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Row(
                                    children: List.generate(5, (starIdx) {
                                      return Icon(
                                        starIdx < rev.rating ? Icons.star : Icons.star_border,
                                        color: const Color(0xFFFDB913),
                                        size: 16,
                                      );
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('Product: ${rev.productTitle} | Date: ${rev.date}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Text(rev.comment, style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 12),

                              if (rev.sellerReply != null)
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.store, size: 16, color: Color(0xFF004D40)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text('Official Seller Reply: ${rev.sellerReply}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 8),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.flag_outlined, size: 14, color: Colors.red),
                                    label: const Text('Report Abuse to Admin', style: TextStyle(fontSize: 11, color: Colors.red)),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Abuse Report for ${rev.id} submitted to Super Admin!')),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.reply, size: 14),
                                    label: const Text('Reply to Customer', style: TextStyle(fontSize: 11)),
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                                    onPressed: () => _showReplyModal(rev),
                                  ),
                                ],
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

  void _showReplyModal(CustomerReviewItem rev) async {
    final TextEditingController replyCtrl = TextEditingController(text: rev.sellerReply ?? '');

    try {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Publish Store Reply — ${rev.customerName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: replyCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Type your official public store reply...', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
              onPressed: () {
                if (mounted) setState(() => rev.sellerReply = replyCtrl.text);
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Official Public Store Reply Published!')),
                  );
                }
              },
              child: const Text('Publish Reply'),
            ),
          ],
        ),
      );
    } finally {
      replyCtrl.dispose();
    }
  }
}
