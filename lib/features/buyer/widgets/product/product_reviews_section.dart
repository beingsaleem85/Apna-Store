import 'package:flutter/material.dart';
import '../../../../core/services/app_state_provider.dart';
import '../../../../core/services/supabase_reviews_service.dart';

class ProductReviewsSection extends StatefulWidget {
  final AppProduct product;

  const ProductReviewsSection({
    super.key,
    required this.product,
  });

  @override
  State<ProductReviewsSection> createState() => _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends State<ProductReviewsSection> {
  final _questionController = TextEditingController();
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingReviews = false;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoadingReviews = true);
    try {
      final list = await SupabaseReviewsService().getProductReviews(widget.product.id);
      if (mounted) {
        setState(() => _reviews = list);
      }
    } catch (_) {
      // Offline fallback
    } finally {
      if (mounted) setState(() => _isLoadingReviews = false);
    }
  }

  final List<Map<String, String>> _productQuestions = [
    {
      'question': 'Is official brand warranty included with this phone?',
      'answer': 'Yes, 1 year official brand warranty card with PTA approval is included inside the box.',
      'user': 'Ahsan K.',
      'date': '2 days ago',
    },
    {
      'question': 'Is cash on delivery available nationwide?',
      'answer': 'Yes, cash on delivery is available all across Pakistan with fast 2-3 days shipping.',
      'user': 'Tariq M.',
      'date': '5 days ago',
    },
  ];

  final List<Map<String, dynamic>> _sellerReviews = [
    {
      'user': 'Hamza K.',
      'rating': 5,
      'comment': 'Excellent seller! Item was 100% original, official seal packed, and delivered in under 24 hours.',
      'date': 'Yesterday',
    },
    {
      'user': 'Zainab S.',
      'rating': 5,
      'comment': 'Very polite seller, answered all my product warranty questions in chat immediately. Recommended!',
      'date': '3 days ago',
    },
    {
      'user': 'Usman R.',
      'rating': 5,
      'comment': 'Packaging was very safe with multi-layer bubble wrap. Extremely trusted seller on Elegant Marketplace!',
      'date': '1 week ago',
    },
  ];

  void _showWriteSellerReviewDialog(BuildContext context) {
    int rating = 5;
    final reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Rate & Review Seller', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How was your overall experience with this seller?', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (idx) => IconButton(
                        icon: Icon(
                          Icons.star,
                          size: 28,
                          color: idx < rating ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                        ),
                        onPressed: () => setModalState(() => rating = idx + 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reviewController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Share feedback on seller response, delivery speed, and service...',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    if (reviewController.text.trim().isNotEmpty) {
                      setState(() {
                        _sellerReviews.insert(0, {
                          'user': 'You (Verified Buyer)',
                          'rating': rating,
                          'comment': reviewController.text.trim(),
                          'date': 'Just now',
                        });
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Thank you! Your seller review has been published.'),
                          backgroundColor: Color(0xFF059669),
                        ),
                      );
                    }
                  },
                  child: const Text('Submit Review'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Widget _buildRatingBar(int stars, int count, int total) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Row(
            children: List.generate(
              5,
              (idx) => Icon(
                Icons.star,
                size: 14,
                color: idx < stars ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 24,
            child: Text('$count', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerReviewCard({
    required String username,
    required int rating,
    required String comment,
    required List<String> images,
    required int likes,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(
            5,
            (idx) => Icon(
              Icons.star,
              size: 14,
              color: idx < rating ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(username, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text(comment, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), height: 1.5)),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: images.map((img) {
              return Container(
                margin: const EdgeInsets.only(right: 12),
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(img, fit: BoxFit.cover),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.thumb_up_alt_outlined, size: 14, color: Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text('$likes', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Ratings & Reviews Box
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ratings & Reviews of ${widget.product.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 24),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final totalRatings = _reviews.length;
                  final avgRating = totalRatings > 0
                      ? (_reviews.fold(0.0, (sum, r) => sum + ((r['rating'] as num?)?.toDouble() ?? 5.0)) / totalRatings)
                      : (double.tryParse(widget.product.rating) ?? 5.0);
                  final totalBase = totalRatings > 0 ? totalRatings : 1;
                  final c5 = _reviews.where((r) => (r['rating'] as num?)?.toInt() == 5).length;
                  final c4 = _reviews.where((r) => (r['rating'] as num?)?.toInt() == 4).length;
                  final c3 = _reviews.where((r) => (r['rating'] as num?)?.toInt() == 3).length;
                  final c2 = _reviews.where((r) => (r['rating'] as num?)?.toInt() == 2).length;
                  final c1 = _reviews.where((r) => (r['rating'] as num?)?.toInt() == 1).length;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                              const Text('/5', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: List.generate(
                              5,
                              (index) => Icon(
                                index < avgRating.round() ? Icons.star : Icons.star_border,
                                color: const Color(0xFFF59E0B),
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('$totalRatings Ratings', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                        ],
                      ),
                      SizedBox(width: isMobile ? 24 : 60),

                      Expanded(
                        child: Column(
                          children: [
                            _buildRatingBar(5, c5, totalBase),
                            _buildRatingBar(4, c4, totalBase),
                            _buildRatingBar(3, c3, totalBase),
                            _buildRatingBar(2, c2, totalBase),
                            _buildRatingBar(1, c1, totalBase),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Product Reviews', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Row(
                    children: const [
                      Icon(Icons.swap_vert, size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 4),
                      Text('Sort: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text('Relevance', style: TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                      SizedBox(width: 16),
                      Icon(Icons.filter_alt_outlined, size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 4),
                      Text('Filter: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      Text('All star', style: TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_isLoadingReviews)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else if (_reviews.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  alignment: Alignment.center,
                  child: Column(
                    children: const [
                      Icon(Icons.rate_review_outlined, size: 40, color: Color(0xFF94A3B8)),
                      SizedBox(height: 8),
                      Text('No customer reviews yet for this product.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Verified buyers can leave reviews after receiving their order.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    ],
                  ),
                )
              else
                ..._reviews.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildCustomerReviewCard(
                        username: (r['profiles'] is Map ? r['profiles']['full_name'] : null) ?? 'Verified Buyer',
                        rating: (r['rating'] as num?)?.toInt() ?? 5,
                        comment: (r['comment'] ?? '').toString(),
                        images: const [],
                        likes: 0,
                      ),
                    )),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Seller Ratings & Seller Performance Reviews Box
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Seller Ratings & Performance Reviews',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.rate_review_outlined, size: 16),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showWriteSellerReviewDialog(context),
                    label: const Text('Rate Seller', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Seller Performance Overview Cards
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Rating score
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('98%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                          SizedBox(height: 2),
                          Text('Positive Seller Score', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Container(height: 36, width: 1, color: const Color(0xFFCBD5E1)),
                      const SizedBox(width: 24),

                      // Ship on time
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('99%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                          SizedBox(height: 2),
                          Text('Ship on Time Rate', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Container(height: 36, width: 1, color: const Color(0xFFCBD5E1)),
                      const SizedBox(width: 24),

                      // Chat response rate
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('98%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                          SizedBox(height: 2),
                          Text('Chat Response Rate', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Verified Buyer Feedback on Seller:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 12),

              // Seller Reviews List
              ..._sellerReviews.map((sr) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Row(
                              children: List.generate(
                                5,
                                (idx) => Icon(
                                  Icons.star,
                                  size: 14,
                                  color: idx < (sr['rating'] as int) ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(sr['user'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                              child: const Text('Verified Buyer', style: TextStyle(fontSize: 9, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                            ),
                            const Spacer(),
                            Text(sr['date'] as String, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(sr['comment'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.4)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Questions Box
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Questions about this product',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 20),

              // Question Input Box
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionController,
                      decoration: InputDecoration(
                        hintText: 'Ask seller a question about this product...',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      if (_questionController.text.trim().isNotEmpty) {
                        setState(() {
                          _productQuestions.insert(0, {
                            'question': _questionController.text.trim(),
                            'answer': 'Seller has received your question and will answer shortly.',
                            'user': 'You',
                            'date': 'Just now',
                          });
                          _questionController.clear();
                        });
                      }
                    },
                    child: const Text('Ask', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Questions List
              ..._productQuestions.map((q) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.help_outline, size: 16, color: Color(0xFF059669)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(q['question']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            ),
                            Text(q['date']!, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 22.0),
                          child: Text(q['answer']!, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }
}
