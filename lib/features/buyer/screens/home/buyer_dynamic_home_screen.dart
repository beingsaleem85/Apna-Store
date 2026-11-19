import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BuyerDynamicHomeScreen extends StatefulWidget {
  const BuyerDynamicHomeScreen({super.key});

  @override
  State<BuyerDynamicHomeScreen> createState() => _BuyerDynamicHomeScreenState();
}

class _BuyerDynamicHomeScreenState extends State<BuyerDynamicHomeScreen> {
  String _selectedCategoryChip = 'All';

  final List<String> _categories = [
    'All',
    'Women Fashion',
    'Men Wear',
    'Mobiles',
    'Electronics',
    'Beauty',
    'Groceries',
  ];

  final List<Map<String, dynamic>> _flashProducts = [];

  @override
  void initState() {
    super.initState();
    _fetchFlashSales();
  }

  Future<void> _fetchFlashSales() async {
    try {
      final res = await Supabase.instance.client.rpc('get_flash_sale_products', params: {'p_limit': 10});
      if (res is List && res.isNotEmpty && mounted) {
        setState(() {
          _flashProducts.clear();
          for (final item in res) {
            _flashProducts.add({
              'title': (item['name'] ?? '').toString(),
              'price': 'Rs. ${item['sale_price'] ?? item['price']}',
              'originalPrice': 'Rs. ${item['price']}',
              'discount': '-${item['discount_percentage'] ?? 0}%',
              'rating': '${item['rating'] ?? 5.0} ⭐',
              'imageIcon': Icons.local_offer,
              'reason': 'Special Flash Deal',
            });
          }
        });
      }
    } catch (_) {
      // Gracefully stays empty if no active flash sale
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elegant Marketplace — Personalized Home'),
        backgroundColor: const Color(0xFF004D40),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () => Navigator.pushNamed(context, '/buyer/address'),
            tooltip: 'Select Location',
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {},
            tooltip: 'Cart',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Search Bar Shortcut
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: Color(0xFF004D40)),
                    SizedBox(width: 12),
                    Text('Search 50,000+ products in Urdu or English...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    Spacer(),
                    Icon(Icons.mic, color: Colors.grey),
                    SizedBox(width: 8),
                    Icon(Icons.camera_alt, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Hero Campaign Banner Slider
            Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF004D40), Color(0xFF00796B)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFFDB913), borderRadius: BorderRadius.circular(4)),
                          child: const Text('RAMZAN & EID MEGA SALE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black)),
                        ),
                        const SizedBox(height: 8),
                        const Text('Flat Up To 70% Off + Free Delivery', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Use vouchers at checkout for extra savings', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Positioned(
                    right: 20,
                    bottom: 20,
                    child: Icon(Icons.card_giftcard, size: 70, color: Colors.white24),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quick Action Shortcuts Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildShortcutItem(Icons.history, 'Buy Again', Colors.blue),
                _buildShortcutItem(Icons.bolt, 'Flash Sale', Colors.amber.shade800),
                _buildShortcutItem(Icons.local_shipping, 'Free Shipping', Colors.green),
                _buildShortcutItem(Icons.storefront, 'Local Stores', Colors.purple),
              ],
            ),
            const SizedBox(height: 20),

            // Category Quick Filter Chips
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final cat = _categories[i];
                  final isSel = _selectedCategoryChip == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSel,
                    selectedColor: const Color(0xFF004D40),
                    labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black87, fontSize: 12),
                    onSelected: (val) => setState(() => _selectedCategoryChip = cat),
                  );
                },
              ),
            ),
            if (_flashProducts.isNotEmpty) ...[
              const SizedBox(height: 20),
              // Flash Sale Section Header with Realtime Ticker Clock
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.bolt, color: Colors.amber, size: 22),
                      SizedBox(width: 4),
                      Text('Flash Sale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Products Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _flashProducts.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final p = _flashProducts[index];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Center(
                              child: Icon(p['imageIcon'] as IconData, size: 50, color: const Color(0xFF004D40)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(p['title'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(p['price'] as String, style: const TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 6),
                              Text(p['originalPrice'] as String, style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey, fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(p['reason'] as String, style: const TextStyle(color: Colors.grey, fontSize: 9, fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutItem(IconData icon, String label, Color color) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
