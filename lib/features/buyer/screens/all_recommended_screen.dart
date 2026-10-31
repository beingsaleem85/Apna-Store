import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/app_state_provider.dart';
import '../../../core/widgets/app_footer.dart';
import '../widgets/dashboard/buyer_auth_dialog.dart';
import 'buyer_dashboard.dart'; // Reusing HoverProductCard

class AllRecommendedScreen extends StatefulWidget {
  const AllRecommendedScreen({super.key});

  @override
  State<AllRecommendedScreen> createState() => _AllRecommendedScreenState();
}

class _AllRecommendedScreenState extends State<AllRecommendedScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateProvider>(context);
    final brandGreen = const Color(0xFF004D40);
    final screenWidth = MediaQuery.of(context).size.width;

    // Filter recommended products (rating >= 4.5, excluding flash sale products to avoid clutter)
    final allRecommended = state.products.where((p) {
      final ratingVal = double.tryParse(p.rating) ?? 0.0;
      final isFlash = p.id.startsWith('flash_');
      final query = _searchQuery.toLowerCase();
      final matchesSearch = p.name.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query) ||
          p.category.toLowerCase().contains(query);
      return ratingVal >= 4.5 && !isFlash && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 1. Top Announcement Bar
          Container(
            width: double.infinity,
            color: brandGreen,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Center(
              child: Text(
                'EXCLUSIVE CAMPAIGN LIVE - SHOP VERIFIED LOCAL SELLERS NATIONWIDE!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),

          // 2. Replicated Daraz Header
          _buildHeader(context, state, brandGreen, screenWidth),

          // Main body content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Breadcrumbs & Header Row
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1680),
                      padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Home', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                              ),
                              const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
                              const Text('All Recommended Products', style: TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Recommended For You',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              Text(
                                '${allRecommended.length} Items Found',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Responsive Products Grid
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1680),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: allRecommended.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(48.0),
                                child: Text(
                                  'No recommended products found matching your search.',
                                  style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
                                ),
                              ),
                            )
                          : GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: screenWidth > 1400
                                    ? 6
                                    : (screenWidth > 1000
                                        ? 5
                                        : (screenWidth > 600 ? 4 : 2)),
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: allRecommended.length,
                              itemBuilder: (context, index) {
                                final product = allRecommended[index];
                                final store = state.stores.firstWhere(
                                  (s) => s.id == product.sellerId,
                                  orElse: () => AppStore(id: product.sellerId, shopName: 'Official Store'),
                                );
                                return HoverProductCard(
                                  product: product,
                                  shopName: store.shopName,
                                  showDiscountBadge: false,
                                  showAddToCart: false,
                                  showOriginalPrice: false,
                                  onTap: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/product',
                                      arguments: product,
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Footer
                  const AppFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Replicated Header
  Widget _buildHeader(BuildContext context, AppStateProvider state, Color brandGreen, double screenWidth) {
    return Container(
      width: double.infinity,
      color: brandGreen,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo
          InkWell(
            onTap: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Apna Store',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // Centered Search Bar
          if (screenWidth > 950) ...[
            const Spacer(),
            SizedBox(
              width: 700,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Color(0xFF1E293B)),
                        decoration: const InputDecoration(
                          hintText: 'Search products, brands and categories...',
                          hintStyle: TextStyle(color: Colors.black38, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),
                    Container(
                      height: double.infinity,
                      width: 50,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFDB913),
                        borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.search, color: Colors.black, size: 18),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
          ] else ...[
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Color(0xFF1E293B)),
                        decoration: const InputDecoration(
                          hintText: 'Search in Recommended...',
                          hintStyle: TextStyle(color: Colors.black38, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),
                    Container(
                      height: double.infinity,
                      width: 45,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFDB913),
                        borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.search, color: Colors.black, size: 16),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],

          // Icons Section
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.favorite_border, color: Colors.white),
                onPressed: () {
                  if (!state.isCustomerLoggedIn) {
                    showCustomerAuthDialog(context, onAuthSuccess: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Wishlist: ${state.wishlistProducts.length} items')),
                      );
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Wishlist: ${state.wishlistProducts.length} items')),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                    onPressed: () {
                      if (!state.isCustomerLoggedIn) {
                        showCustomerAuthDialog(context, onAuthSuccess: () {
                          _showCartBottomSheet(context, brandGreen);
                        });
                      } else {
                        _showCartBottomSheet(context, brandGreen);
                      }
                    },
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFDB913),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${state.cartProducts.length}',
                        style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.person_outline, color: Colors.white),
                onPressed: () {
                  if (!state.isCustomerLoggedIn) {
                    showCustomerAuthDialog(context, onAuthSuccess: () {
                      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                    });
                  } else {
                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Replicated Footer
  Widget _buildFooter(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final footerBg = const Color(0xFF0B5D50);
    final linkColor = const Color(0xFFD1D5DB);

    return Container(
      color: footerBg,
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1680),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  if (screenWidth > 950) {
                    // Desktop layout
                    return Column(
                      children: [
                        // Top Row: 4 Columns of links
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildFooterLinksCol('Quick Links', [
                                'Home',
                                'Categories',
                                'Flash Sale',
                                'New Arrivals',
                                'Best Sellers',
                                'Contact Us'
                              ], linkColor),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildFooterLinksCol('Customer Service', [
                                'My Account',
                                'My Orders',
                                'Wishlist',
                                'Track Order',
                                'Return Policy',
                                'Refund Policy',
                                'FAQs'
                              ], linkColor),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildFooterLinksCol('Seller Center', [
                                'Become a Seller',
                                'Seller Dashboard',
                                'Seller Guidelines',
                                'Commission Policy',
                                'Seller Support'
                              ], linkColor),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildFooterLinksCol('Company', [
                                'About Us',
                                'Privacy Policy',
                                'Terms & Conditions',
                                'Careers',
                                'Blog'
                              ], linkColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        Divider(color: Colors.white.withOpacity(0.1), height: 1),
                        const SizedBox(height: 48),
                        // Middle Row: Brand Intro, Payments, App Downloads
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Follow Us
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Follow Us',
                                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildFollowUsWrap(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 32),
                            // Payments
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'We Accept',
                                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildPaymentsWrap(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 32),
                            // Download App
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Download App',
                                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDownloadAppSec(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 32),
                            // Security Badges
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Trusted & Secure',
                                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildSecurityBadgesWrap(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  } else {
                    // Mobile stacked layout
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Follow Us', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildFollowUsWrap(),
                        const Divider(color: Colors.white12, height: 48),
                        
                        // Links in stacked columns
                        _buildFooterLinksCol('Quick Links', ['Home', 'Categories', 'Flash Sale', 'New Arrivals', 'Contact Us'], linkColor),
                        const SizedBox(height: 24),
                        _buildFooterLinksCol('Customer Service', ['My Account', 'My Orders', 'Wishlist', 'Return Policy', 'FAQs'], linkColor),
                        const SizedBox(height: 24),
                        _buildFooterLinksCol('Seller Center', ['Become a Seller', 'Seller Dashboard', 'Seller Support'], linkColor),
                        
                        const Divider(color: Colors.white12, height: 48),
                        const Text('We Accept', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildPaymentsWrap(),
                        
                        const Divider(color: Colors.white12, height: 48),
                        const Text('Download App', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildDownloadAppSec(),

                        const Divider(color: Colors.white12, height: 48),
                        const Text('Trusted & Secure', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildSecurityBadgesWrap(),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 48),
              Divider(color: Colors.white.withOpacity(0.1), height: 1),
              const SizedBox(height: 32),
              // Bottom Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (screenWidth > 600) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '© 2026 Apna Store. All Rights Reserved.',
                              style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
                            ),
                            const SizedBox(width: 48),
                            const Text(
                              'Made with ❤️ in Pakistan',
                              style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
                            ),
                          ],
                        );
                      } else {
                        return const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '© 2026 Apna Store. All Rights Reserved.',
                              style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Made with ❤️ in Pakistan',
                              style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 11),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  Row(
                    children: ['Privacy Policy', 'Terms', 'Cookies'].map((term) => Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Text(
                        term,
                        style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLinksCol(String title, List<String> links, Color linkColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...links.map((link) => Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: InkWell(
                onTap: () {},
                hoverColor: Colors.transparent,
                child: Text(
                  link,
                  style: TextStyle(color: linkColor, fontSize: 12),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildFollowUsWrap() {
    final List<Map<String, String>> socialIcons = [
      {'name': 'Facebook', 'url': 'https://img.icons8.com/color/48/facebook-new.png'},
      {'name': 'Instagram', 'url': 'https://img.icons8.com/color/48/instagram-new.png'},
      {'name': 'YouTube', 'url': 'https://img.icons8.com/color/48/youtube-play.png'},
      {'name': 'TikTok', 'url': 'https://img.icons8.com/color/48/tiktok.png'},
      {'name': 'WhatsApp', 'url': 'https://img.icons8.com/color/48/whatsapp.png'},
      {'name': 'LinkedIn', 'url': 'https://img.icons8.com/color/48/linkedin.png'},
    ];
    return Wrap(
      spacing: 12,
      children: socialIcons.map((social) {
        bool isHovered = false;
        return StatefulBuilder(
          builder: (context, setStateHover) {
            return InkWell(
              onTap: () {},
              onHover: (hover) {
                setStateHover(() {
                  isHovered = hover;
                });
              },
              child: AnimatedScale(
                scale: isHovered ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isHovered ? Colors.white : Colors.white10,
                    shape: BoxShape.circle,
                  ),
                  child: Image.network(
                    social['url']!,
                    width: 18,
                    height: 18,
                  ),
                ),
              ),
            );
          }
        );
      }).toList(),
    );
  }

  Widget _buildPaymentsWrap() {
    final List<String> logoPaths = [
      'https://img.icons8.com/color/48/visa.png',
      'https://img.icons8.com/color/48/mastercard.png',
      'assets/images/paypak.png',
      'assets/images/jazzcash.png',
      'assets/images/easypaisa.png',
      'https://img.icons8.com/color/48/cash-on-delivery.png',
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: logoPaths.map((path) {
        final isAsset = path.startsWith('assets/');
        return Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(6),
          child: ClipOval(
            child: isAsset
                ? Image.asset(
                    path,
                    fit: BoxFit.contain,
                  )
                : Image.network(
                    path,
                    fit: BoxFit.contain,
                  ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDownloadAppSec() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.all(4),
          child: const Icon(Icons.qr_code_2, color: Colors.black, size: 48),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {},
              child: Image.asset(
                'assets/images/google_play.png',
                height: 25,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () {},
              child: Image.asset(
                'assets/images/app_store.png',
                height: 25,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityBadgesWrap() {
    final List<Map<String, String>> badges = [
      {'name': 'SSL Secure', 'path': 'assets/images/ssl_secure.png'},
      {'name': 'PCI DSS', 'path': 'assets/images/pci_dss.png'},
      {'name': '100% Secure Payments', 'path': 'assets/images/secure_payment.png'},
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: badges.map((badge) {
        return Tooltip(
          message: badge['name']!,
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(6),
            child: ClipOval(
              child: Image.asset(
                badge['path']!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showCartBottomSheet(BuildContext context, Color goldColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<AppStateProvider>(
          builder: (context, state, child) {
            final double subtotal = state.cartProducts.fold(0.0, (sum, p) => sum + (double.tryParse(p.price) ?? 0.0));
            final double shippingFee = state.cartProducts.isEmpty ? 0.0 : 150.0;
            final double total = subtotal + shippingFee;

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Shopping Cart (${state.cartProducts.length} items)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: state.cartProducts.isEmpty
                        ? const Center(
                            child: Text('Your cart is empty', style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.builder(
                            itemCount: state.cartProducts.length,
                            itemBuilder: (context, index) {
                              final p = state.cartProducts[index];
                              return Card(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 60, height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.grey,
                                          borderRadius: BorderRadius.circular(8),
                                          image: DecorationImage(
                                            image: NetworkImage(p.imageUrl),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Text('${p.price} PKR', style: TextStyle(color: goldColor, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                        onPressed: () {
                                          state.removeFromCart(p.id);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Subtotal (${state.cartProducts.length} items)'),
                            Text('${subtotal.toInt()} PKR', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Shipping Fee'),
                            Text('${shippingFee.toInt()} PKR', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('${total.toInt()} PKR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: goldColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: goldColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: state.cartProducts.isEmpty
                          ? null
                          : () {
                              Navigator.pop(context);
                              _showCheckoutDialog(context, state.cartProducts.first, state);
                            },
                      child: const Text('Proceed to Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _showCheckoutDialog(BuildContext context, AppProduct product, AppStateProvider state) {
    final goldColor = Theme.of(context).primaryColor;
    final addressController = TextEditingController(text: 'Model Town, Lahore');
    final voucherController = TextEditingController();
    String paymentMethod = 'COD';
    String shippingSpeed = 'Standard';
    int installmentMonths = 3;
    double calculatedDiscount = 0.0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateCheckout) {
            final double basePrice = double.parse(product.price);
            final double finalAmount = basePrice - calculatedDiscount;

            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: goldColor),
              ),
              title: const Text('Checkout'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text('Base Price: ${product.price} PKR', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87, fontSize: 13)),
                    const Divider(color: Colors.black12, height: 20),
                    
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(labelText: 'Delivery Address', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    
                    DropdownButtonFormField<String>(
                      value: paymentMethod,
                      decoration: const InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'COD', child: Text('Cash on Delivery (COD)')),
                        DropdownMenuItem(value: 'Prepaid', child: Text('Pay via Apna Wallet')),
                        DropdownMenuItem(value: 'BNPL', child: Text('BNPL (3-Month Installments)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setStateCheckout(() {
                            paymentMethod = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    DropdownButtonFormField<String>(
                      value: shippingSpeed,
                      decoration: const InputDecoration(labelText: 'Shipping Speed', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Standard', child: Text('Standard (3-5 Days) - Rs. 150')),
                        DropdownMenuItem(value: 'Express', child: Text('Express (Next Day) - Rs. 300')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setStateCheckout(() {
                            shippingSpeed = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: voucherController,
                            decoration: const InputDecoration(labelText: 'Voucher Code', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final code = voucherController.text.trim().toUpperCase();
                            if (code.isEmpty) return;
                            final result = await state.validateVoucherOnline(code: code, subtotal: basePrice);
                            if (!context.mounted) return;
                            if (result.isValid) {
                              setStateCheckout(() {
                                calculatedDiscount = result.discountAmount;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Voucher Applied: -$calculatedDiscount PKR'), backgroundColor: Colors.green),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result.errorMessage ?? 'Invalid Voucher Code!'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: goldColor),
                          child: const Text('Apply', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.black12, height: 24),
                    
                    if (calculatedDiscount > 0)
                      Text('Coupon Discount: -$calculatedDiscount PKR', style: const TextStyle(color: Colors.greenAccent, fontSize: 13)),
                    Text(
                      'Total Payable Amount: ${finalAmount.toInt()} PKR',
                      style: TextStyle(color: goldColor, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (paymentMethod == 'Prepaid' && state.walletCash < finalAmount) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Insufficient Wallet Balance!'), backgroundColor: Colors.red),
                      );
                      return;
                    }

                    if (paymentMethod == 'BNPL') {
                      state.chargeBnpl(finalAmount, installmentMonths);
                    }

                    state.placeOrder(
                      productId: product.id,
                      sellerId: product.sellerId,
                      buyerName: state.loggedInCustomerName ?? 'Ali Khan',
                      address: addressController.text,
                      shippingSpeed: shippingSpeed,
                      paymentMethod: paymentMethod,
                      couponDiscount: calculatedDiscount,
                    );
                    state.clearCart();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Order has been finalized!'), backgroundColor: Colors.green),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: goldColor),
                  child: const Text('Confirm Order', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
