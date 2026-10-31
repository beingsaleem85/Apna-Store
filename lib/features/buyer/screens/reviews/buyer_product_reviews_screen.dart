import 'package:flutter/material.dart';

class ReviewItem {
  final String author;
  final double rating;
  final String date;
  final String text;
  final bool isVerified;
  int helpfulCount;
  final List<IconData> photoIcons;

  ReviewItem({
    required this.author,
    required this.rating,
    required this.date,
    required this.text,
    required this.isVerified,
    required this.helpfulCount,
    required this.photoIcons,
  });
}

class BuyerProductReviewsScreen extends StatefulWidget {
  const BuyerProductReviewsScreen({super.key});

  @override
  State<BuyerProductReviewsScreen> createState() => _BuyerProductReviewsScreenState();
}

class _BuyerProductReviewsScreenState extends State<BuyerProductReviewsScreen> {
  bool _filterPhotosOnly = false;
  double _userSelectedRating = 5.0;
  final TextEditingController _reviewTextController = TextEditingController();
  bool _isPhotoAttached = false;

  final List<ReviewItem> _reviews = [
    ReviewItem(
      author: 'Fatima Z.',
      rating: 5.0,
      date: '18 July 2026',
      text: 'Mashallah! The embroidery quality is stunning and lawn fabric is super soft. Fits perfectly size M.',
      isVerified: true,
      helpfulCount: 142,
      photoIcons: [Icons.checkroom, Icons.style],
    ),
    ReviewItem(
      author: 'Usman R.',
      rating: 5.0,
      date: '15 July 2026',
      text: 'Fast delivery via TCS in Lahore! Packaging was intact and color matches 100% with PDP photos.',
      isVerified: true,
      helpfulCount: 89,
      photoIcons: [Icons.local_shipping],
    ),
    ReviewItem(
      author: 'Zainab M.',
      rating: 4.0,
      date: '10 July 2026',
      text: 'Good product quality, but shipping took 3 days instead of 2. Overall recommended!',
      isVerified: true,
      helpfulCount: 34,
      photoIcons: [],
    ),
  ];

  @override
  void dispose() {
    _reviewTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filterPhotosOnly ? _reviews.where((r) => r.photoIcons.isNotEmpty).toList() : _reviews;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Reviews & Rating Booster'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Rating Summary Header Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Column(
                      children: [
                        const Text('4.8', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                        Row(
                          children: List.generate(
                            5,
                            (i) => const Icon(Icons.star, color: Color(0xFFFDB913), size: 16),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('1,420 Reviews', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          _buildStarBar(5, 0.85),
                          _buildStarBar(4, 0.10),
                          _buildStarBar(3, 0.03),
                          _buildStarBar(2, 0.01),
                          _buildStarBar(1, 0.01),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Review Wizard Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Write a Verified Buyer Review', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),

                    // Star Selector
                    Row(
                      children: [
                        const Text('Your Rating:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Row(
                          children: List.generate(5, (index) {
                            final starVal = index + 1.0;
                            return IconButton(
                              icon: Icon(
                                starVal <= _userSelectedRating ? Icons.star : Icons.star_border,
                                color: const Color(0xFFFDB913),
                              ),
                              onPressed: () => setState(() => _userSelectedRating = starVal),
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Review Text Field
                    TextField(
                      controller: _reviewTextController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Share your experience regarding size fit, fabric, and delivery...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Attach Buyer Photo Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          icon: Icon(_isPhotoAttached ? Icons.check_circle : Icons.add_a_photo, color: const Color(0xFF004D40)),
                          label: Text(_isPhotoAttached ? 'Photo Attached' : 'Attach Buyer Photo'),
                          onPressed: () {
                            setState(() => _isPhotoAttached = true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Buyer photo attached to review!')),
                            );
                          },
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.send),
                          label: const Text('Submit Review'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF004D40),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            if (_reviewTextController.text.isNotEmpty) {
                              setState(() {
                                _reviews.insert(
                                  0,
                                  ReviewItem(
                                    author: 'You (Verified Buyer)',
                                    rating: _userSelectedRating,
                                    date: 'Just now',
                                    text: _reviewTextController.text,
                                    isVerified: true,
                                    helpfulCount: 0,
                                    photoIcons: _isPhotoAttached ? [Icons.camera_alt] : [],
                                  ),
                                );
                                _reviewTextController.clear();
                                _isPhotoAttached = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Review Submitted! Thank you for rating this product.')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Review Filter Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Buyer Reviews (${filteredList.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                FilterChip(
                  label: const Text('With Photos Only', style: TextStyle(fontSize: 11)),
                  selected: _filterPhotosOnly,
                  selectedColor: const Color(0xFFFDB913),
                  onSelected: (val) => setState(() => _filterPhotosOnly = val),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Reviews List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredList.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final r = filteredList[index];

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: const Color(0xFF004D40).withOpacity(0.1),
                                  child: Text(r.author[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40), fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                Text(r.author, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                if (r.isVerified) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(4)),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.verified, size: 10, color: Colors.green),
                                        SizedBox(width: 2),
                                        Text('Verified Purchase', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(r.date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 8),

                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(
                              i < r.rating ? Icons.star : Icons.star_border,
                              color: const Color(0xFFFDB913),
                              size: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(r.text, style: const TextStyle(fontSize: 12, height: 1.4)),
                        const SizedBox(height: 10),

                        // Photo Gallery Preview if present
                        if (r.photoIcons.isNotEmpty) ...[
                          Row(
                            children: r.photoIcons.map((ic) {
                              return Container(
                                width: 50,
                                height: 50,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Icon(ic, color: const Color(0xFF004D40), size: 24),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Helpful Upvote Counter Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.thumb_up_alt_outlined, size: 14),
                              label: Text('Helpful (${r.helpfulCount})', style: const TextStyle(fontSize: 11)),
                              onPressed: () {
                                setState(() => r.helpfulCount++);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarBar(int stars, double pct) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text('$stars ★', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.grey.shade200,
              color: const Color(0xFFFDB913),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
