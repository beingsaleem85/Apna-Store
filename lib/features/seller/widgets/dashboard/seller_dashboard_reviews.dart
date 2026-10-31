import 'package:flutter/material.dart';
import '../../../../core/services/app_state_provider.dart';

// 1. Executive Product Customer Reviews & Feedback Desk
class SellerProductReviewsSection extends StatefulWidget {
  final AppStateProvider state;
  final String activeSellerId;

  const SellerProductReviewsSection({
    super.key,
    required this.state,
    required this.activeSellerId,
  });

  @override
  State<SellerProductReviewsSection> createState() => _SellerProductReviewsSectionState();
}

class _SellerProductReviewsSectionState extends State<SellerProductReviewsSection> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedRatingFilter = 'All';

  final List<Map<String, dynamic>> _reviews = [
    {
      'id': 'REV-101',
      'productName': 'Embroidered Cotton Kurta - Royal Blue (Size L)',
      'buyerName': 'Ali Khan',
      'date': '18 Aug 2026',
      'rating': 5,
      'comment': 'MashAllah amazing quality fabric and stitching! Received in 2 days in Lahore. Will order again!',
      'sellerReply': 'Assalam-o-Alaikum Ali! Thank you so much for your positive review and support.',
      'verified': true,
    },
    {
      'id': 'REV-102',
      'productName': 'Wireless Bluetooth Earbuds Pro',
      'buyerName': 'Ayesha Khan',
      'date': '15 Aug 2026',
      'rating': 5,
      'comment': 'Battery backup is great and sound clarity is crisp. High value for money product.',
      'sellerReply': '',
      'verified': true,
    },
    {
      'id': 'REV-103',
      'productName': 'Men Leather Formal Shoes - Tan (Size 42)',
      'buyerName': 'Bilal Farooq',
      'date': '12 Aug 2026',
      'rating': 4,
      'comment': 'Good genuine leather. Size fits well and comfortable for daily wear.',
      'sellerReply': '',
      'verified': true,
    },
    {
      'id': 'REV-104',
      'productName': 'Designer Silk Lawn Unstitched Suit',
      'buyerName': 'Saima Malik',
      'date': '08 Aug 2026',
      'rating': 5,
      'comment': 'Vibrant colors and premium silk feel. Highly recommended seller!',
      'sellerReply': 'Thank you Saima! We are glad you loved the unstitched suit collection.',
      'verified': true,
    },
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showReplyModal(Map<String, dynamic> review) {
    final replyCtrl = TextEditingController(text: review['sellerReply'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Public Seller Reply to ${review['buyerName']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review Comment: "${review['comment']}"', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
            const SizedBox(height: 12),
            const Text('Your Seller Reply:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: replyCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Write a professional response...',
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                review['sellerReply'] = replyCtrl.text.trim();
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Public seller reply published!'), backgroundColor: Color(0xFF059669)),
              );
            },
            child: const Text('Publish Reply'),
          ),
        ],
      ),
    );
  }

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

  Widget _buildStars(int rating) {
    return Row(
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star_rounded : Icons.star_border_rounded,
          color: const Color(0xFFF59E0B),
          size: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchCtrl.text.toLowerCase();
    final filtered = _reviews.where((r) {
      final matchesSearch = searchQuery.isEmpty ||
          r['productName']!.toLowerCase().contains(searchQuery) ||
          r['buyerName']!.toLowerCase().contains(searchQuery) ||
          r['comment']!.toLowerCase().contains(searchQuery);
      final matchesRating = _selectedRatingFilter == 'All' || r['rating'].toString() == _selectedRatingFilter;
      return matchesSearch && matchesRating;
    }).toList();

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
                  Text('Product Reviews & Customer Feedback Desk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Manage buyer ratings, product feedback comments, star ratings, and reply publicly to customer reviews.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Product Reviews exported to CSV!'), backgroundColor: Color(0xFF059669)),
                  );
                },
                icon: const Icon(Icons.download_outlined, size: 14),
                label: const Text('Export Reviews CSV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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
                  _buildKpiBox('Overall Product Score', '4.8 / 5.0 Rating', Icons.star_outline_rounded, const Color(0xFFB45309)),
                  _buildKpiBox('Total Customer Reviews', '${_reviews.length} Reviews', Icons.rate_review_outlined, const Color(0xFF0284C7)),
                  _buildKpiBox('5-Star Positive Rate', '92% 5-Star Reviews', Icons.thumb_up_alt_outlined, const Color(0xFF059669)),
                  _buildKpiBox('Seller Response SLA', '98% Replied', Icons.reply_outlined, const Color(0xFF7C3AED)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Search & Filter Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Search product, buyer, or feedback...',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Filter Rating Dropdown
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 38,
                        child: DropdownButtonFormField<String>(
                          value: _selectedRatingFilter,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All Ratings')),
                            DropdownMenuItem(value: '5', child: Text('5 Stars ⭐⭐⭐⭐⭐')),
                            DropdownMenuItem(value: '4', child: Text('4 Stars ⭐⭐⭐⭐')),
                            DropdownMenuItem(value: '3', child: Text('3 Stars ⭐⭐⭐')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedRatingFilter = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Reviews List Stream
                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: const Center(
                      child: Text('No product reviews match your active search or filter criteria.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final r = filtered[index];
                      final bool hasReply = (r['sellerReply'] as String).isNotEmpty;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    r['productName'],
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                _buildStars(r['rating']),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(r['buyerName'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                                  child: const Text('Verified Buyer', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                ),
                                const SizedBox(width: 8),
                                Text(r['date'], style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('"${r['comment']}"', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),

                            if (hasReply) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.reply, size: 14, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Seller Reply: "${r['sellerReply']}"',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: () => _showReplyModal(r),
                                icon: const Icon(Icons.reply, size: 12),
                                label: Text(hasReply ? 'Edit Seller Reply' : 'Public Reply', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2563EB),
                                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 2. Executive Store Service Rating & Reputation Performance Desk
class SellerStoreRatingSection extends StatelessWidget {
  final AppStateProvider state;
  final AppStore store;
  final String activeSellerId;

  const SellerStoreRatingSection({
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

  Widget _buildScoreRow(String title, String score, double pct, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              Text(score, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 6),
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
                  Text('Store Service Rating & Reputation Desk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Monitor store performance scores, seller service SLA, delivery speed satisfaction, and buyer reputation metrics.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Official Top-Rated Seller Certificate loaded!'), backgroundColor: Color(0xFF059669)),
                  );
                },
                icon: const Icon(Icons.workspace_premium, size: 16),
                label: const Text('View Seller Certificate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB45309),
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
                  _buildKpiBox('Overall Store Score', '4.9 / 5.0 Rating', Icons.stars_outlined, const Color(0xFFB45309)),
                  _buildKpiBox('Item As Described Rate', '98.5% Accuracy', Icons.check_circle_outline, const Color(0xFF059669)),
                  _buildKpiBox('Seller Response SLA', '99.2% Response Rate', Icons.chat_bubble_outline, const Color(0xFF0284C7)),
                  _buildKpiBox('Shipping Speed Rating', '4.8 / 5.0 Speed', Icons.local_shipping_outlined, const Color(0xFF7C3AED)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Store Quality Scores Card
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
                const Text('Marketplace Governance Quality Ratings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 14),
                _buildScoreRow('Product Quality & Description Accuracy', '4.9 / 5.0 (98.5% Positive)', 0.985, const Color(0xFF059669)),
                _buildScoreRow('Pre-Sales & Post-Sales Support SLA', '4.9 / 5.0 (Avg < 15 mins reply)', 0.98, const Color(0xFF0284C7)),
                _buildScoreRow('Same-Day Packaging & Dispatch Speed', '4.8 / 5.0 (99.2% On-time)', 0.96, const Color(0xFF7C3AED)),
                _buildScoreRow('Return & Dispute Resolution Rate', '4.9 / 5.0 (99.0% Amicable)', 0.98, const Color(0xFFB45309)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
