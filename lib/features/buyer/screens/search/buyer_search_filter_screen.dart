import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/app_state_provider.dart';

class BuyerSearchFilterScreen extends StatefulWidget {
  const BuyerSearchFilterScreen({super.key});

  @override
  State<BuyerSearchFilterScreen> createState() => _BuyerSearchFilterScreenState();
}

class _BuyerSearchFilterScreenState extends State<BuyerSearchFilterScreen> {
  final TextEditingController _searchController = TextEditingController(text: '');
  RangeValues _priceRange = const RangeValues(1000, 150000);
  bool _onlyCod = false;
  bool _onlyFreeShipping = false;
  double _minRating = 0.0;
  bool _showComparisonModal = false;

  final List<String> _recentSearches = [
    'Lawn 3 Piece Suit',
    'Bluetooth Headphones',
    'Air Fryer 5L',
    'Smart Watch',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateProvider>(context);
    final query = _searchController.text.trim().toLowerCase();

    // Dynamically filter active products from AppStateProvider
    final filteredProducts = state.activeProducts.where((product) {
      // 1. Search Query Match
      final nameMatch = product.name.toLowerCase().contains(query);
      final descMatch = product.description.toLowerCase().contains(query);
      final catMatch = product.category.toLowerCase().contains(query);
      if (query.isNotEmpty && !nameMatch && !descMatch && !catMatch) {
        return false;
      }

      // 2. Price Range Match
      final priceVal = double.tryParse(product.price) ?? 0.0;
      if (priceVal < _priceRange.start || priceVal > _priceRange.end) {
        return false;
      }

      // 3. Rating Match
      final ratingVal = double.tryParse(product.rating.split(' ').first) ?? 5.0;
      if (ratingVal < _minRating) {
        return false;
      }

      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Intelligent Search & Filter Engine'),
        backgroundColor: const Color(0xFF004D40),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            onPressed: () => setState(() => _showComparisonModal = !_showComparisonModal),
            tooltip: 'Product Comparison Matrix',
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showFilterDrawer(context),
            tooltip: 'Filters',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar Input with Voice & Visual Triggers
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search in English, Urdu or Roman Urdu...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF004D40)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.mic),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Listening to voice in Urdu/English...')),
                    );
                  },
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  icon: const Icon(Icons.qr_code_scanner),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Camera Barcode / Visual Search Activated')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Recent Searches Chips
            const Text('Recent Searches:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _recentSearches.map((s) {
                return ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 11)),
                  onPressed: () => setState(() => _searchController.text = s),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Comparison Matrix if Toggled
            if (_showComparisonModal) ...[
              if (filteredProducts.length >= 2)
                Card(
                  color: Colors.amber.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.amber)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.compare_arrows, color: Colors.amber),
                            SizedBox(width: 8),
                            Text('Side-by-Side Product Comparison Matrix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Table(
                          border: TableBorder.all(color: Colors.amber.shade200),
                          children: [
                            TableRow(
                              children: [
                                const Padding(padding: EdgeInsets.all(6), child: Text('Feature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Padding(padding: const EdgeInsets.all(6), child: Text(filteredProducts[0].name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                Padding(padding: const EdgeInsets.all(6), child: Text(filteredProducts[1].name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            TableRow(
                              children: [
                                const Padding(padding: EdgeInsets.all(6), child: Text('Price', style: TextStyle(fontSize: 11))),
                                Padding(padding: const EdgeInsets.all(6), child: Text('Rs. ${filteredProducts[0].price}', style: const TextStyle(fontSize: 11, color: Color(0xFF004D40), fontWeight: FontWeight.bold))),
                                Padding(padding: const EdgeInsets.all(6), child: Text('Rs. ${filteredProducts[1].price}', style: const TextStyle(fontSize: 11, color: Color(0xFF004D40), fontWeight: FontWeight.bold))),
                              ],
                            ),
                            TableRow(
                              children: [
                                const Padding(padding: EdgeInsets.all(6), child: Text('Category', style: TextStyle(fontSize: 11))),
                                Padding(padding: const EdgeInsets.all(6), child: Text(filteredProducts[0].category, style: const TextStyle(fontSize: 11))),
                                Padding(padding: const EdgeInsets.all(6), child: Text(filteredProducts[1].category, style: const TextStyle(fontSize: 11))),
                              ],
                            ),
                            TableRow(
                              children: [
                                const Padding(padding: EdgeInsets.all(6), child: Text('Rating', style: TextStyle(fontSize: 11))),
                                Padding(padding: const EdgeInsets.all(6), child: Text('${filteredProducts[0].rating} ⭐', style: const TextStyle(fontSize: 11))),
                                Padding(padding: const EdgeInsets.all(6), child: Text('${filteredProducts[1].rating} ⭐', style: const TextStyle(fontSize: 11))),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '⚠️ Please search or filter to show at least 2 matching products for side-by-side comparison.',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade800),
                  ),
                ),
              const SizedBox(height: 20),
            ],

            // Search Results Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Search Results (${filteredProducts.length} Products Found)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.filter_list, size: 16),
                  label: const Text('Filters'),
                  onPressed: () => _showFilterDrawer(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search Results List View
            if (filteredProducts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                alignment: Alignment.center,
                child: Column(
                  children: const [
                    Icon(Icons.search_off, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No products found matching your search query.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredProducts.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  final priceVal = double.tryParse(product.price) ?? 0.0;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/product',
                        arguments: product,
                      );
                    },
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                product.imageUrl.isNotEmpty ? product.imageUrl : 'https://images.unsplash.com/photo-1531403009284-440f080d1e12?w=600&auto=format&fit=crop&q=60',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, e, st) => Container(
                                  width: 60,
                                  height: 60,
                                  color: const Color(0xFF004D40).withOpacity(0.1),
                                  child: const Icon(Icons.image, color: Color(0xFF004D40)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text('Rs. ${priceVal.toInt()}', style: const TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text('${product.rating} ⭐ | Category: ${product.category}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _onlyFreeShipping || priceVal >= 3000 ? 'Delivery: Free Shipping | COD Available' : 'Delivery: Rs. 150 | COD Available',
                                    style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  void _showFilterDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter Search Results', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              Text('Price Range: Rs. ${_priceRange.start.round()} - Rs. ${_priceRange.end.round()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              RangeSlider(
                values: _priceRange,
                min: 5000,
                max: 150000,
                divisions: 29,
                activeColor: const Color(0xFF004D40),
                labels: RangeLabels('Rs. ${_priceRange.start.round()}', 'Rs. ${_priceRange.end.round()}'),
                onChanged: (val) {
                  setModalState(() => _priceRange = val);
                  setState(() => _priceRange = val);
                },
              ),
              const SizedBox(height: 12),

              SwitchListTile(
                title: const Text('Cash on Delivery (COD) Only', style: TextStyle(fontSize: 13)),
                value: _onlyCod,
                activeColor: const Color(0xFF004D40),
                onChanged: (val) {
                  setModalState(() => _onlyCod = val);
                  setState(() => _onlyCod = val);
                },
              ),
              SwitchListTile(
                title: const Text('Free Shipping Only', style: TextStyle(fontSize: 13)),
                value: _onlyFreeShipping,
                activeColor: const Color(0xFF004D40),
                onChanged: (val) {
                  setModalState(() => _onlyFreeShipping = val);
                  setState(() => _onlyFreeShipping = val);
                },
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
