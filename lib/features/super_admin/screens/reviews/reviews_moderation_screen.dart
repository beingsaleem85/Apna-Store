import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/supabase_reviews_service.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';

class ReviewItem {
  final String id;
  final String productName;
  final String buyerName;
  final int rating;
  final String comment;
  bool isFlagged;
  String status; // 'Approved', 'Hidden', 'Flagged'
  final DateTime date;

  ReviewItem({
    required this.id,
    required this.productName,
    required this.buyerName,
    required this.rating,
    required this.comment,
    this.isFlagged = false,
    this.status = 'Approved',
    required this.date,
  });
}

class ReviewsModerationScreen extends StatefulWidget {
  const ReviewsModerationScreen({super.key});

  @override
  State<ReviewsModerationScreen> createState() => _ReviewsModerationScreenState();
}

class _ReviewsModerationScreenState extends State<ReviewsModerationScreen> {
  String _selectedFilter = 'All'; // 'All', 'Flagged Abusive', 'Approved', 'Hidden'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  List<ReviewItem> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadProductReviews();
  }

  Future<void> _loadProductReviews() async {
    try {
      final data = await SupabaseReviewsService().fetchAllReviewsForModeration();
      if (mounted && data.isNotEmpty) {
        setState(() {
          _reviews = data.map<ReviewItem>((r) {
            final prodName = r['products']?['name'] ?? 'Product';
            final buyerName = r['profiles']?['full_name'] ?? 'Verified Buyer';
            return ReviewItem(
              id: r['id']?.toString() ?? 'REV-100',
              productName: prodName,
              buyerName: buyerName,
              rating: (r['rating'] as num?)?.toInt() ?? 5,
              comment: r['comment'] ?? '',
              date: DateTime.tryParse(r['created_at'] ?? '') ?? DateTime.now(),
            );
          }).toList();
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Supabase reviews fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = Provider.of<SuperAdminProvider>(context);

    // Filter Reviews
    final filteredReviews = _reviews.where((r) {
      final matchesSearch = r.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.buyerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.comment.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (_selectedFilter == 'Flagged Abusive') return r.isFlagged || r.status == 'Flagged';
      if (_selectedFilter == 'Approved') return r.status == 'Approved';
      if (_selectedFilter == 'Hidden') return r.status == 'Hidden';
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), shape: BoxShape.circle),
                    child: const Icon(Icons.rate_review_outlined, size: 36, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customer Reviews & Content Moderation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        SizedBox(height: 4),
                        Text('Moderate product ratings, inspect buyer photo reviews, filter profanity/abusive language, and resolve merchant review appeals.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Search & Filter Controls Bar
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: const InputDecoration(
                        hintText: 'Search by Product Name, Buyer, Review Comment...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  Row(
                    children: ['All', 'Flagged Abusive', 'Approved', 'Hidden'].map((filter) {
                      final isSel = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: ChoiceChip(
                          label: Text(filter, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : const Color(0xFF64748B))),
                          selected: isSel,
                          selectedColor: const Color(0xFF0F172A),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onSelected: (val) => setState(() => _selectedFilter = filter),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Master Reviews Table
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Product & Rating', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                        Expanded(flex: 2, child: Text('Buyer & Review Text', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                        Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                        Expanded(flex: 2, child: Text('Moderation Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  ...filteredReviews.map((rev) {
                    final isHidden = rev.status == 'Hidden';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Row(
                        children: [
                          // Product & Rating
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(rev.productName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Row(
                                  children: List.generate(5, (i) => Icon(i < rev.rating ? Icons.star : Icons.star_border, size: 14, color: const Color(0xFFD97706))),
                                ),
                              ],
                            ),
                          ),

                          // Buyer & Text
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Buyer: ${rev.buyerName}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 12)),
                                Text('"${rev.comment}"', style: TextStyle(color: rev.isFlagged ? Colors.redAccent : const Color(0xFF334155), fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),

                          // Status
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isHidden
                                    ? const Color(0xFFFEE2E2)
                                    : rev.isFlagged
                                        ? const Color(0xFFFEF3C7)
                                        : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                rev.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isHidden
                                      ? Colors.redAccent
                                      : rev.isFlagged
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF059669),
                                ),
                              ),
                            ),
                          ),

                          // Actions
                          Expanded(
                            flex: 2,
                            child: Wrap(
                              spacing: 6,
                              children: [
                                if (!isHidden)
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                    onPressed: () async {
                                      final confirmed = await SuperAdminDialogs.showConfirmation(
                                        context: context,
                                        title: 'Hide Review',
                                        message: 'Hide this review from public product page?',
                                        confirmColor: Colors.redAccent,
                                      );
                                      if (confirmed) {
                                        setState(() => rev.status = 'Hidden');
                                        adminState.logAuditAction('REVIEW_HIDE', rev.id, 'Hid review due to policy violation.');
                                        if (mounted) SuperAdminDialogs.showToast(context, 'Review Hidden', isError: true);
                                      }
                                    },
                                    child: const Text('Hide Review', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  )
                                else
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                                    onPressed: () {
                                      setState(() {
                                        rev.status = 'Approved';
                                        rev.isFlagged = false;
                                      });
                                      adminState.logAuditAction('REVIEW_APPROVE', rev.id, 'Approved review.');
                                      SuperAdminDialogs.showToast(context, 'Review Approved');
                                    },
                                    child: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
