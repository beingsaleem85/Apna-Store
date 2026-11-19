import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/app_state_provider.dart';
import '../../../core/widgets/app_footer.dart';

class CategoryProductsScreen extends StatefulWidget {
  const CategoryProductsScreen({super.key});

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final Map<String, bool> _activeFilters = {
    'All': true,
    'Greatask': false,
    'Prospietc Offirts': false,
  };

  void _openProductDetails(BuildContext context, AppProduct product) {
    Navigator.pushNamed(context, '/product', arguments: product);
  }

  List<AppProduct> _getCategoryProducts(String catName, AppStateProvider state) {
    if (catName.trim().isEmpty || catName.trim().toLowerCase() == 'all') {
      return state.activeProducts;
    }
    return state.activeProducts
        .where((p) => p.category.trim().toLowerCase() == catName.trim().toLowerCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final String catName = (args is String && args.isNotEmpty) ? args : 'Mobiles';
    final state = Provider.of<AppStateProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // Filter products dynamically per category
    final categoryProducts = _getCategoryProducts(catName, state);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Utility Strip
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

            // 2. Main Header (Logo, Integrated Search, Actions)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      // Back Navigation Arrow Button
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 22),
                        tooltip: 'Back to Previous Page',
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacementNamed(context, '/');
                          }
                        },
                      ),
                      const SizedBox(width: 8),

                      // Brand Logo
                      InkWell(
                        onTap: () => Navigator.pushReplacementNamed(context, '/'),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Elegant', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), height: 1.0)),
                                Text('Marketplace', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Integrated Search Group
                      Expanded(
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 580),
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText: 'Search products...',
                                      hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0F172A),
                                    borderRadius: BorderRadius.horizontal(right: Radius.circular(7)),
                                  ),
                                  child: const Icon(Icons.search, color: Colors.white, size: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),

                      // Right Header Utilities
                      Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.pushNamed(context, '/buyer/wishlist'),
                            child: Row(
                              children: const [
                                Icon(Icons.favorite_border, size: 20, color: Color(0xFF334155)),
                                SizedBox(width: 6),
                                Text('Wishlist', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          InkWell(
                            onTap: () => Navigator.pushNamed(context, '/buyer/cart'),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.shopping_cart_outlined, size: 22, color: Color(0xFF334155)),
                                Positioned(
                                  right: -6,
                                  top: -6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle),
                                    child: Text(
                                      '${state.orders.length}',
                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          InkWell(
                            onTap: () => Navigator.pushNamed(context, '/buyer'),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                              child: const Icon(Icons.person_outline, size: 18, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Dark Navy Category Nav Bar
            Container(
              width: double.infinity,
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _buildNavCategoryItem('Mobiles', catName),
                      _buildNavCategoryItem('Electronics', catName),
                      _buildNavCategoryItem('Fashion', catName),
                      _buildNavCategoryItem('Home', catName),
                      _buildNavCategoryItem('Beauty', catName),
                      _buildNavCategoryItem('Grocery', catName),
                      _buildNavCategoryItem('Sports', catName),
                      _buildNavCategoryItem('Automotive', catName),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Breadcrumbs Row
            Container(
              width: double.infinity,
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pushNamed(context, '/buyer'),
                        child: const Text('Home', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(catName, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 6),
                      Text(catName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                ),
              ),
            ),

            // 5. Main Body Layout (Left Sidebar + Right Product Grid)
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1280),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Sidebar Panel (Fixed ~240px width)
                    SizedBox(
                      width: 230,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Category',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 14),
                          _buildSidebarCatTile('Mobiles', Icons.smartphone, catName),
                          _buildSidebarCatTile('Electronics', Icons.laptop, catName),
                          _buildSidebarCatTile('Fashion', Icons.checkroom, catName),
                          _buildSidebarCatTile('Home', Icons.home_outlined, catName),
                          _buildSidebarCatTile('Beauty', Icons.sanitizer, catName),
                          _buildSidebarCatTile('Grocery', Icons.shopping_basket_outlined, catName),
                          _buildSidebarCatTile('Sports', Icons.sports_soccer, catName),
                          _buildSidebarCatTile('Automotive', Icons.directions_car_outlined, catName),
                          _buildSidebarCatTile('More', Icons.grid_view, catName),
                          const SizedBox(height: 28),

                          // Filter Section
                          const Text(
                            'Filter',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 12),
                          _buildFilterCheckbox('All'),
                          _buildFilterCheckbox('Greatask'),
                          _buildFilterCheckbox('Prospietc Offirts'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),

                    // Right Main Product Listing Area
                    Expanded(
                      child: Column(
                        children: [
                          // Header: Product Listing Title & Sort Navigation
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Product Listing (${categoryProducts.length})',
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Row(
                                children: [
                                  const Text('Sort by: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  const SizedBox(width: 4),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.chevron_left, size: 16),
                                          onPressed: () {},
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          padding: EdgeInsets.zero,
                                        ),
                                        Container(width: 1, height: 16, color: const Color(0xFFE2E8F0)),
                                        IconButton(
                                          icon: const Icon(Icons.chevron_right, size: 16),
                                          onPressed: () {},
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // 4-Column Responsive Grid
                          categoryProducts.isEmpty
                              ? Container(
                                  height: 300,
                                  alignment: Alignment.center,
                                  child: Text('No products available under "$catName"', style: const TextStyle(color: Color(0xFF64748B))),
                                )
                              : GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 0.62,
                                  ),
                                  itemCount: categoryProducts.length,
                                  itemBuilder: (context, index) {
                                    final prod = index < categoryProducts.length
                                        ? categoryProducts[index]
                                        : null;
                                    return _buildListingProductCard(index, prod, catName);
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            const AppFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildNavCategoryItem(String name, String currentCat) {
    final isSelected = name.toLowerCase() == currentCat.toLowerCase();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.pushReplacementNamed(context, '/category', arguments: name);
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 24.0, top: 4, bottom: 4),
        child: Row(
          children: [
            Text(
              name,
              style: TextStyle(
                color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 14, color: isSelected ? const Color(0xFF38BDF8) : Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarCatTile(String title, IconData icon, String currentCat) {
    final isSelected = title.toLowerCase() == currentCat.toLowerCase();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.pushReplacementNamed(context, '/category', arguments: title);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, size: 14, color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCheckbox(String title) {
    final checked = _activeFilters[title] ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _activeFilters[title] = !checked;
          });
        },
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: Checkbox(
                value: checked,
                onChanged: (v) {
                  setState(() {
                    _activeFilters[title] = v ?? false;
                  });
                },
                activeColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          ],
        ),
      ),
    );
  }

  Widget _buildListingProductCard(int index, AppProduct? realProduct, String catName) {
    final discounts = ['55%', '33%', null, null, null, '20%', '40%', null];
    final images = [
      'https://images.unsplash.com/photo-1592899677977-9c10ca588bbd?w=300',
      'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=300',
      'https://images.unsplash.com/photo-1580910051074-3eb694886505?w=300',
      'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=300',
      'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=300',
      'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=300',
      'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?w=300',
      'https://images.unsplash.com/photo-1618354691373-d851c5c3a990?w=300',
    ];
    final prices = ['PKR 169,0 PKR', 'PKR KX30 PKR', 'PKR 4K80 PKR', 'PKR 4BB0 PKR', 'PKR 169,0 PKR', 'PKR 3465 PKR', 'PKR 3465 PKR', 'PKR 3465 PKR'];
    final ratings = ['3 Ratings', '2 Ratings', '3 Ratings', '3 Ratings', '5 Ratings', '2 Ratings', '4 Ratings', '3 Ratings'];

    final discount = discounts[index % discounts.length];
    final imgUrl = realProduct?.imageUrl ?? images[index % images.length];
    final title = realProduct?.name ?? 'Apple of Five Motors Doltor 4 Moo...';
    final price = realProduct != null ? 'PKR ${realProduct.price}' : prices[index % prices.length];
    final rating = ratings[index % ratings.length];

    final productToPass = realProduct ?? AppProduct(
      id: 'prod_${index}',
      sellerId: 'seller_1',
      name: title,
      price: price.replaceAll(RegExp(r'[^0-9]'), '').isEmpty ? '3455' : price.replaceAll(RegExp(r'[^0-9]'), ''),
      rating: '4.8',
      description: 'High quality premium marketplace product with official warranty and doorstep delivery.',
      imageUrl: imgUrl,
      category: catName,
      variations: [
        ProductVariation(name: 'Color', values: ['Black', 'Blue', 'Silver']),
        ProductVariation(name: 'Storage', values: ['128GB', '256GB']),
      ],
      wholesalePrices: {},
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: () => _openProductDetails(context, productToPass),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      child: Container(
                        color: const Color(0xFFF8FAFC),
                        width: double.infinity,
                        height: 155,
                        child: Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF1F5F9))),
                      ),
                    ),
                    if (discount != null)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFF97316), borderRadius: BorderRadius.circular(4)),
                          child: Text(discount, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    const Positioned(
                      right: 8,
                      top: 8,
                      child: Icon(Icons.favorite_border, size: 16, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      const SizedBox(height: 4),
                      Text(price, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 10, color: Color(0xFFF59E0B)),
                          const Icon(Icons.star, size: 10, color: Color(0xFFF59E0B)),
                          const Icon(Icons.star, size: 10, color: Color(0xFFF59E0B)),
                          const Icon(Icons.star, size: 10, color: Color(0xFFF59E0B)),
                          const Icon(Icons.star, size: 10, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(rating, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: const [
                          Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF94A3B8)),
                          SizedBox(width: 2),
                          Text('Seller Location', style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (index == 0)
          Positioned(
            left: 8,
            bottom: 48,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                children: const [
                  Text('Quick Add-to-Cart', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPremiumFooter(BuildContext context, double screenWidth) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.only(top: 40, bottom: 20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1280),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Customer Care', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        Text('Help Center\nHow to Buy\nCorporate & Bulk Purchasing\nReturns & Refunds\nContact Us', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.8)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Elegant Marketplace', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        Text('About Us\nDigital Payments\nElegant Marketplace Card\nBlogs & News\nTerms & Conditions', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.8)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Sell On Elegant Marketplace', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        Text('Seller Registration\nSeller University\nSell on Global Market\nCode of Conduct', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.8)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Payment & Delivery', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        SizedBox(height: 12),
                        Text('VISA / MasterCard / EasyPaisa / JazzCash / COD Supported nationwide', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, height: 1.6)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Divider(color: Color(0xFF334155)),
              const SizedBox(height: 12),
              const Text('© 2026 Elegant Marketplace. All Rights Reserved.', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
