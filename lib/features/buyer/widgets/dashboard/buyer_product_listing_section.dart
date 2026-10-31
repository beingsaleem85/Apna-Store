import 'package:flutter/material.dart';
import '../../../../core/services/app_state_provider.dart';
import '../../../../core/constants/app_breakpoints.dart';

class BuyerProductListingSection extends StatefulWidget {
  final AppStateProvider state;
  final double screenWidth;
  final String selectedCategory;
  final String searchQuery;
  final TextEditingController searchController;
  final ValueChanged<String> onSelectCategory;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearSearch;

  const BuyerProductListingSection({
    super.key,
    required this.state,
    required this.screenWidth,
    required this.selectedCategory,
    required this.searchQuery,
    required this.searchController,
    required this.onSelectCategory,
    required this.onSearchSubmitted,
    required this.onClearSearch,
  });

  @override
  State<BuyerProductListingSection> createState() => _BuyerProductListingSectionState();
}

class _BuyerProductListingSectionState extends State<BuyerProductListingSection> {
  final Map<String, bool> _activeBrands = {
    'Samsung': false,
    'Apple': false,
    'Xiaomi': false,
    'Infinix': false,
    'Realme': false,
  };

  Widget _buildSidebarCatTile(String title, IconData icon) {
    final isSelected = widget.selectedCategory == title || (title == 'Mobiles' && widget.selectedCategory == 'All');
    return InkWell(
      onTap: () => widget.onSelectCategory(title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF059669) : const Color(0xFF64748B)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF059669) : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCheckbox(String title) {
    final isChecked = _activeBrands[title] ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _activeBrands[title] = !isChecked;
          });
        },
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: isChecked,
                onChanged: (val) {
                  setState(() {
                    _activeBrands[title] = val ?? false;
                  });
                },
                activeColor: const Color(0xFF059669),
              ),
            ),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          ],
        ),
      ),
    );
  }

  List<AppProduct> _getCategoryProducts(AppStateProvider state, String catName, String query) {
    List<AppProduct> list = state.activeProducts;
    if (catName != 'All' && catName.isNotEmpty) {
      list = list.where((p) => p.category.toLowerCase() == catName.toLowerCase()).toList();
    }
    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list.where((p) => p.name.toLowerCase().contains(q) || p.description.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Widget _buildListingProductCard(BuildContext context, AppProduct product, AppStateProvider state) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.pushNamed(context, '/product', arguments: product);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                  child: Container(
                    height: 155,
                    width: double.infinity,
                    color: const Color(0xFFF8FAFC),
                    child: Image.network(
                      product.imageUrl.isNotEmpty ? product.imageUrl : 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=600',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFF1F5F9),
                        child: const Icon(Icons.image_outlined, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), height: 1.3),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'PKR ${product.price}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            product.rating,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final catName = widget.selectedCategory == 'All' ? 'Mobiles' : widget.selectedCategory;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Utility Bar
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1280),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pushNamed(context, '/seller/landing'),
                      child: const Text('Sell on Platform', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () => Navigator.pushNamed(context, '/buyer/chat-qa'),
                      child: const Text('Help Center', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () => Navigator.pushNamed(context, '/buyer/order-tracking'),
                      child: const Text('Track Order', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    ),
                    const SizedBox(width: 16),
                    const Text('English / اردو', style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),

          // Main Header Row
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1280),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    InkWell(
                      onTap: widget.onClearSearch,
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(Icons.grid_view_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Elegant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.0)),
                              Text('Marketplace', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.5)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Container(
                          width: AppBreakpoints.getResponsiveDialogWidth(context, defaultDesktopWidth: 580),
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: widget.searchController,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                                  decoration: const InputDecoration(
                                    hintText: 'Search products...',
                                    hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                  ),
                                  onSubmitted: widget.onSearchSubmitted,
                                ),
                              ),
                              InkWell(
                                onTap: () => widget.onSearchSubmitted(widget.searchController.text),
                                child: Container(
                                  width: 44,
                                  height: 42,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF059669),
                                    borderRadius: BorderRadius.horizontal(right: Radius.circular(7)),
                                  ),
                                  child: const Icon(Icons.search, color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Product Listing Body
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1280),
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Sidebar Filters (Desktop)
                  if (widget.screenWidth > 850)
                    SizedBox(
                      width: 230,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Categories', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 10),
                          _buildSidebarCatTile('Mobiles', Icons.phone_iphone_outlined),
                          _buildSidebarCatTile('Electronics', Icons.laptop_mac_outlined),
                          _buildSidebarCatTile('Fashion', Icons.checkroom_outlined),
                          _buildSidebarCatTile('Home', Icons.chair_outlined),
                          _buildSidebarCatTile('Beauty', Icons.sanitizer_outlined),
                          _buildSidebarCatTile('Grocery', Icons.shopping_bag_outlined),
                          _buildSidebarCatTile('Sports', Icons.sports_basketball_outlined),
                          _buildSidebarCatTile('Automotive', Icons.directions_car_outlined),
                          const SizedBox(height: 24),
                          const Text('Brand Filter', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 8),
                          _buildFilterCheckbox('Samsung'),
                          _buildFilterCheckbox('Apple'),
                          _buildFilterCheckbox('Xiaomi'),
                          _buildFilterCheckbox('Infinix'),
                          _buildFilterCheckbox('Realme'),
                        ],
                      ),
                    ),

                  if (widget.screenWidth > 850) const SizedBox(width: 24),

                  // Right Product Grid Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.searchQuery.isNotEmpty ? 'Search Results for "${widget.searchQuery}"' : catName,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            Builder(
                              builder: (context) {
                                final products = _getCategoryProducts(widget.state, catName, widget.searchQuery);
                                return Text('${products.length} Items Found', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)));
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            final rawProducts = _getCategoryProducts(widget.state, catName, widget.searchQuery);
                            final selectedBrands = _activeBrands.entries.where((e) => e.value).map((e) => e.key.toLowerCase()).toList();
                            final filtered = selectedBrands.isEmpty
                                ? rawProducts
                                : rawProducts.where((p) => selectedBrands.any((b) => p.name.toLowerCase().contains(b))).toList();
                            final displayList = filtered.isEmpty && selectedBrands.isEmpty ? rawProducts : filtered;

                            if (displayList.isEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(48),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFF94A3B8)),
                                    SizedBox(height: 12),
                                    Text('No products found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                    SizedBox(height: 4),
                                    Text('Try adjusting your category or search filters.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  ],
                                ),
                              );
                            }

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: widget.screenWidth > 1100 ? 4 : (widget.screenWidth > 700 ? 3 : 2),
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: 0.62,
                              ),
                              itemCount: displayList.length,
                              itemBuilder: (context, index) => _buildListingProductCard(context, displayList[index], widget.state),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
