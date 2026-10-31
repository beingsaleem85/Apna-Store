import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_breakpoints.dart';
import 'dart:async';
import '../../../core/widgets/responsive_builder.dart';
import '../../../core/services/app_state_provider.dart';
import '../../../core/widgets/dev_version_banner.dart';
import '../../../core/widgets/app_footer.dart';
import '../../../core/widgets/add_to_cart_success_dialog.dart';
import '../../../core/config/feature_flags.dart';
import '../widgets/dashboard/buyer_dashboard_header.dart';
import '../widgets/dashboard/buyer_dashboard_categories.dart';
import '../widgets/dashboard/buyer_dashboard_banner_carousel.dart';
import '../widgets/dashboard/buyer_dashboard_product_sections.dart';
import '../widgets/dashboard/buyer_dashboard_recommendations.dart';
import '../widgets/dashboard/buyer_dashboard_navigation.dart';
import '../widgets/dashboard/buyer_auth_dialog.dart';
import '../widgets/dashboard/buyer_dashboard_widgets.dart';
import '../widgets/dashboard/buyer_product_listing_section.dart';
import '../widgets/dashboard/buyer_account_section.dart';
import '../widgets/dashboard/buyer_orders_chat_section.dart';

part '../widgets/dashboard/buyer_dashboard_cards.dart';



class BuyerDashboard extends StatefulWidget {
  const BuyerDashboard({super.key});

  @override
  State<BuyerDashboard> createState() => _BuyerDashboardState();
}

class _BuyerDashboardState extends State<BuyerDashboard> {
  int _selectedIndex = 0;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  double _maxPriceFilter = 100000;
  final Map<String, bool> _activeFilters = {'All': true, 'Greatask': false, 'Prospietc Offirts': false};
  
  // Controllers & Inputs
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _budgetLimitController = TextEditingController();

  // Dialog / Scanner States
  bool _isListeningVoice = false;
  bool _isScanningBarcode = false;
  bool _isMegaMenuOpen = false;
  String? _activeNavMegaCat;

  // Auto-Sliding Hero Banners State
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;

