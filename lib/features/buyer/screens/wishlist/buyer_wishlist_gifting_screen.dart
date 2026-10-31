import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/app_state_provider.dart';
import '../../../../core/widgets/safe_network_image.dart';

class BuyerWishlistGiftingScreen extends StatefulWidget {
  const BuyerWishlistGiftingScreen({super.key});

  @override
  State<BuyerWishlistGiftingScreen> createState() => _BuyerWishlistGiftingScreenState();
}

class _BuyerWishlistGiftingScreenState extends State<BuyerWishlistGiftingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _recipientNameController = TextEditingController();
  final TextEditingController _greetingMsgController = TextEditingController();
  String _selectedGiftWrap = 'Luxury Velvet Ribbon Box (Rs. 150)';

  final List<Map<String, dynamic>> _wishlistItems = [
    {
      'title': 'Embroidered Lawn 3-Piece Suit',
      'folder': 'Ramzan Outfits',
      'price': 'Rs. 3,500',
      'icon': Icons.checkroom,
    },
    {
      'title': 'Xiaomi Smart Watch S3',
      'folder': 'Tech Gadgets',
      'price': 'Rs. 18,999',
      'icon': Icons.watch,
    },
  ];

  final List<Map<String, dynamic>> _registryItems = [
    {
      'title': 'Royal Velvet Sofa Set 5-Seater',
      'price': 'Rs. 85,000',
      'fulfilledBy': 'Purchased by Uncle Tariq & Family',
      'status': 'Fulfilled',
    },
    {
      'title': 'Philips Air Fryer XL',
      'price': 'Rs. 32,000',
      'fulfilledBy': 'Waiting for contribution',
      'status': 'Open',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _recipientNameController.dispose();
    _greetingMsgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
          tooltip: 'Go Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/');
            }
          },
        ),
        title: const Text('Wishlist, Gifting & Registry Hub', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF004D40),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.home_rounded, size: 16),
                label: const Text('Go to Home', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              child: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFFDB913),
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                isScrollable: false,
                tabs: const [
                  Tab(text: 'Wishlist Boards'),
                  Tab(text: 'Gift Packaging'),
                  Tab(text: 'Gift Registry & Group'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Wishlist Boards
          Consumer<AppStateProvider>(
            builder: (context, state, _) {
              final items = state.wishlistProducts;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Saved Wishlist Items (${items.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.shopping_cart_checkout, size: 14),
                          label: const Text('Move All to Cart', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                          onPressed: items.isEmpty
                              ? null
                              : () {
                                  for (final p in items) {
                                    state.addToCart(p);
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('All wishlist items added to cart!'), backgroundColor: Colors.green),
                                  );
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (items.isEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(36),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.favorite_border, size: 48, color: Color(0xFF94A3B8)),
                            SizedBox(height: 12),
                            Text('Your Wishlist is currently empty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                            SizedBox(height: 4),
                            Text('Save products you love to view or buy them anytime.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final product = items[index];
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SafeNetworkImage(
                                  imageUrl: product.imageUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('PKR ${product.price} | ${product.category}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                    onPressed: () => state.removeFromWishlist(product.id),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                                    onPressed: () {
                                      state.addToCart(product);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('${product.name} moved to Active Cart!'), backgroundColor: Colors.green),
                                      );
                                    },
                                    child: const Text('Add to Cart', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          // Tab 2: Gift Wrapping & Greeting Card Studio
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.card_giftcard, color: Color(0xFF004D40), size: 24),
                        SizedBox(width: 8),
                        Text('Personalized Gift Packaging Studio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('Send this order directly as a gift wrapped package to your loved ones.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const Divider(height: 24),

                    const Text('Select Gift Wrapping Style:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      value: _selectedGiftWrap,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: [
                        'Luxury Velvet Ribbon Box (Rs. 150)',
                        'Classic Golden Bow Packaging (Rs. 100)',
                        'Eco-Friendly Craft Wrap (Rs. 50)',
                      ].map((w) => DropdownMenuItem(value: w, child: Text(w, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (val) => setState(() => _selectedGiftWrap = val!),
                    ),
                    const SizedBox(height: 16),

                    const Text('Recipient Name:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _recipientNameController,
                      decoration: const InputDecoration(hintText: 'Enter Recipient Full Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),

                    const Text('Personalized Greeting Note:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _greetingMsgController,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'Write your personalized message card text...', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Apply Gift Wrap & Greetings to Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004D40),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Gift Wrapping & Greeting Card configured!')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tab 3: Gift Registry & Team-Up Group Buying
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team-Up Group Buying Card
                Card(
                  color: Colors.amber.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.amber)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.groups, color: Colors.brown, size: 24),
                            SizedBox(width: 8),
                            Text('Team-Up Group Buying Deal — 35% OFF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.brown)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text('Buy with 2 Friends & Pay Rs. 2,275 instead of Rs. 3,500!', style: TextStyle(fontSize: 12, color: Colors.brown, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),

                        ElevatedButton.icon(
                          icon: const Icon(Icons.share, size: 14),
                          label: const Text('Invite 2 Friends via WhatsApp to Unlock Deal'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Group Deal Invite Link Copied & Shared!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Gift Registry Header Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Wedding Gift Registry #REG-4401', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('Created by Ali & Fatima', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.link, size: 14),
                              label: const Text('Share Registry', style: TextStyle(fontSize: 11)),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Registry Link copied to clipboard!')),
                                );
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _registryItems.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final r = _registryItems[index];
                            final bool isFulfilled = r['status'] == 'Fulfilled';

                            return ListTile(
                              leading: Icon(isFulfilled ? Icons.check_circle : Icons.radio_button_unchecked, color: isFulfilled ? Colors.green : Colors.grey),
                              title: Text(r['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              subtitle: Text('${r['price']} | ${r['fulfilledBy']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
}
}
