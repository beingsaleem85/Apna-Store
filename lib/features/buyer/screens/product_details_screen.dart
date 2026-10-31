import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_breakpoints.dart';
import '../../../core/services/app_state_provider.dart';
import '../../../core/widgets/app_footer.dart';
import '../widgets/product/product_buy_actions.dart';
import '../widgets/product/product_gallery.dart';
import '../widgets/product/product_info_section.dart';
import '../widgets/product/product_reviews_section.dart';
import '../widgets/product/product_specifications.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late AppProduct product;
  String _selectedImageUrl = '';
  List<String> _productImages = [];
  bool _isLoading = true;
  int _selectedImageIndex = 0;
  int _selectedQuantity = 1;
  bool _isCustomersExpanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = Provider.of<AppStateProvider>(context, listen: false);
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is AppProduct) {
      product = args;
    } else if (args is Map<String, dynamic>) {
      product = AppProduct(
        id: args['id']?.toString() ?? 'prod_dynamic_${DateTime.now().millisecondsSinceEpoch}',
        sellerId: args['sellerId']?.toString() ?? 'seller_dynamic',
        name: args['title'] ?? args['name'] ?? 'Awesome Product',
        price: args['currentPrice'] ?? args['price'] ?? 'PKR 0',
        rating: args['rating']?.toString() ?? '4.8',
        description: args['description'] ?? 'High quality premium product with advanced features and official warranty.',
        imageUrl: args['imgUrl'] ?? args['imageUrl'] ?? 'https://images.unsplash.com/photo-1592899677977-9c10ca588bbd?w=800',
        category: args['category'] ?? 'Miscellaneous',
        variations: [],
        wholesalePrices: {},
      );
    } else {
      if (state.activeProducts.isNotEmpty) {
        product = state.activeProducts.first;
      } else {
        product = AppProduct(
          id: 'prod_default',
          sellerId: 'seller_1',
          name: 'Apple of The Mobiles 123 Electronics faulsellid D SGR',
          price: '35,00',
          rating: '4.8',
          description: 'High quality premium smartphone with advanced camera setup and official warranty.',
          imageUrl: 'https://images.unsplash.com/photo-1592899677977-9c10ca588bbd?w=800',
          category: 'Mobiles',
          variations: [],
          wholesalePrices: {},
        );
      }
    }

    _selectedImageUrl = product.imageUrl;
    _productImages = [
      if (product.imageUrl.isNotEmpty) product.imageUrl,
      ...?product.additionalImages,
    ];
    if (_productImages.isEmpty) {
      _productImages = [product.imageUrl];
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Widget _buildFilterItem(String title, String count, bool isChecked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isChecked ? const Color(0xFF059669) : Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: isChecked ? const Color(0xFF059669) : const Color(0xFFCBD5E1)),
            ),
            child: isChecked ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: TextStyle(fontSize: 12, color: isChecked ? const Color(0xFF0F172A) : const Color(0xFF475569), fontWeight: isChecked ? FontWeight.bold : FontWeight.normal)),
          ),
          Text(count, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildSellerItem(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
        ],
      ),
    );
  }

  Widget _buildCustomerItem(String title, bool isChecked) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: isChecked ? const Color(0xFF059669) : Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: isChecked ? const Color(0xFF059669) : const Color(0xFFCBD5E1)),
            ),
            child: isChecked ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
          ),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 12, color: isChecked ? const Color(0xFF0F172A) : const Color(0xFF475569), fontWeight: isChecked ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Utility Strip
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

                  // Main Header
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
                                      Text(
                                        'Elegant',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), height: 1.0),
                                      ),
                                      Text(
                                        'Marketplace',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.5),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

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
                                            '${state.cartProducts.length}',
                                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                InkWell(
                                  onTap: () => Navigator.pushReplacementNamed(context, '/'),
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

                  // Breadcrumbs
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
                              onTap: () => Navigator.pushReplacementNamed(context, '/'),
                              child: const Text('Home', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => Navigator.pushReplacementNamed(context, '/category'),
                              child: const Text('Product Listing', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 6),
                            Text(
                              product.name.isNotEmpty ? product.name : 'Product Detail',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Main 3-Column Layout
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Filters Sidebar (~230px)
                          SizedBox(
                            width: 230,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: const [
                                      Text('Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      Icon(Icons.keyboard_arrow_up, size: 18, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildFilterItem('All stones', '31', true),
                                  _buildFilterItem('Electronics', '21', false),
                                  _buildFilterItem('Networkorns', '104', false),
                                  _buildFilterItem('Sexisionine', '13', false),
                                  _buildFilterItem('Sbatistation', '14', false),
                                  _buildFilterItem('Satra Krhatics', '11', false),
                                  const SizedBox(height: 20),
                                  const Divider(color: Color(0xFFF1F5F9)),
                                  const SizedBox(height: 12),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: const [
                                      Text('Seller', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      Icon(Icons.keyboard_arrow_up, size: 18, color: Color(0xFF64748B)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSellerItem('Abeal'),
                                  _buildSellerItem('Silibre'),
                                  _buildSellerItem('DGS'),
                                  _buildSellerItem('Gllite'),
                                  _buildSellerItem('Koda'),
                                  const SizedBox(height: 20),
                                  const Divider(color: Color(0xFFF1F5F9)),
                                  const SizedBox(height: 12),

                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _isCustomersExpanded = !_isCustomersExpanded;
                                      });
                                    },
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Customers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                        Icon(
                                          _isCustomersExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                          size: 18,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_isCustomersExpanded) ...[
                                    const SizedBox(height: 12),
                                    _buildCustomerItem('All Customers', true),
                                    _buildCustomerItem('Verified Buyers', false),
                                    _buildCustomerItem('Repeat Buyers', false),
                                    _buildCustomerItem('Top Reviewers', false),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),

                          // Middle Column: Main Showcase & Thumbnails
                          Expanded(
                            child: ProductGallery(
                              selectedImageUrl: _selectedImageUrl,
                              productImages: _productImages,
                              selectedImageIndex: _selectedImageIndex,
                              onImageSelected: (idx) {
                                setState(() {
                                  _selectedImageIndex = idx;
                                  _selectedImageUrl = _productImages[idx];
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 20),

                          // Right Column: Specs & Seller Card (~300px)
                          SizedBox(
                            width: 300,
                            child: Column(
                              children: [
                                ProductInfoSection(
                                  product: product,
                                  selectedQuantity: _selectedQuantity,
                                  onQuantityChanged: (newQty) {
                                    setState(() {
                                      _selectedQuantity = newQty;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                ProductBuyActions(
                                  state: state,
                                  product: product,
                                  selectedQuantity: _selectedQuantity,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Specifications, Reviews & Questions
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProductSpecificationsSection(product: product),
                          const SizedBox(height: 24),
                          ProductReviewsSection(product: product),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  const AppFooter(),
                ],
              ),
            ),
    );
  }
}
