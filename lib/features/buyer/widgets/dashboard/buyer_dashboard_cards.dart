part of '../../screens/buyer_dashboard.dart';

class _MarketplaceProductCardWidget extends StatefulWidget {
  final Map<String, dynamic> product;

  const _MarketplaceProductCardWidget({required this.product});

  @override
  State<_MarketplaceProductCardWidget> createState() => _MarketplaceProductCardWidgetState();
}

class _MarketplaceProductCardWidgetState extends State<_MarketplaceProductCardWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.product['title'] as String? ?? 'Marketplace Product';
    final currentPrice = widget.product['currentPrice'] as String? ?? 'PKR 3,455';
    final originalPrice = widget.product['originalPrice'] as String?;
    final discount = widget.product['discount'] as String?;
    final imgUrl = widget.product['imgUrl'] as String? ?? 'https://images.unsplash.com/photo-1592899677977-9c10ca588bbd?w=300';
    final rating = widget.product['rating']?.toString() ?? '4.8';
    final reviews = widget.product['reviews']?.toString() ?? '342';
    final soldCount = widget.product['soldCount'] as String? ?? '1.2k Sold';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: _isHovered ? (Matrix4.identity()..translate(0.0, -4.0, 0.0)) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isHovered ? const Color(0xFF059669).withOpacity(0.4) : const Color(0xFFE2E8F0),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered ? const Color(0xFF059669).withOpacity(0.12) : Colors.black.withOpacity(0.04),
              blurRadius: _isHovered ? 16 : 8,
              offset: Offset(0, _isHovered ? 8 : 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              final cleanPrice = currentPrice.replaceAll(RegExp(r'[^0-9]'), '');
              final productObj = AppProduct(
                id: 'prod_${title.hashCode.abs()}',
                sellerId: 'seller_1',
                name: title,
                price: cleanPrice.isEmpty ? '3455' : cleanPrice,
                rating: rating,
                description: 'High quality premium product available on Elegant Marketplace.',
                imageUrl: imgUrl,
                category: 'Electronics',
                variations: const [],
                wholesalePrices: const {},
              );
              Navigator.pushNamed(context, '/product', arguments: productObj);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        color: const Color(0xFFF8FAFC),
                        child: Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: const Color(0xFFF1F5F9)),
                        ),
                      ),
                    ),
                    if (discount != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            discount,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                          height: 1.3,
                        ),
                      ),
                      
                      // Redesigned Premium Price Section
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                currentPrice,
                                style: const TextStyle(
                                  color: Color(0xFF059669),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                              if (originalPrice != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  originalPrice,
                                  style: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Color(0xFFCBD5E1),
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 3),
                          Text(
                            rating,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '($reviews)',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            soldCount,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF059669),
                            ),
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
      ),
    );
  }
}

class HoverProductCard extends StatefulWidget {
  final AppProduct product;
  final String shopName;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;
  final bool showDiscountBadge;
  final bool showAddToCart;
  final bool showOriginalPrice;
  final String? reason;

  const HoverProductCard({
    super.key,
    required this.product,
    required this.shopName,
    required this.onTap,
    this.onAddToCart,
    this.showDiscountBadge = true,
    this.showAddToCart = true,
    this.showOriginalPrice = true,
    this.reason,
  });

  @override
  State<HoverProductCard> createState() => _HoverProductCardState();
}

class _HoverProductCardState extends State<HoverProductCard> {
  bool _isHovered = false;
  bool _isWishlisted = false;