  final List<Map<String, String>> _heroBanners = [
    {
      'tag': 'SPECIAL OFFER',
      'title': r'Special Offer Him $150',
      'desc': 'Get fashion style special offer on this e-commerce platform with the best deal prices.',
      'btn': 'Call on Offer',
      'image': 'https://images.unsplash.com/photo-1592899677977-9c10ca588bbd?w=400',
      'color1': '0xFF064E3B',
      'color2': '0xFF047857',
    },
    {
      'tag': 'MEGA TECH SALE 50% OFF',
      'title': 'Latest Electronics & Devices',
      'desc': 'Upgrade your gadgets with premium smartphones, laptops & wireless headphones.',
      'btn': 'Explore Tech',
      'image': 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400',
      'color1': '0xFF0F172A',
      'color2': '0xFF1E293B',
    },
    {
      'tag': 'EXCLUSIVE DEAL',
      'title': '100% Farm Fresh Groceries',
      'desc': 'Fresh organic fruits, vegetables, and daily essentials delivered within 2 hours.',
      'btn': 'Order Grocery',
      'image': 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400',
      'color1': '0xFF065F46',
      'color2': '0xFF059669',
    },
    {
      'tag': 'SUMMER FASHION',
      'title': 'Trending Luxury Collection',
      'desc': 'Discover modern fashion apparel, sneakers, and designer accessories.',
      'btn': 'Shop Fashion',
      'image': 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=400',
      'color1': '0xFF312E81',
      'color2': '0xFF4338CA',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startBannerTimer();
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _currentBannerIndex = (_currentBannerIndex + 1) % _heroBanners.length;
        });
      }
    });
  }

  void _nextBanner() {
    setState(() {
      _currentBannerIndex = (_currentBannerIndex + 1) % _heroBanners.length;
    });
    _startBannerTimer();
  }

  void _previousBanner() {
    setState(() {
      _currentBannerIndex = (_currentBannerIndex - 1 + _heroBanners.length) % _heroBanners.length;
    });
    _startBannerTimer();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _searchController.dispose();
    _budgetLimitController.dispose();
    super.dispose();
  }

  List<Widget> _getPages(AppStateProvider state) {
    return [
      _buildBuyerHome(state),
      _buildOrdersAndChat(state),
      _buildProfileAndSupport(state),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateProvider>(context);
    final theme = Theme.of(context);
    final goldColor = Theme.of(context).primaryColor;

    return Column(
      children: [
        const DevVersionBanner(),
        Expanded(
          child: PopScope(
            canPop: _selectedIndex == 0,
            onPopInvoked: (didPop) {
              if (!didPop && _selectedIndex != 0) {
                setState(() {
                  _selectedIndex = 0;
                });
              }
            },
            child: Scaffold(
              appBar: null,
              body: Stack(
                children: [
                  _getPages(state)[_selectedIndex],
                  if (_isScanningBarcode) _buildBarcodeScannerOverlay(state),
                  if (_isMegaMenuOpen) _buildMegaMenuOverlay(state),
                ],
              ),
              bottomNavigationBar: MediaQuery.of(context).size.width <= 600
                  ? BottomNavigationBar(
                      backgroundColor: Theme.of(context).cardColor,
                      currentIndex: _selectedIndex,
                      selectedItemColor: goldColor,
                      unselectedItemColor: Colors.grey.shade600,
                      onTap: (index) {
                        if (index > 0 && !state.isCustomerLoggedIn) {
                          showCustomerAuthDialog(context, onAuthSuccess: () {
                            setState(() {
                              _selectedIndex = index;
                            });
                          });
                        } else {
                          setState(() {
                            _selectedIndex = index;
                          });
                        }
                      },
                      items: [
                        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                        BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
                        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
                      ],
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // ONBOARDING DIALOG
  // ==========================================
  void _showOnboardingDialog() {
    final goldColor = Theme.of(context).primaryColor;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: goldColor),
          ),
          title: Row(
            children: [
              Icon(Icons.stars, color: goldColor),
              SizedBox(width: 8),
              Text('Onboarding Guide'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome to our premium multi-vendor shopping system.', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text('• Easy navigation and English support.\n• Biometric login and account switching.\n• Real final cost and price comparisons.', style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: goldColor, foregroundColor: Colors.black),
              child: Text('Get Started', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPhaseNavChip(BuildContext context, String label, String route, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: const Color(0xFF004D40)),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF004D40),
        ),
      ),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFFDB913)),
      elevation: 2,
      onPressed: () => Navigator.pushNamed(context, route),
    );
  }

  // ==========================================
  // TAB 1: BUYER HOME (ELEGANT MARKETPLACE LAYOUT)
  // ==========================================
  Widget _buildBuyerHome(AppStateProvider state) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (_selectedCategory != 'All' || _searchQuery.isNotEmpty) {
      return _buildProductListingScreen(state, screenWidth);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Utility Strip (Aligned to 1280px container)
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

          // 2. Main Header Row (Aligned to 1280px container)
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
                    // Brand Logo (Elegant Marketplace with Green M Mark)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _searchQuery = '';
                          _selectedCategory = 'All';
                          _searchController.clear();
                        });
                      },
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
                              Text(
                                'Elegant',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.0),
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
                    const SizedBox(width: 16),

                    // Integrated Search Bar + Search Button
                    Expanded(
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 580),
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
                                  controller: _searchController,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                                  onSubmitted: (val) {
                                    if (val.trim().isNotEmpty) {
                                      setState(() {
                                        _searchQuery = val.trim();
                                      });
                                    }
                                  },
                                  decoration: const InputDecoration(
                                    hintText: 'Search products...',
                                    hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  final text = _searchController.text.trim();
                                  setState(() {
                                    _searchQuery = text;
                                  });
                                },
                                child: Container(
                                  height: double.infinity,
                                  width: 48,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF0F172A),
                                    borderRadius: BorderRadius.horizontal(right: Radius.circular(7)),
                                  ),
                                  child: const Icon(Icons.search, color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                      // Header Icons (Wishlist, Cart, Profile)
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCategory = 'Mobiles';
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Wishlist Items Filtered!'),
                                  backgroundColor: Color(0xFF0F172A),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: const Row(
                              children: [
                                Icon(Icons.favorite_border, size: 18, color: Color(0xFF334155)),
                                SizedBox(width: 4),
                                Text('Wishlist', style: TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.shopping_cart_outlined, size: 20, color: Color(0xFF334155)),
                                onPressed: () => _showCartBottomSheet(context, const Color(0xFF059669)),
                              ),
                              Positioned(
                                right: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEA580C),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${state.cartProducts.length}',
                                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _selectedIndex = 2; // Profile & Support Tab (Buyer Account)
                              });
                            },
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Color(0xFFF1F5F9),
                                  child: Icon(Icons.person_outline, size: 18, color: Color(0xFF334155)),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Profile',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 3 & 4. Dark Navy Category Navigation & Floating Mega Menu Container (Auto Dismiss on Mouse Exit)
          MouseRegion(
            onExit: (_) {
              setState(() {
                _activeNavMegaCat = null;
              });
            },
            child: Column(
              children: [
                // Dark Navy Category Navigation Bar (Aligned to 1280px container)
                Container(
                  width: double.infinity,
                  color: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildNavCategoryItem('Mobiles'),
                            _buildNavCategoryItem('Electronics'),
                            _buildNavCategoryItem('Fashion'),
                            _buildNavCategoryItem('Home & Living'),
                            _buildNavCategoryItem('Beauty'),
                            _buildNavCategoryItem('Grocery'),
                            _buildNavCategoryItem('Sports'),
                            _buildNavCategoryItem('Automotive'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Main Body Content with Floating Mega Menu Overlay (Zero Layout Shift)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      children: [
                        Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 1280),
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Hero Banner Section (Auto-Rotating 3-Second Multi-Banner Carousel)
                                const AutoSlidingBanner(),
                                const SizedBox(height: 24),

                                // 8 Category Icon Cards Grid (Production Quality - Responsive Desktop/Tablet/Mobile)
                                _buildResponsiveCategoryGrid(context),
                                const SizedBox(height: 32),

                                // Flash Sale Section (Production Marketplace Quality - Daraz/Amazon/Noon/Temu level)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              'Flash Sale',
                                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5),
                                            ),
                                            const SizedBox(width: 12),
                                            _buildTimerBadge('02'),
                                            _buildTimerBadge('14'),
                                            _buildTimerBadge('29'),
                                          ],
                                        ),
                                        _ViewAllHeaderButton(
                                          onTap: () => Navigator.pushNamed(context, '/category', arguments: 'Flash Sale'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    _buildResponsiveProductGrid(
                                      context,
                                      [
                                        {
                                          'title': 'Sitimars Pro Wireless Earbuds Active Noise Cancelling',
                                          'currentPrice': 'PKR 3,455',
                                          'originalPrice': 'PKR 5,750',
                                          'discount': '40% OFF',
                                          'imgUrl': 'https://images.unsplash.com/photo-1592899677977-9c10ca588bbd?w=300',
                                          'rating': 4.8,
                                          'reviews': 342,
                                          'soldCount': '1.2k Sold',
                                        },
                                        {
                                          'title': 'Ultra HD Smart Watch Series 8 Display Heart Rate',
                                          'currentPrice': 'PKR 3,455',
                                          'originalPrice': 'PKR 4,930',
                                          'discount': '30% OFF',
                                          'imgUrl': 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=300',
                                          'rating': 4.7,
                                          'reviews': 850,
                                          'soldCount': '850 Sold',
                                        },
                                        {
                                          'title': 'Aitinass Premium Ergonomic Mechanical Gaming Keyboard',
                                          'currentPrice': 'PKR 3,455',
                                          'originalPrice': 'PKR 5,750',
                                          'discount': '40% OFF',
                                          'imgUrl': 'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?w=300',
                                          'rating': 4.9,
                                          'reviews': 1240,
                                          'soldCount': '2.1k Sold',
                                          'badgeGradient': const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                                        },
                                        {
                                          'title': 'Sitimars HD Portable Bluetooth Speaker Waterproof Bass',
                                          'currentPrice': 'PKR 3,555',
                                          'originalPrice': 'PKR 5,070',
                                          'discount': '30% OFF',
                                          'imgUrl': 'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=300',
                                          'rating': 4.6,
                                          'reviews': 512,
                                          'soldCount': '1.5k Sold',
                                        },
                                        {
                                          'title': 'Sitimars Fast Wireless Charging Stand 15W Dock',
                                          'currentPrice': 'PKR 3,455',
                                          'originalPrice': 'PKR 4,930',
                                          'discount': '30% OFF',
                                          'imgUrl': 'https://images.unsplash.com/photo-1565849904461-04a58ad377e0?w=300',
                                          'rating': 4.8,
                                          'reviews': 420,
                                          'soldCount': '640 Sold',
                                        },
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 36),

                                // Official Stores Section (5 Cards Full Width Span)
                                Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Official Stores',
                                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5),
                                        ),
                                        ViewAllHeaderButton(
                                          title: 'Explore Stores',
                                          onTap: () => Navigator.pushNamed(context, '/category', arguments: 'Official Stores'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    _buildResponsiveOfficialStoresGrid(context),
                                  ],
                                ),
                                const SizedBox(height: 36),

                                // 4 Campaign Banners Grid (4 Cards: Trending Products, Featured Products, Seasonal Campaign, Special Offers)
                                _build4CampaignBannersGrid(context),
                                const SizedBox(height: 36),

                                // Recommended for You Section (Production Marketplace Quality)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Recommended for You',
                                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5),
                                        ),
                                        ViewAllHeaderButton(
                                          title: 'View All',
                                          onTap: () => Navigator.pushNamed(context, '/buyer/recommended'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    _buildResponsiveProductGrid(
                                      context,
                                      [
                                        {
                                          'title': 'Afreless Urban Casual Oversized Hoodie Sweatshirt',
                                          'currentPrice': 'PKR 4,466',
                                          'imgUrl': 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=300',
                                          'rating': 4.8,
                                          'reviews': 240,
                                          'soldCount': '950 Sold',
                                        },
                                        {
                                          'title': 'Alionass 5G Smartphone Dual SIM 128GB AMOLED',
                                          'currentPrice': 'PKR 3,465',
                                          'imgUrl': 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=300',
                                          'rating': 4.9,
                                          'reviews': 780,
                                          'soldCount': '1.8k Sold',
                                        },
                                        {
                                          'title': 'Ahinass Pro ANC Wireless Headphones Over-Ear',
                                          'currentPrice': 'PKR 3,465',
                                          'imgUrl': 'https://images.unsplash.com/photo-1580910051074-3eb694886505?w=300',
                                          'rating': 4.7,
                                          'reviews': 140,
                                          'soldCount': '430 Sold',
                                        },
                                        {
                                          'title': 'Ahouars Men Cotton Running Shoes Sneakers Soft Sole',
                                          'currentPrice': 'PKR 3,406',
                                          'imgUrl': 'https://images.unsplash.com/photo-1556905055-8f358a7a47b2?w=300',
                                          'rating': 4.8,
                                          'reviews': 310,
                                          'soldCount': '1.1k Sold',
                                        },
                                        {
                                          'title': 'Premium Cotton Fleece Sweatshirt Winter Collection',
                                          'currentPrice': 'PKR 3,465',
                                          'imgUrl': 'https://images.unsplash.com/photo-1618354691373-d851c5c3a990?w=300',
                                          'rating': 4.9,
                                          'reviews': 620,
                                          'soldCount': '780 Sold',
                                        },
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),

                        // 5. Trust Section (Secure Payments, Easy Returns, Verified Sellers, Delivery)
                        _buildTrustSection(),
                      ],
                    ),

                    // Floating Overlay Mega Dropdown Menu (Floats over Hero Banner with zero layout shift)
                    if (_activeNavMegaCat != null)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: MouseRegion(
                          onExit: (_) {
                            setState(() {
                              _activeNavMegaCat = null;
                            });
                          },
                          child: _buildFloatingMegaMenuOverlay(_activeNavMegaCat!),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 6. Restored Premium Footer Section
          const AppFooter(),
        ],
      ),
    );
  }

  Widget _build4CampaignBannersGrid(BuildContext context) {
    return const BuyerCampaignBannersGrid();
  }

  Widget _buildNavCategoryItem(String name) {
    final isActive = _activeNavMegaCat == name;
    IconData iconData = Icons.grid_view_rounded;
    if (name == 'Mobiles') iconData = Icons.smartphone_rounded;
    if (name == 'Electronics') iconData = Icons.laptop_mac_rounded;
    if (name == 'Fashion') iconData = Icons.checkroom_rounded;
    if (name == 'Home & Living' || name == 'Home') iconData = Icons.chair_rounded;
    if (name == 'Beauty') iconData = Icons.sanitizer_rounded;
    if (name == 'Grocery') iconData = Icons.shopping_bag_rounded;
    if (name == 'Sports') iconData = Icons.sports_basketball_rounded;
    if (name == 'Automotive') iconData = Icons.directions_car_rounded;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _activeNavMegaCat = name;
        });
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _activeNavMegaCat = isActive ? null : name;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF059669) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(iconData, size: 14, color: isActive ? Colors.white : Colors.white70),
              const SizedBox(width: 6),
              Text(
                name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isActive ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 14,
                color: isActive ? Colors.white : Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingMegaMenuOverlay(String catName) {
    final Map<String, Map<String, List<String>>> megaData = {
      'Mobiles': {
        'Smartphones': ['Flagship Phones', 'Budget Mobiles', '5G Smartphones', 'Gaming Phones'],
        'Accessories': ['Fast Chargers', 'Power Banks', 'Screen Protectors', 'Covers & Cases'],
        'Audio & Wearables': ['Wireless Earbuds', 'Smartwatches', 'Bluetooth Speakers', 'Handsfree'],
        'Tablets & iPads': ['Android Tablets', 'iPads', 'Kids Tablets', 'Stylus Pens'],
      },
      'Electronics': {
        'Laptops & PCs': ['Gaming Laptops', 'Ultrabooks', 'Workstations', 'All-in-One PCs'],
        'TV & Home Audio': ['4K Smart TVs', 'Soundbars', 'Home Theaters', 'Streaming Devices'],
        'Gaming Gear': ['PlayStation 5', 'Xbox Consoles', 'Gaming Mice', 'Mechanical Keyboards'],
        'Cameras & Drones': ['DSLR Cameras', 'Action Cameras', 'Vlogging Kits', 'Security Cameras'],
      },
      'Fashion': {
        'Men\'s Fashion': ['T-Shirts & Polos', 'Casual Shirts', 'Jeans & Trousers', 'Jackets & Hoodies'],
        'Women\'s Fashion': ['Unstitched Lawn', 'Ready to Wear Kurtis', 'Abayas & Hijabs', 'Western Wear'],
        'Footwear': ['Sneakers', 'Formal Shoes', 'Sandals & Chappals', 'Heels & Flats'],
        'Watches & Jewelry': ['Luxury Watches', 'Sunglasses', 'Rings & Chains', 'Handbags & Purses'],
      },
      'Home & Living': {
        'Furniture': ['Sofa Sets', 'Dining Tables', 'Beds & Mattresses', 'Office Chairs'],
        'Kitchen & Appliances': ['Air Fryers', 'Juicers & Blenders', 'Cookware Sets', 'Dinner Sets'],
        'Home Decor': ['Wall Art', 'LED Lights', 'Carpets & Rugs', 'Indoor Plants'],
        'Bedding & Bath': ['Bed Sheets', 'Comforters & Blankets', 'Pillows', 'Bath Towels'],
      },
      'Home': {
        'Furniture': ['Sofa Sets', 'Dining Tables', 'Beds & Mattresses', 'Office Chairs'],
        'Kitchen & Appliances': ['Air Fryers', 'Juicers & Blenders', 'Cookware Sets', 'Dinner Sets'],
        'Home Decor': ['Wall Art', 'LED Lights', 'Carpets & Rugs', 'Indoor Plants'],
        'Bedding & Bath': ['Bed Sheets', 'Comforters & Blankets', 'Pillows', 'Bath Towels'],
      },
      'Beauty': {
        'Skincare': ['Face Serums', 'Sunscreens', 'Cleansers & Wash', 'Moisturizers'],
        'Makeup': ['Lipsticks & Gloss', 'Foundations', 'Eye Palettes', 'Mascaras'],
        'Hair Care': ['Shampoos & Conditioners', 'Hair Oils', 'Hair Dryers', 'Straighteners'],
        'Fragrances': ['Men\'s Perfumes', 'Women\'s Perfumes', 'Body Sprays', 'Attars & Oils'],
      },
      'Grocery': {
        'Fresh & Organic': ['Seasonal Fruits', 'Fresh Vegetables', 'Organic Herbs', 'Exotic Fruits'],
        'Pantry Essentials': ['Rice & Grains', 'Pulses & Dal', 'Cooking Oil & Ghee', 'Flour (Atta)'],
        'Snacks & Beverages': ['Tea & Coffee', 'Juices & Soda', 'Chips & Biscuits', 'Chocolates'],
        'Household Cleaners': ['Laundry Detergents', 'Dishwash Liquids', 'Surface Cleaners', 'Tissues'],
      },
      'Sports': {
        'Fitness & Gym': ['Dumbbells & Weights', 'Treadmills', 'Resistance Bands', 'Yoga Mats'],
        'Cricket & Outdoor': ['Cricket Bats', 'Leather Balls', 'Kits & Guards', 'Footballs'],
        'Cycling & Skating': ['Mountain Bikes', 'Helmets', 'Skateboards', 'Electric Scooters'],
        'Sportswear': ['Gym Hoodies', 'Tracksuits', 'Athletic Socks', 'Water Bottles'],
      },
      'Automotive': {
        'Car Care & Oils': ['Car Shampoos', 'Polishes & Waxes', 'Microfiber Towels', 'Car Vacuums'],
        'Car Electronics': ['Dash Cameras', 'Bluetooth Car Kits', 'Car Speakers', 'GPS Trackers'],
        'Car Accessories': ['Waterproof Covers', 'Seat Covers', 'Floor Mats', 'Air Fresheners'],
        'Bike Accessories': ['Riding Helmets', 'Biker Gloves', 'LED Headlights', 'Bike Covers'],
      },
    };

    final subGroups = megaData[catName] ?? {};

    return MouseRegion(
      onExit: (_) {
        setState(() {
          _activeNavMegaCat = null;
        });
      },
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1280),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _activeNavMegaCat == catName ? 1.0 : 0.0,
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(minHeight: 290, maxHeight: 520),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Compact Header: "Shop Mobiles"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Shop $catName',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          setState(() => _activeNavMegaCat = null);
                          Navigator.pushNamed(context, '/category', arguments: catName);
                        },
                        child: Row(
                          children: const [
                            Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF059669)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 14),

                  // 4 Evenly Spaced Full Width Columns (Full 100% Grid)
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: subGroups.entries.map((group) {
                          final groupTitle = group.key;
                          final items = group.value;

                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    groupTitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF059669), // Brand Primary Color
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...items.map((item) {
                                    return MegaMenuItemWidget(
                                      title: item,
                                      subItems: const ['Latest Deals', 'Best Sellers', 'Discounted Items'],
                                      onSelectSubItem: (sub) {
                                        setState(() {
                                          _activeNavMegaCat = null;
                                          Navigator.pushNamed(context, '/category', arguments: sub);
                                        });
                                      },
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(String name, IconData icon, {bool isSelected = false}) {
    return BuyerCategoryCardItem(name: name, icon: icon, isSelected: isSelected);
  }

  Widget _buildResponsiveCategoryGrid(BuildContext context) {
    return BuyerResponsiveCategoryGrid(
      selectedCategory: _selectedCategory,
      onSelectCategory: (catName) {
        setState(() {
          _selectedCategory = catName;
        });
      },
    );
  }


  Widget _buildFeatureQuickBar(BuildContext context) {
    return BuyerDashboardQuickBar(
      onHomeTap: () {
        setState(() {
          _selectedIndex = 0;
          _selectedCategory = 'All';
          _searchQuery = '';
        });
      },
      onAccountTap: () => setState(() => _selectedIndex = 2),
    );
  }

  Widget _buildQuickNavChip(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        avatar: Icon(icon, size: 14, color: const Color(0xFF0F172A)),
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        onPressed: onTap,
      ),
    );
  }

  // ==========================================
  // PRODUCT LISTING PAGE (EXACT SCREENSHOT MATCH)
  // ==========================================
  Widget _buildProductListingScreen(AppStateProvider state, double screenWidth) {
    return BuyerProductListingSection(
      state: state,
      screenWidth: screenWidth,
      selectedCategory: _selectedCategory,
      searchQuery: _searchQuery,
      searchController: _searchController,
      onSelectCategory: (cat) => setState(() => _selectedCategory = cat),
      onSearchSubmitted: (q) => setState(() => _searchQuery = q),
      onClearSearch: () => setState(() {
        _searchQuery = '';
        _selectedCategory = 'All';
        _searchController.clear();
      }),
    );
  }

  Widget _buildSidebarCatTile(String title, IconData icon) {
    final isSelected = _selectedCategory == title || (_selectedCategory == 'All' && title == 'Mobiles');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.pushNamed(context, '/category', arguments: title);
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

  void _openProductDetails(BuildContext context, String name, String price, String imgUrl) {
    final cleanPrice = price.replaceAll(RegExp(r'[^0-9]'), '');
    final pPrice = cleanPrice.isEmpty ? '3455' : cleanPrice;
    final product = AppProduct(
      id: 'prod_${name.hashCode.abs()}',
      sellerId: 'seller_1',
      name: name,
      price: pPrice,
      rating: '4.8',
      description: 'High quality premium marketplace product with official warranty, doorstep delivery, and authentic seller guarantee.',
      imageUrl: imgUrl,
      category: 'Mobiles',
      variations: [
        ProductVariation(name: 'Color', values: ['Black', 'Blue', 'Silver']),
        ProductVariation(name: 'Storage', values: ['128GB', '256GB']),
      ],
      wholesalePrices: {},
    );
    Navigator.pushNamed(context, '/product', arguments: product);
  }

  Widget _buildListingProductCard(int index, AppStateProvider state) {
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
    final imgUrl = images[index % images.length];
    final price = prices[index % prices.length];
    final rating = ratings[index % ratings.length];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: () {
            _openProductDetails(context, 'Apple of Five Motors Doltor 4 Moo...', price, imgUrl);
          },
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
                      const Text('Apple of Five Motors Doltor 4 Moo...', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      const SizedBox(height: 4),
                      Text(price, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 10, color: Color(0xFFF59E0B)),
                          const Icon(Icons.star, size: 10, color: Color(0xFFF59E0B)),
                          const Icon(Icons.star, size: 10, color: Color(0xFFF59E0B)),
                          const Icon(Icons.star, size: 10, color: Color(0xFFF59E0B)),
                          const Icon(Icons.star, size: 10, color: Color(0xFFCBD5E1)),
                          const SizedBox(width: 4),
                          Text(rating, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 10, color: Color(0xFF64748B)),
                          SizedBox(width: 2),
                          Text('Seller Location', style: TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Tooltip Popup Badge for Card 0 (Quick Add-to-Cart)
        if (index == 0)
          Positioned(
            bottom: -16,
            left: 12,
            right: 12,
            child: InkWell(
              onTap: () {
                state.addToCart(AppProduct(
                  id: 'prod_${DateTime.now().millisecondsSinceEpoch}',
                  name: 'Apple of Five Motors Doltor 4 Moo...',
                  category: 'Mobiles',
                  price: '3455',
                  rating: '4.8',
                  imageUrl: imgUrl,
                  description: 'High quality product on Elegant Marketplace',
                  sellerId: 'seller_1',
                  variations: const [],
                  wholesalePrices: const {},
                ));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Item added to Cart!'),
                    backgroundColor: Color(0xFF059669),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Quick Add-to-Cart',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTimerBadge(String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(val, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildResponsiveProductGrid(BuildContext context, List<Map<String, dynamic>> products) {
    return BuyerResponsiveProductGrid(products: products);
  }

  Widget _buildResponsiveOfficialStoresGrid(BuildContext context) {
    return const BuyerResponsiveOfficialStoresGrid();
  }

  Widget _buildCategoryListItem(String title, IconData icon, AppStateProvider state) {
    final goldColor = const Color(0xFFFFD700);
    final isSelected = _selectedCategory == title || (title == 'All Categories' && _selectedCategory == 'All');
    return ListTile(
      leading: Icon(icon, color: isSelected ? goldColor : Colors.white70),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? goldColor : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        setState(() {
          _selectedCategory = title == 'All Categories' ? 'All' : title;
        });
      },
    );
  }

  Widget _buildShortcutsBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildShortcutItem(Icons.history, 'Buy Again', Colors.blue),
        _buildShortcutItem(Icons.bolt, 'Flash Sale', Colors.amber.shade800),
        _buildShortcutItem(Icons.local_shipping, 'Free Shipping', Colors.green),
        _buildShortcutItem(Icons.storefront, 'Local Stores', Colors.purple),
      ],
    );
  }

  Widget _buildShortcutItem(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGridBlock(String title, String imageUrl, AppStateProvider state) {
    final goldColor = const Color(0xFFFFD700);
    final isSelected = _selectedCategory == title;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = isSelected ? 'All' : title;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? goldColor : Colors.white.withOpacity(0.08), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(color: const Color(0xFF1E1E1E));
                  },
                ),
              ),
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.45),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryMobileItem(String title, IconData icon, AppStateProvider state) {
    final goldColor = const Color(0xFFFFD700);
    final isSelected = _selectedCategory == title;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ChoiceChip(
        avatar: Icon(icon, color: isSelected ? Colors.black : goldColor),
        label: Text(title),
        selected: isSelected,
        selectedColor: goldColor,
        backgroundColor: const Color(0xFF1E1E1E),
        labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white),
        onSelected: (val) {
          setState(() {
            _selectedCategory = val ? title : 'All';
          });
        },
      ),
    );
  }



  Widget _buildIndicatorDot(bool active) {
    return Container(
      width: active ? 12 : 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: active ? Theme.of(context).primaryColor : Colors.white30,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildSidebarCategoryItem(String title, IconData icon) {
    final goldColor = Theme.of(context).primaryColor;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = _selectedCategory == title ? 'All' : title;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            Icon(icon, size: 16, color: _selectedCategory == title ? goldColor : Colors.white70),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: _selectedCategory == title ? goldColor : Colors.white70,
                  fontWeight: _selectedCategory == title ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 8, color: _selectedCategory == title ? goldColor : Colors.white30),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterColumn(String title, List<String> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
        ),
        SizedBox(height: 8),
        ...links.map((link) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Text(
                link,
                style: TextStyle(fontSize: 10, color: const Color(0xFF64748B)),
              ),
            )),
      ],
    );
  }


  // ==========================================
  // TAB 2: ORDERS, CHATS & DELIVERIES
  // ==========================================
  Widget _buildOrdersAndChat(AppStateProvider state) {
    final screenWidth = MediaQuery.of(context).size.width;
    return BuyerOrdersChatSection(
      state: state,
      screenWidth: screenWidth,
      onGoHome: () => setState(() => _selectedIndex = 0),
    );
  }

  // ==========================================
  // TAB 3: CLEAN PROFESSIONAL CUSTOMER ACCOUNT HUB
  // ==========================================
  Widget _buildProfileAndSupport(AppStateProvider state) {
    final screenWidth = MediaQuery.of(context).size.width;
    return BuyerAccountSection(
      state: state,
      screenWidth: screenWidth,
      onGoHome: () => setState(() => _selectedIndex = 0),
      onShowCart: () => _showCartBottomSheet(context, const Color(0xFF004D40)),
    );
  }

  Widget _buildBuyerSidebarItem(IconData icon, String label, bool isActive, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFD1FAE5) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        leading: Icon(icon, size: 18, color: isActive ? const Color(0xFF059669) : const Color(0xFF475569)),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? const Color(0xFF059669) : const Color(0xFF334155),
          ),
        ),
        onTap: onTap ?? () {},
      ),
    );
  }

  Widget _buildBuyerOrderRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required String price,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          // Icon Circle
          SizedBox(
            width: 48,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFF1F5F9),
              child: Icon(icon, size: 18, color: const Color(0xFF334155)),
            ),
          ),

          // Service Details
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),

          // Status Badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                ),
              ),
            ),
          ),

          // Action Link
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, '/buyer/order-tracking'),
                child: const Text(
                  'View Order Details',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                ),
              ),
            ),
          ),

          // Price
          Expanded(
            flex: 2,
            child: Text(
              price,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountHubCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: iconBg,
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF004D40).withOpacity(0.08),
        child: Icon(icon, color: const Color(0xFF004D40), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildPrefDropdown(String label, String currentVal, List<String> options, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: currentVal,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      dropdownColor: Theme.of(context).cardColor,
      items: options.map((opt) {
        return DropdownMenuItem(value: opt, child: Text(opt));
      }).toList(),
      onChanged: onChanged,
    );
  }

  // ==========================================
  // HELPER MODALS & DIALOGS
  // ==========================================

  void _showProductDetailsDialog(BuildContext context, AppProduct product, AppStateProvider state) {
    final goldColor = Theme.of(context).primaryColor;
    final isCompared = state.comparisonProductIds.contains(product.id);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: goldColor.withAlpha(120)),
              ),
              title: Row(
                children: [
                  Expanded(child: Text(product.name, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  IconButton(
                    icon: Icon(Icons.close, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // High-quality image gallery structure (with indicators)
                      Stack(
                        children: [
                          Container(
                            height: 250,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: NetworkImage(product.imageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(4, (index) => Container(
                                width: 8,
                                height: 8,
                                margin: EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index == 0 ? goldColor : Colors.white54,
                                ),
                              )),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Transparent Pricing Display
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${product.price} PKR', style: TextStyle(color: goldColor, fontSize: 24, fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
                          Text('${(double.parse(product.price) * 1.5).toStringAsFixed(0)} PKR', style: TextStyle(color: Colors.grey, fontSize: 14, decoration: TextDecoration.lineThrough)),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text('-33%', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      // Delivery / Shipping mock
                      Row(
                        children: [
                          Icon(Icons.local_shipping, size: 16, color: Colors.green),
                          SizedBox(width: 4),
                          Text('Free Shipping on orders over 1000 PKR', style: TextStyle(fontSize: 12, color: Colors.green)),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(product.description, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87, fontSize: 13)),
                      Divider(color: Colors.black12, height: 24),
                      
                      // Product Variations Selection
                      Text('Variations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 8),
                      Text('Color: Black', style: TextStyle(fontSize: 12)),
                      SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(label: Text('Black'), selected: true, selectedColor: goldColor.withOpacity(0.2)),
                          ChoiceChip(label: Text('White'), selected: false),
                          ChoiceChip(label: Text('Blue'), selected: false),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text('Size: Medium', style: TextStyle(fontSize: 12)),
                      SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(label: Text('Small'), selected: false),
                          ChoiceChip(label: Text('Medium'), selected: true, selectedColor: goldColor.withOpacity(0.2)),
                          ChoiceChip(label: Text('Large'), selected: false),
                        ],
                      ),
                      Divider(color: Colors.black12, height: 24),

                      // Custom Price History Chart (Fake Discount warning checker)
                      Text('Honest Price Chart (Price History):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87)),
                      SizedBox(height: 10),
                      _buildCustomPriceChart(state.getPriceHistory(product.id)),
                      SizedBox(height: 4),
                      Text('Congratulations! This discount is 100% honest and free from fake markups.', style: TextStyle(color: Colors.greenAccent, fontSize: 10)),
                      Divider(color: Colors.black12, height: 24),
                    ],
                  ),
                ),
              ),
              actions: [
                // Compare toggle chip button
                ActionChip(
                  avatar: Icon(isCompared ? Icons.check : Icons.add, size: 14),
                  label: Text(isCompared ? 'Add ' : 'Product Comparison'),
                  onPressed: () {
                    state.toggleComparison(product.id);
                    setStateDialog(() {});
                  },
                ),
                ElevatedButton(
                  onPressed: product.stock > 0
                      ? () {
                          state.addToCart(product);
                          showAddToCartSuccessDialog(context, product: product);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004D40),
                    foregroundColor: Colors.white,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_cart, size: 14),
                      SizedBox(width: 4),
                      Text('Add to Cart', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: product.stock > 0
                      ? () {
                          Navigator.pop(context);
                          _showCheckoutDialog(context, product, state);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: goldColor, foregroundColor: Colors.black),
                  child: const Text('Buy Now', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAllFlashSaleProducts(BuildContext context, List<AppProduct> products, AppStateProvider state) {
    showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'All Flash Sale Products',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: screenWidth > 1100
                          ? 5
                          : (screenWidth > 800
                              ? 4
                              : (screenWidth > 500 ? 3 : 2)),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final store = state.stores.firstWhere(
                        (s) => s.id == product.sellerId,
                        orElse: () => AppStore(id: product.sellerId, shopName: 'Official Store'),
                      );
                      return HoverProductCard(
                        product: product,
                        shopName: store.shopName,
                        showDiscountBadge: true,
                        showAddToCart: false,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/product', arguments: product);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomPriceChart(List<double> prices) {
    // Renders custom bars matching prices
    final maxVal = prices.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: prices.map((price) {
          final double percentage = price / maxVal;
          return Container(
            width: 32,
            height: 60 * percentage,
            color: Theme.of(context).primaryColor.withAlpha((255 * percentage).toInt()),
            child: Center(
              child: Text(
                '${price.toInt()}',
                style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }).toList(),
      ),
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
              title: Text('Checkout'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 6),
                    Text('Base Price: ${product.price} PKR', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87, fontSize: 13)),
                    Divider(color: Colors.black12, height: 20),
                    
                    TextField(
                      controller: addressController,
                      decoration: InputDecoration(labelText: 'Delivery Address', border: OutlineInputBorder()),
                    ),
                    SizedBox(height: 12),
                    
                    DropdownButtonFormField<String>(
                      value: paymentMethod,
                      decoration: InputDecoration(labelText: 'Payment Method', border: OutlineInputBorder()),
                      dropdownColor: Theme.of(context).cardColor,
                      items: [
                        const DropdownMenuItem(value: 'COD', child: Text('Cash on Delivery (COD)')),
                        const DropdownMenuItem(value: 'Prepaid', child: Text('Prepaid (Wallet Balance)')),
                        if (state.bnplStatus == 'Approved')
                          const DropdownMenuItem(value: 'BNPL', child: Text('Interest-Free Easy Installments (BNPL)')),
                      ],
                      onChanged: (val) {
                        setStateCheckout(() {
                          paymentMethod = val!;
                        });
                      },
                    ),
                    SizedBox(height: 12),
                    
                    // Show BNPL Calculator if selected
                    if (paymentMethod == 'BNPL') ...[
                      DropdownButtonFormField<int>(
                        value: installmentMonths,
                        decoration: InputDecoration(labelText: 'Installment Tenure', border: OutlineInputBorder()),
                        dropdownColor: Theme.of(context).cardColor,
                        items: [
                          DropdownMenuItem(value: 3, child: Text('3 Months (0% Interest)')),
                          DropdownMenuItem(value: 6, child: Text('6 Months (0% Interest)')),
                        ],
                        onChanged: (val) {
                          setStateCheckout(() {
                            installmentMonths = val!;
                          });
                        },
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Monthly Installment: ${(finalAmount / installmentMonths).toInt()} PKR/Month',
                        style: TextStyle(color: goldColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Divider(color: Colors.black12, height: 16),
                    ],

                    DropdownButtonFormField<String>(
                      value: shippingSpeed,
                      decoration: InputDecoration(labelText: 'Shipping Coverage', border: OutlineInputBorder()),
                      dropdownColor: Theme.of(context).cardColor,
                      items: [
                        DropdownMenuItem(value: 'Standard', child: Text('Standard Delivery (2-4 Days)')),
                        DropdownMenuItem(value: 'Express', child: Text('Express Delivery (24 Hours)')),
                      ],
                      onChanged: (val) {
                        setStateCheckout(() {
                          shippingSpeed = val!;
                        });
                      },
                    ),
                    SizedBox(height: 12),

                    // Voucher Check
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: voucherController,
                            decoration: InputDecoration(
                              labelText: 'Enter Coupon Code',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final code = voucherController.text.trim();
                            if (code.isEmpty) return;
                            final result = await state.validateVoucherOnline(code: code, subtotal: finalAmount);
                            if (result.isValid) {
                              setStateCheckout(() {
                                calculatedDiscount = result.discountAmount;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: goldColor, foregroundColor: Colors.black),
                          child: Text('Apply'),
                        ),
                      ],
                    ),
                    Divider(color: Colors.black12, height: 24),
                    
                    if (calculatedDiscount > 0)
                      Text('Coupon Discount: -$calculatedDiscount PKR', style: TextStyle(color: Colors.greenAccent, fontSize: 13)),
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
                      buyerName: 'Ali Khan',
                      address: addressController.text,
                      shippingSpeed: shippingSpeed,
                      paymentMethod: paymentMethod,
                      couponDiscount: calculatedDiscount,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Order has been finalized!'), backgroundColor: Colors.green),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: goldColor, foregroundColor: Colors.black),
                  child: Text('Finalize Order', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // SPECIFIC POPUPS & SIDE-BY-SIDE COMPARE
  // ==========================================
  void _showComparisonSheet(BuildContext context, AppStateProvider state) {
    final goldColor = Theme.of(context).primaryColor;
    final List<AppProduct> compareList = state.products
        .where((p) => state.comparisonProductIds.contains(p.id))
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Product Comparison (Comparison Grid)', style: TextStyle(color: goldColor, fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(Icons.clear_all, color: Colors.redAccent),
                        onPressed: () {
                          state.clearComparison();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: compareList.isEmpty
                        ? Center(child: Text('No products selected for comparison.'))
                        : Table(
                            border: TableBorder.all(color: Colors.black12),
                            children: [
                              TableRow(
                                children: [
                                  Padding(padding: EdgeInsets.all(8.0), child: Text('Specs', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ...compareList.map((p) => Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(p.name, style: TextStyle(fontWeight: FontWeight.bold)),
                                      )),
                                ],
                              ),
                              TableRow(
                                children: [
                                  Padding(padding: EdgeInsets.all(8.0), child: Text('Price')),
                                  ...compareList.map((p) => Padding(padding: const EdgeInsets.all(8.0), child: Text('${p.price} PKR', style: TextStyle(color: goldColor)))),
                                ],
                              ),
                              TableRow(
                                children: [
                                  Padding(padding: EdgeInsets.all(8.0), child: Text('Rating')),
                                  ...compareList.map((p) => Padding(padding: const EdgeInsets.all(8.0), child: Text('⭐ ${p.rating}'))),
                                ],
                              ),
                              TableRow(
                                children: [
                                  Padding(padding: EdgeInsets.all(8.0), child: Text('Stock')),
                                  ...compareList.map((p) => Padding(padding: const EdgeInsets.all(8.0), child: Text('${p.stock} pcs'))),
                                ],
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _simulateVoiceSearch() {
    if (!FeatureFlags.voiceAssistantEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice Search feature is disabled (Feature Flag OFF). Speech recognition integration required.')),
      );
      return;
    }
    setState(() {
      _isListeningVoice = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic, size: 64, color: Theme.of(context).primaryColor),
              SizedBox(height: 16),
              Text('Listening for voice query...', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );

    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pop(context);
      setState(() {
        _isListeningVoice = false;
      });
    });
  }

  Widget _buildBarcodeScannerOverlay(AppStateProvider state) {
    if (!FeatureFlags.barcodeScannerIntegrationEnabled) {
      return Container(
        color: Colors.black.withOpacity(0.9),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner, size: 80, color: Colors.grey),
              const SizedBox(height: 20),
              const Text('Barcode Scanner Hardware Integration Disabled (Feature Flag OFF)', style: TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => setState(() => _isScanningBarcode = false),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner, size: 100, color: Theme.of(context).primaryColor),
            SizedBox(height: 20),
            Text('Barcode Scanner Active', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
      ),
    );
  }

  void _showReturnDialog(BuildContext context, String orderId, AppStateProvider state) {
    final goldColor = Theme.of(context).primaryColor;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: goldColor),
          ),
          title: Text('Submit Return Request'),
          content: TextField(
            controller: reasonController,
            decoration: InputDecoration(labelText: 'Write Return Reason', border: OutlineInputBorder()),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                state.requestReturn(orderId, reasonController.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Request received, refund transferred to wallet!'), backgroundColor: Colors.green),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: goldColor, foregroundColor: Colors.black),
              child: Text('Send Request'),
            ),
          ],
        );
      },
    );
  }

  void _showReviewDialog(BuildContext context, String productId, AppStateProvider state) {
    final goldColor = Theme.of(context).primaryColor;
    double stars = 5.0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateReview) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: goldColor),
              ),
              title: Text('Submit Rating & Review'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Select your rating stars:'),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1.0;
                      return IconButton(
                        icon: Icon(
                          stars >= starValue ? Icons.star : Icons.star_border,
                          color: goldColor,
                        ),
                        onPressed: () {
                          setStateReview(() {
                            stars = starValue;
                          });
                        },
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () {
                    state.rateProduct(productId, stars.toString());
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Thank you very much for submitting your review!')),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: goldColor, foregroundColor: Colors.black),
                  child: Text('Submit Review'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openChatDialog(BuildContext context, String buyerName, String sellerId, AppStateProvider state) {
    final goldColor = Theme.of(context).primaryColor;
    final msgController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateChat) {
            final chatList = state.getChatroom(buyerName, sellerId);
            
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: goldColor.withAlpha(100)),
              ),
              title: Text('Direct Chat with Seller'),
              content: SizedBox(
                width: 400,
                height: 400,
                child: Column(
                  children: [
                    Expanded(
                      child: chatList.isEmpty
                          ? Center(child: Text('Start conversation.'))
                          : ListView.builder(
                              itemCount: chatList.length,
                              itemBuilder: (context, index) {
                                final chat = chatList[index];
                                final isBuyer = chat.sender == 'buyer';
                                return Align(
                                  alignment: isBuyer ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isBuyer ? goldColor : const Color(0xFF252528),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      chat.message,
                                      style: TextStyle(
                                        color: isBuyer ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Divider(color: Colors.black12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: msgController,
                            decoration: InputDecoration(hintText: 'Write message...'),
                            onSubmitted: (_) {
                              final text = msgController.text.trim();
                              if (text.isNotEmpty) {
                                state.sendMessage(buyerName, sellerId, text, 'buyer');
                                msgController.clear();
                                Future.delayed(const Duration(milliseconds: 200), () {
                                  setStateChat(() {});
                                });
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send, color: goldColor),
                          onPressed: () {
                            final text = msgController.text.trim();
                            if (text.isNotEmpty) {
                              state.sendMessage(buyerName, sellerId, text, 'buyer');
                              msgController.clear();
                              Future.delayed(const Duration(milliseconds: 200), () {
                                  setStateChat(() {});
                                });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label = status;

    switch (status) {
      case 'Pending':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        label = 'Approval Pending';
        break;
      case 'Confirmed':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        label = 'Order Approved';
        break;
      case 'Packed':
        bg = Colors.purple.shade100;
        fg = Colors.purple.shade900;
        label = 'Packed';
        break;
      case 'ReadyToShip':
        bg = Colors.teal.shade100;
        fg = Colors.teal.shade900;
        label = 'Ready for Shipment';
        break;
      case 'Shipped':
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
        label = 'Shipped';
        break;
      case 'Delivered':
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        label = 'Delivered';
        break;
      case 'Returned':
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        label = 'Return Completed';
        break;
      case 'Cancelled':
      default:
        bg = Colors.grey.shade300;
        fg = Colors.black87;
        label = 'Cancelled';
    }

    return Chip(
      label: Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
      backgroundColor: bg,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildNavCategoryLink(String title, [IconData? icon]) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = _selectedCategory == title ? 'All' : title;
          });
        },
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: _selectedCategory == title ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87),
              SizedBox(width: 4),
            ],
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: _selectedCategory == title ? FontWeight.bold : FontWeight.normal,
                color: _selectedCategory == title ? Theme.of(context).primaryColor : Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustItem(IconData icon, String title, {bool isGold = false}) {
    return Row(
      children: [
        Icon(icon, color: isGold ? Colors.orangeAccent : Colors.white, size: 16),
        SizedBox(width: 4),
        Text(title, style: TextStyle(color: isGold ? Colors.orangeAccent : Colors.white, fontSize: 11)),
      ],
    );
  }

  Widget _buildCircularCategory(String title, IconData icon, {bool isSpecial = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isSpecial ? Color(0xFF005953) : Theme.of(context).cardColor,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Icon(icon, color: isSpecial ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87, size: 24),
          ),
          SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildMegaMenuOverlay(AppStateProvider state) {
    final tealColor = Theme.of(context).primaryColor;
    return Positioned(
      top: 130,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).cardColor,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 0.65,
            children: [
              _buildMegaMenuColumn('Electronics', [
                'Smartphones', 'Laptops', 'Tablets', 'Smart Watches', 'Accessories'
              ]),
              _buildMegaMenuColumn('Fashion', [
                "Men's Wear", "Women's Wear", 'Shoes', 'Bags & Luggage', 'Watches'
              ]),
              _buildMegaMenuColumn('Home & Living', [
                'Kitchenware', 'Furniture', 'Home Decor', 'Bedding', 'Bath'
              ]),
              _buildMegaMenuColumn('Health & Beauty', [
                'Skincare', 'Cosmetics', 'Fragrances', 'Haircare', 'Personal Care'
              ]),
              _buildMegaMenuColumn('Groceries & Mart', [
                'Beverages', 'Snacks', 'Fresh Food', 'Pet Supplies', 'Household'
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMegaMenuColumn(String categoryTitle, List<String> subCats) {
    final tealColor = Theme.of(context).primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          categoryTitle,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: tealColor),
        ),
        const SizedBox(height: 8),
        const Divider(color: Colors.black12, height: 12),
        ...subCats.map((sub) => Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: InkWell(
            onTap: () {
              setState(() {
                _searchQuery = sub;
                _searchController.text = sub;
                _isMegaMenuOpen = false;
              });
            },
            child: Text(
              sub,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        )).toList(),
      ],
    );
  }


  Widget _buildFaqItem(String question, String answer) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(question, style: const TextStyle(fontSize: 11, color: Colors.black87)),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(answer, style: const TextStyle(fontSize: 10, color: Colors.black54)),
          )
        ],
      ),
    );
  }

  // ==========================================
  // ADVANCED FILTER BOTTOM SHEET
  // ==========================================
  void _showFilterBottomSheet(BuildContext context, Color goldColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Advanced Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              const Text('Sort By', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(label: const Text('Best Match'), selected: true, selectedColor: goldColor.withOpacity(0.2)),
                  ChoiceChip(label: const Text('Price: Low to High'), selected: false),
                  ChoiceChip(label: const Text('Price: High to Low'), selected: false),
                  ChoiceChip(label: const Text('Top Rated'), selected: false),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Services & Promotions', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(label: const Text('Free Shipping'), onSelected: (val) {}),
                  FilterChip(label: const Text('Cash on Delivery'), onSelected: (val) {}),
                  FilterChip(label: const Text('Daraz Mall'), onSelected: (val) {}),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Price Range', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Min', filled: true), keyboardType: TextInputType.number)),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('-')),
                  Expanded(child: TextField(decoration: const InputDecoration(hintText: 'Max', filled: true), keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: goldColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Filters applied')));
                  },
                  child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // SHOPPING CART BOTTOM SHEET
  // ==========================================
  void _showCartBottomSheet(BuildContext context, Color goldColor) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Shop Cart',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.white,
            elevation: 16,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
            ),
            child: Container(
              width: 380,
              height: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Consumer<AppStateProvider>(
                builder: (context, state, child) {
                  // Group flat cartProducts list by product ID
                  final Map<String, _SideCartItem> grouped = {};
                  for (final p in state.cartProducts) {
                    if (grouped.containsKey(p.id)) {
                      grouped[p.id]!.quantity++;
                    } else {
                      grouped[p.id] = _SideCartItem(
                        id: p.id,
                        name: p.name.isNotEmpty ? p.name : 'Sitimars Pro Wireless Earbuds',
                        price: int.tryParse(p.price.replaceAll(',', '')) ?? 3455,
                        quantity: 1,
                        imgUrl: p.imageUrl.isNotEmpty ? p.imageUrl : 'https://images.unsplash.com/photo-1592899677977-9c10ca588bbd?w=150',
                        productRef: p,
                      );
                    }
                  }

                  final cartItemsList = grouped.values.toList();
                  final int cartTotal = cartItemsList.fold(0, (sum, i) => sum + (i.price * i.quantity));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shopping_bag_outlined, color: Color(0xFF059669), size: 22),
                              const SizedBox(width: 8),
                              Text('Shop Cart (${state.cartProducts.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Color(0xFFF1F5F9), height: 1),
                      const SizedBox(height: 12),

                      // Cart Items Scrollable List
                      Expanded(
                        child: cartItemsList.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: const BoxDecoration(color: Color(0xFFECFDF5), shape: BoxShape.circle),
                                      child: const Icon(Icons.shopping_cart_outlined, size: 48, color: Color(0xFF059669)),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('Your Cart is Empty!', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    const SizedBox(height: 6),
                                    const Text('Add items from the store to view them here.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: cartItemsList.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = cartItemsList[index];

                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFF1F5F9)),
                                    ),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Image.network(
                                            item.imgUrl,
                                            width: 52,
                                            height: 52,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(color: const Color(0xFFCBD5E1), width: 52, height: 52),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${item.quantity} x PKR ${item.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Quantity controls + Delete button
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFF64748B)),
                                              onPressed: () {
                                                state.removeSingleFromCart(item.id);
                                              },
                                            ),
                                            Text('${item.quantity}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            IconButton(
                                              icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF059669)),
                                              onPressed: () {
                                                if (item.productRef != null) {
                                                  state.addToCart(item.productRef!);
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
                                              onPressed: () {
                                                state.removeFromCart(item.id);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Item removed from cart!'), backgroundColor: Color(0xFF059669)),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFF1F5F9), height: 1),
                      const SizedBox(height: 12),

                      // Total Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text(
                            'PKR ${cartTotal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Checkout Button
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 2,
                          ),
                          onPressed: cartItemsList.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  if (!state.isCustomerLoggedIn) {
                                    showCustomerAuthDialog(
                                      context,
                                      onAuthSuccess: () {
                                        Navigator.pushNamed(context, '/buyer/checkout');
                                      },
                                    );
                                  } else {
                                    Navigator.pushNamed(context, '/buyer/checkout');
                                  }
                                },
                          child: const Text('Checkout Now', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Action Links Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/buyer/cart');
                            },
                            child: const Text('View Full Cart', style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 16),
                          const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            child: const Text('Continue Shopping', style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  Widget _buildTrustSection() {
    final trustItems = [
      {
        'icon': Icons.security_rounded,
        'title': 'Secure Payments',
        'subtitle': 'Encrypted & safe checkout with COD, Cards & Wallets.',
      },
      {
        'icon': Icons.assignment_return_rounded,
        'title': 'Easy Returns',
        'subtitle': 'Hassle-free 7-day return & money-back guarantee.',
      },
      {
        'icon': Icons.verified_user_rounded,
        'title': 'Verified Sellers',
        'subtitle': '100% authentic products from registered stores.',
      },
      {
        'icon': Icons.local_shipping_rounded,
        'title': 'Nationwide Delivery',
        'subtitle': 'Fast express delivery to 150+ cities across Pakistan.',
      },
    ];

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1440),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = 4;
                  if (constraints.maxWidth < 600) {
                    crossAxisCount = 1;
                  } else if (constraints.maxWidth < 950) {
                    crossAxisCount = 2;
                  }

                  final itemWidth = (constraints.maxWidth - ((crossAxisCount - 1) * 16)) / crossAxisCount;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: trustItems.map((item) {
                      return SizedBox(
                        width: itemWidth,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x06000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF059669).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  item['icon'] as IconData,
                                  color: const Color(0xFF059669),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title'] as String,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['subtitle'] as String,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumFooter(BuildContext context, double screenWidth) {
    return BuyerDashboardPremiumFooter(screenWidth: screenWidth);
  }

  Widget _buildTopNavDivider() {
    return Container(
      height: 12,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white.withOpacity(0.18),
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
}