  @override
  Widget build(BuildContext context) {
    final double currentPrice = double.tryParse(widget.product.price) ?? 0.0;
    final double originalPrice = currentPrice * 1.5;
    final discountPct = 33;
    final primaryGreen = const Color(0xFF00474F);
    final goldColor = const Color(0xFFFDB913);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isHovered ? (Matrix4.identity()..translate(0, -6, 0)) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(_isHovered ? 0.12 : 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isHovered ? 0.08 : 0.03),
              blurRadius: _isHovered ? 16 : 6,
              offset: Offset(0, _isHovered ? 8 : 3),
            )
          ],
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image with Stack
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.network(
                          widget.product.imageUrl.isNotEmpty ? widget.product.imageUrl : 'https://images.unsplash.com/photo-1531403009284-440f080d1e12?w=500&q=80',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Image.network(
                              'https://images.unsplash.com/photo-1531403009284-440f080d1e12?w=500&q=80',
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                      ),
                    ),
                    // Discount Badge
                    if (widget.showDiscountBadge)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '-$discountPct%',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    // Wishlist Heart Icon
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Consumer<AppStateProvider>(
                        builder: (context, state, child) {
                          final isWishlisted = state.isProductWishlisted(widget.product.id);
                          return GestureDetector(
                            onTap: () {
                              if (!state.isCustomerLoggedIn) {
                                showCustomerAuthDialog(context, onAuthSuccess: () {
                                  state.toggleWishlist(widget.product);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Added to Wishlist'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                });
                              } else {
                                state.toggleWishlist(widget.product);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(!isWishlisted ? 'Added to Wishlist' : 'Removed from Wishlist'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                                ],
                              ),
                              child: Icon(
                                isWishlisted ? Icons.favorite : Icons.favorite_border,
                                color: isWishlisted ? Colors.red : Colors.grey,
                                size: 16,
                              ),
                            ),
                          );
                        }
                      ),
                    ),
                    // Free Shipping Badge (Light green like screenshot)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Free Shipping',
                          style: TextStyle(color: primaryGreen, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Details
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.reason != null && widget.reason!.isNotEmpty) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF004D40).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.reason!,
                          style: const TextStyle(color: Color(0xFF004D40), fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    // Fixed height (42px) 2-line clamped title container to prevent layout shifting
                    SizedBox(
                      height: 42,
                      child: Text(
                        widget.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Rating
                    Row(
                      children: [
                        Icon(Icons.star, color: goldColor, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          widget.product.rating,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '| 1.2k sold',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Prices (Dark green price like screenshot)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Rs. ${widget.product.price}',
                          style: TextStyle(
                            color: primaryGreen,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        if (widget.showOriginalPrice) ...[
                          const SizedBox(width: 6),
                          Text(
                            'Rs. ${originalPrice.toInt()}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Seller Name
                    Row(
                      children: [
                        const Icon(Icons.storefront, size: 10, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.shopName,
                            style: const TextStyle(fontSize: 9, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (widget.showAddToCart && widget.onAddToCart != null) ...[
                      const SizedBox(height: 8),
                      // Add To Cart Button (Primary Green like screenshot theme)
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: ElevatedButton(
                          onPressed: widget.onAddToCart,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_cart, size: 12),
                              SizedBox(width: 4),
                              Text('Add To Cart', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class PromotionCarousel extends StatefulWidget {
  const PromotionCarousel({super.key});

  @override
  State<PromotionCarousel> createState() => _PromotionCarouselState();
}

class _PromotionCarouselState extends State<PromotionCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final Timer? _timer;

  final List<Map<String, String>> _slides = [
    {
      'tag': 'WEEKLY SUPER SAVINGS BAZAAR',
      'title': 'GROCERY & HOUSEHOLD DEALS',
      'subtitle': 'Up to 35% OFF on Fresh Fruits, Vegetables, Cleaners & Pantry Essentials!',
      'image': 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=1200',
      'fallbackBg': '0xFF0D2418',
      'badge': 'BEST PRICE GUARANTEE',
      'voucher': 'WEEKLY35',
    },
    {
      'tag': 'EXCLUSIVE TECH BRAND DEALS',
      'title': 'SMART DEVICE EXPO 2026',
      'subtitle': 'Flat 20% Cashback on Smartwatches, AirPods & Laptops!',
      'image': 'https://images.unsplash.com/photo-1468436139062-f60a71c5c892?w=1200',
      'fallbackBg': '0xFF1A1F2C',
      'badge': 'NO-COST EMI',
      'voucher': 'TECH20',
    },
    {
      'tag': 'DESIGNER SUMMER ARRIVALS',
      'title': 'NEW LAWN COLLECTION 2026',
      'subtitle': 'Discover premium designer wear, footwear & accessories!',
      'image': 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=1200',
      'fallbackBg': '0xFF3E1F2A',
      'badge': 'BUY 1 GET 1 FREE',
      'voucher': 'LAWN26',
    },
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _slides.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;
    final height = isDesktop ? 380.0 : 200.0;
    final brandGreen = const Color(0xFF004D40);
    final goldColor = const Color(0xFFFDB913);

    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemCount: _slides.length,
              itemBuilder: (context, index) {
                final slide = _slides[index];
                return Stack(
                  children: [
                    // Background Image
                    Positioned.fill(
                      child: Image.network(
                        slide['image']!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(color: Color(int.parse(slide['fallbackBg']!)));
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(color: Color(int.parse(slide['fallbackBg']!)));
                        },
                      ),
                    ),
                    // Gradient Overlay to ensure text readability
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withOpacity(0.9),
                              Colors.black.withOpacity(0.6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Glassmorphic Content Panel
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: isDesktop ? 550 : screenWidth * 0.75,
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 48.0 : 20.0,
                          vertical: isDesktop ? 36.0 : 16.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Promo Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: goldColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                slide['badge']!,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Tag
                            Text(
                              slide['tag']!,
                              style: TextStyle(
                                color: goldColor.withOpacity(0.9),
                                fontSize: isDesktop ? 12 : 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Title
                            Text(
                              slide['title']!,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isDesktop ? 32 : 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Subtitle
                            Text(
                              slide['subtitle']!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: isDesktop ? 14 : 10,
                                height: 1.3,
                              ),
                            ),
                            if (slide['voucher'] != null && slide['voucher']!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(color: goldColor, width: 1),
                                  borderRadius: BorderRadius.circular(4),
                                  color: goldColor.withOpacity(0.1),
                                ),
                                child: Text(
                                  'Use Code: ${slide['voucher']}',
                                  style: TextStyle(
                                    color: goldColor,
                                    fontSize: isDesktop ? 12 : 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            // Shop Now Button with Orange-Gold Gradient
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFDB913), Color(0xFFFF8F00)],
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFDB913).withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isDesktop ? 32 : 16,
                                    vertical: isDesktop ? 16 : 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  'SHOP NOW',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isDesktop ? 12 : 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            // Dynamic Pill Page Indicators
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _currentPage == index ? goldColor : Colors.white.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TickingCountdownTimer extends StatefulWidget {
  const TickingCountdownTimer({super.key});

  @override
  State<TickingCountdownTimer> createState() => _TickingCountdownTimerState();
}

class _TickingCountdownTimerState extends State<TickingCountdownTimer> {
  late Timer _timer;
  int _secondsLeft = 8100; // 2 hours and 15 minutes = 8100 seconds

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTime() {
    final h = (_secondsLeft ~/ 3600).toString().padLeft(2, '0');
    final m = ((_secondsLeft % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return "${h}h : ${m}m : ${s}s";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.15),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flash_on, color: Colors.redAccent, size: 16),
          const SizedBox(width: 4),
          Text(
            'Ending in ${_formatTime()}',
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class HoverGridCategoryCell extends StatefulWidget {
  final Map<String, String> category;
  final AppStateProvider state;
  final Color brandGreen;

  const HoverGridCategoryCell({
    super.key,
    required this.category,
    required this.state,
    required this.brandGreen,
  });

  @override
  State<HoverGridCategoryCell> createState() => _HoverGridCategoryCellState();
}

class _HoverGridCategoryCellState extends State<HoverGridCategoryCell> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final String name = (widget.category['name'] ?? widget.category['title'] ?? '').toString();
    final String image = (widget.category['image'] ?? '').toString();
    const fallbackImage = "https://images.unsplash.com/photo-1513542789411-b6a5d4f31634?w=200&q=80";

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: _isHovered ? (Matrix4.identity()..scale(1.02)) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFFAFAFA) : const Color(0xFFFFFFFF),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(context, '/category', arguments: name);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    image.isNotEmpty ? image : fallbackImage,
                    width: 90,
                    height: 90,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        width: 90,
                        height: 90,
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF004D40)),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          fallbackImage,
                          width: 90,
                          height: 90,
                          fit: BoxFit.contain,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF212121),
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopUtilityNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? activeIconColor;

  const _TopUtilityNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.activeIconColor,
  });

  @override
  State<_TopUtilityNavItem> createState() => _TopUtilityNavItemState();
}

class _TopUtilityNavItemState extends State<_TopUtilityNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final goldColor = const Color(0xFFFDB913);
    final targetIconColor = widget.activeIconColor ?? goldColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  widget.icon,
                  key: ValueKey(_isHovered),
                  size: 15,
                  color: _isHovered ? targetIconColor : Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(width: 7),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _isHovered ? Colors.white : Colors.white.withOpacity(0.85),
                  fontFamily: 'Inter',
                  letterSpacing: 0.2,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// AUTO SLIDING BANNER CAROUSEL (3 SECONDS)
// ==========================================
// AUTO-SLIDING HERO BANNER (PREMIUM MARKETPLACE CAROUSEL)
// ==========================================
class AutoSlidingBanner extends StatefulWidget {
  const AutoSlidingBanner({super.key});

  @override
  State<AutoSlidingBanner> createState() => _AutoSlidingBannerState();
}

class _AutoSlidingBannerState extends State<AutoSlidingBanner> {
  late PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  final List<Map<String, String>> _banners = [
    {
      'tag': 'SPECIAL OFFER',
      'title': r'Special Offer Up To $150 Off',
      'desc': 'Get fashion style special offer on this e-commerce platform with the best deal prices.',
      'btn': 'Claim Offer Now',
      'image': 'https://images.unsplash.com/photo-1592899677977-9c10ca588bbd?w=500',
      'color1': '0xFF064E3B',
      'color2': '0xFF047857',
    },
    {
      'tag': 'MEGA TECH SALE 50% OFF',
      'title': 'Latest Electronics & Devices',
      'desc': 'Upgrade your gadgets with premium smartphones, laptops & wireless headphones.',
      'btn': 'Explore Tech Deals',
      'image': 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500',
      'color1': '0xFF0F172A',
      'color2': '0xFF1E293B',
    },
    {
      'tag': 'EXCLUSIVE DEAL',
      'title': '100% Farm Fresh Groceries',
      'desc': 'Fresh organic fruits, vegetables, and daily essentials delivered within 2 hours.',
      'btn': 'Order Fresh Groceries',
      'image': 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=500',
      'color1': '0xFF065F46',
      'color2': '0xFF059669',
    },
    {
      'tag': 'SUMMER FASHION',
      'title': 'Trending Luxury Collection',
      'desc': 'Discover modern fashion apparel, sneakers, and designer accessories for all seasons.',
      'btn': 'Shop Fashion Now',
      'image': 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=500',
      'color1': '0xFF1E1B4B',
      'color2': '0xFF312E81',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && _pageController.hasClients) {
        _currentPage = (_currentPage + 1) % _banners.length;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              final banner = _banners[index];
              final Color c1 = Color(int.parse(banner['color1']!.replaceAll('0x', ''), radix: 16));
              final Color c2 = Color(int.parse(banner['color2']!.replaceAll('0x', ''), radix: 16));

              return Container(
                width: double.infinity,
                height: 280,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c1, c2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Soft Ambient Glow Circles for Subtle Backdrop Depth
                    Positioned(
                      right: -30,
                      top: -30,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -50,
                      bottom: -50,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF10B981).withOpacity(0.08),
                        ),
                      ),
                    ),

                    // Left Typography & Call To Action Column
                    Positioned(
                      left: 48,
                      top: 32,
                      bottom: 32,
                      width: 520,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Glassmorphism Accent Pill Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFFF97316)),
                                const SizedBox(width: 6),
                                Text(
                                  banner['tag']!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Strong Headline
                          Text(
                            banner['title']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),

                          // Subtitle Description
                          Text(
                            banner['desc']!,
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 13,
                              height: 1.45,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 20),

                          // Attractive CTA Button with Hover Animation
                          HeroCtaButton(
                            text: 'Shop Now',
                            onPressed: () => Navigator.pushNamed(context, '/category', arguments: 'Electronics'),
                          ),
                        ],
                      ),
                    ),

                    // Right High-Impact Floating Image Card Presentation
                    Positioned(
                      right: 56,
                      top: 24,
                      bottom: 24,
                      width: 290,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ambient Light Aura Ring
                            Container(
                              width: 190,
                              height: 190,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF10B981).withOpacity(0.18),
                              ),
                            ),

                            // Main Floating Product Image Card
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.network(
                                  banner['image']!,
                                  height: 205,
                                  width: 220,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    height: 205,
                                    width: 220,
                                    color: const Color(0xFF1E293B),
                                    child: const Icon(Icons.shopping_bag_rounded, size: 70, color: Colors.white70),
                                  ),
                                ),
                              ),
                            ),

                            // Glass Badge Overlay on Top Right of Image Card
                            Positioned(
                              top: 6,
                              right: 20,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded, size: 12, color: Color(0xFF10B981)),
                                    SizedBox(width: 4),
                                    Text(
                                      'VERIFIED DEAL',
                                      style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Left Chevron Navigation Button
          Positioned(
            left: 14,
            top: 122,
            child: InkWell(
              onTap: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubic,
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),

          // Right Chevron Navigation Button
          Positioned(
            right: 14,
            top: 122,
            child: InkWell(
              onTap: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubic,
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),

          // Modern Capsule Slider Indicators
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_banners.length, (idx) {
                final isActive = idx == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 30 : 8,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// Interactive Hero CTA Button with Smooth Hover Effects
class _HeroCtaButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _HeroCtaButton({
    required this.label,
    required this.onPressed,
  });

  @override
  State<_HeroCtaButton> createState() => _HeroCtaButtonState();
}

class _HeroCtaButtonState extends State<_HeroCtaButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isHovered
                  ? const [Color(0xFF10B981), Color(0xFF059669)]
                  : const [Color(0xFF059669), Color(0xFF047857)],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF059669).withOpacity(_isHovered ? 0.5 : 0.3),
                blurRadius: _isHovered ? 16 : 8,
                offset: Offset(0, _isHovered ? 6 : 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.translationValues(_isHovered ? 4 : 0, 0, 0),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCardItem extends StatefulWidget {
  final String name;
  final IconData icon;
  final bool isSelected;

  const _CategoryCardItem({
    required this.name,
    required this.icon,
    this.isSelected = false,
  });

  @override
  State<_CategoryCardItem> createState() => _CategoryCardItemState();
}

class _CategoryCardItemState extends State<_CategoryCardItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, '/category', arguments: widget.name);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          height: 88,
          transform: Matrix4.translationValues(0, _isHovered ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? const Color(0xFF059669).withOpacity(0.12)
                    : Colors.black.withOpacity(0.03),
                blurRadius: _isHovered ? 12 : 4,
                offset: Offset(0, _isHovered ? 5 : 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _isHovered ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    size: 20,
                    color: _isHovered ? const Color(0xFF059669) : const Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: _isHovered ? FontWeight.w700 : FontWeight.w600,
                  color: _isHovered ? const Color(0xFF059669) : const Color(0xFF334155),
                ),
                child: Text(
                  widget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficialStoreCardWidget extends StatefulWidget {
  final Map<String, dynamic> store;

  const _OfficialStoreCardWidget({Key? key, required this.store}) : super(key: key);

  @override
  State<_OfficialStoreCardWidget> createState() => _OfficialStoreCardWidgetState();
}

class _OfficialStoreCardWidgetState extends State<_OfficialStoreCardWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final brandColor = widget.store['brandColor'] as Color;
    final bgColor = widget.store['bgColor'] as Color;
    final logoText = widget.store['logoText'] as String;
    final logoIcon = widget.store['logoIcon'] as IconData;
    final subtitle = widget.store['subtitle'] as String;
    final rating = widget.store['rating'] as String;
    final reviews = widget.store['reviews'] as String;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: _isHovered ? (Matrix4.identity()..translate(0.0, -4.0, 0.0)) : Matrix4.identity(),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? brandColor.withOpacity(0.4) : const Color(0xFFE2E8F0),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered ? brandColor.withOpacity(0.12) : Colors.black.withOpacity(0.04),
              blurRadius: _isHovered ? 16 : 8,
              offset: Offset(0, _isHovered ? 8 : 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.pushNamed(context, '/category', arguments: widget.store['brandName']);
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo container
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(logoIcon, size: 22, color: brandColor),
                          const SizedBox(width: 6),
                          Text(
                            logoText,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: brandColor,
                              letterSpacing: 0.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Subtitle
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Official Tag
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 11, color: Color(0xFF2563EB)),
                            SizedBox(width: 3),
                            Text(
                              'Official Store',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Rating & Reviews
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        reviews,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewAllHeaderButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;

  const _ViewAllHeaderButton({
    Key? key,
    required this.onTap,
    this.label = 'View All',
  }) : super(key: key);

  @override
  State<_ViewAllHeaderButton> createState() => _ViewAllHeaderButtonState();
}

class _ViewAllHeaderButtonState extends State<_ViewAllHeaderButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFFECFDF5) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _isHovered ? const Color(0xFF059669) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: _isHovered ? const Color(0xFF059669) : const Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampaignBannerCardWidget extends StatefulWidget {
  final String title;
  final String tag;
  final String subtitle;
  final String ctaText;
  final String imageUrl;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _CampaignBannerCardWidget({
    Key? key,
    required this.title,
    required this.tag,
    required this.subtitle,
    required this.ctaText,
    required this.imageUrl,
    required this.gradientColors,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_CampaignBannerCardWidget> createState() => _CampaignBannerCardWidgetState();
}

class _CampaignBannerCardWidgetState extends State<_CampaignBannerCardWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          height: 148,
          transform: _isHovered ? (Matrix4.identity()..translate(0.0, -4.0, 0.0)) : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.gradientColors.first.withOpacity(_isHovered ? 0.35 : 0.15),
                blurRadius: _isHovered ? 16 : 8,
                offset: Offset(0, _isHovered ? 8 : 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        widget.gradientColors.first.withOpacity(0.92),
                        widget.gradientColors.last.withOpacity(0.75),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.tag,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          widget.ctaText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 13,
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
    );
  }
}

class _MegaMenuItemWidget extends StatefulWidget {
  final String title;
  final VoidCallback onTap;

  const _MegaMenuItemWidget({required this.title, required this.onTap});

  @override
  State<_MegaMenuItemWidget> createState() => _MegaMenuItemWidgetState();
}

class _MegaMenuItemWidgetState extends State<_MegaMenuItemWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 2.0),
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFFECFDF5) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                Icons.chevron_right_rounded,
                size: 13,
                color: _isHovered ? const Color(0xFF059669) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _isHovered ? const Color(0xFF059669) : const Color(0xFF334155),
                    fontWeight: _isHovered ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideCartItem {
  final String id;
  final String name;
  final int price;
  int quantity;
  final String imgUrl;
  final AppProduct? productRef;

  _SideCartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imgUrl,
    this.productRef,
  });
}
