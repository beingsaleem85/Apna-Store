import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/core/widgets/app_footer.dart';
import 'package:apna_store/features/buyer/screens/auth/customer_auth_dialog.dart';

class CartItem {
  final String id;
  final String title;
  final String storeName;
  final int price;
  int quantity;
  final String variant;
  final String imageUrl;
  final AppProduct? productRef;

  CartItem({
    required this.id,
    required this.title,
    required this.storeName,
    required this.price,
    required this.quantity,
    required this.variant,
    required this.imageUrl,
    this.productRef,
  });
}

class BuyerCartCheckoutScreen extends StatefulWidget {
  const BuyerCartCheckoutScreen({super.key});

  @override
  State<BuyerCartCheckoutScreen> createState() => _BuyerCartCheckoutScreenState();
}

class _BuyerCartCheckoutScreenState extends State<BuyerCartCheckoutScreen> {
  final List<CartItem> _savedForLater = [
    CartItem(
      id: 's1',
      title: 'Wireless Bluetooth Earbuds Pro Active Cancellation',
      storeName: 'Audio Tech Store',
      price: 2499,
      quantity: 1,
      variant: 'White Edition',
      imageUrl: 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=300',
    ),
  ];

  final String? _appliedCoupon = null;
  final int _couponDiscount = 0;
  final int _freeShippingThreshold = 1999;
  final TextEditingController _couponController = TextEditingController();

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // Group flat cart products list by product ID
    final Map<String, CartItem> grouped = {};
    for (final p in state.cartProducts) {
      if (grouped.containsKey(p.id)) {
        grouped[p.id]!.quantity++;
      } else {
        final store = state.stores.firstWhere(
          (s) => s.id == p.sellerId,
          orElse: () => AppStore(id: p.sellerId, shopName: 'Official Store'),
        );
        grouped[p.id] = CartItem(
          id: p.id,
          title: p.name.isNotEmpty ? p.name : 'Product',
          storeName: store.shopName.isNotEmpty ? store.shopName : 'Official Store',
          price: int.tryParse(p.price.replaceAll(',', '')) ?? 0,
          quantity: 1,
          variant: p.variations.isNotEmpty
              ? '${p.variations.first.name}: ${p.variations.first.values.first}'
              : 'Standard',
          imageUrl: p.imageUrl.isNotEmpty
              ? p.imageUrl
              : 'https://images.unsplash.com/photo-1592899677977-9c10ca588bbd?w=400',
          productRef: p,
        );
      }
    }

    final cartItemsList = grouped.values.toList();
    final int subtotal = cartItemsList.fold(0, (sum, item) => sum + (item.price * item.quantity));
    final int uniqueStoresCount = cartItemsList.map((item) => item.storeName).toSet().length;
    final int shippingFee = cartItemsList.isEmpty ? 0 : uniqueStoresCount * 150;
    final int finalTotal = (subtotal + shippingFee - _couponDiscount).clamp(0, 999999);
    final double freeShippingProgress = (subtotal / _freeShippingThreshold).clamp(0.0, 1.0);
    final int amountNeededForFreeShipping = (_freeShippingThreshold - subtotal).clamp(0, 999999);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Top Utility Header Bar
            Container(
              width: double.infinity,
              color: Colors.white,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Navigation Arrow Button
                      Row(
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
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Apna Store',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Search Input (Desktop)
                      if (screenWidth > 768)
                        Container(
                          width: 440,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: const [
                              SizedBox(width: 12),
                              Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                              SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Search products, brands and categories...',
                                    hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Right Action Badges
                      Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.pushNamed(context, '/buyer/wishlist'),
                            child: Row(
                              children: [
                                const Icon(Icons.favorite_border, size: 20, color: Color(0xFF334155)),
                                const SizedBox(width: 4),
                                Text('Wishlist (${state.wishlistProducts.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(Icons.shopping_cart_outlined, size: 22, color: Color(0xFF059669)),
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
                              const SizedBox(width: 8),
                              const Text('Cart', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // 2. Breadcrumbs Strip
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pushNamed(context, '/'),
                        child: const Text('Home', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ),
                      const Text('  /  ', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      const Text('Shopping Cart', style: TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3. Main Body Container (MaxWidth 1280px)
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1280),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: cartItemsList.isEmpty
                    ? _buildEmptyCartView(context)
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop = constraints.maxWidth > 850;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Free Shipping Progress Card
                              _buildFreeShippingCard(amountNeededForFreeShipping, freeShippingProgress),
                              const SizedBox(height: 20),

                              if (isDesktop)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left Column: Cart Items (70% width)
                                    Expanded(
                                      flex: 7,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildCartItemsSection(state, cartItemsList, uniqueStoresCount),
                                          const SizedBox(height: 20),
                                          _buildCouponCard(),
                                          const SizedBox(height: 20),
                                          if (_savedForLater.isNotEmpty) _buildSavedForLaterSection(state),
                                          const SizedBox(height: 24),
                                          _buildTrustBadgesRow(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),

                                    // Right Column: Order Summary (30% width)
                                    Expanded(
                                      flex: 3,
                                      child: _buildOrderSummaryCard(context, state, subtotal, uniqueStoresCount, shippingFee, finalTotal),
                                    ),
                                  ],
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildCartItemsSection(state, cartItemsList, uniqueStoresCount),
                                    const SizedBox(height: 20),
                                    _buildCouponCard(),
                                    const SizedBox(height: 20),
                                    _buildOrderSummaryCard(context, state, subtotal, uniqueStoresCount, shippingFee, finalTotal),
                                    const SizedBox(height: 20),
                                    if (_savedForLater.isNotEmpty) _buildSavedForLaterSection(state),
                                    const SizedBox(height: 24),
                                    _buildTrustBadgesRow(),
                                  ],
                                ),
                              const SizedBox(height: 48),
                            ],
                          );
                        },
                      ),
              ),
            ),

            // 4. Footer
            const AppFooter(),
          ],
        ),
      ),
    );
  }

  // --- EMPTY CART VIEW ---
  Widget _buildEmptyCartView(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      margin: const EdgeInsets.only(bottom: 60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_cart_outlined, size: 64, color: Color(0xFF059669)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your Shopping Cart is Empty!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Looks like you haven’t added any items to your cart yet.\nExplore our top products and start shopping!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Start Shopping Now', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
            onPressed: () => Navigator.pushNamed(context, '/'),
          ),
        ],
      ),
    );
  }

  // --- FREE SHIPPING PROGRESS CARD ---
  Widget _buildFreeShippingCard(int amountNeeded, double progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded, color: Color(0xFF059669), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  amountNeeded > 0
                      ? 'Add PKR ${amountNeeded.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} more to unlock FREE Shipping across Pakistan!'
                      : '🎉 Congratulations! You have unlocked FREE Nationwide Shipping!',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFD1FAE5),
              color: const Color(0xFF059669),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  // --- CART ITEMS SECTION ---
  Widget _buildCartItemsSection(AppStateProvider state, List<CartItem> cartItems, int uniqueStoresCount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cart Items (${cartItems.fold(0, (sum, i) => sum + i.quantity)})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Text(
                'From $uniqueStoresCount ${uniqueStoresCount == 1 ? "Seller Store" : "Seller Stores"}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cartItems.length,
            separatorBuilder: (ctx, i) => const Divider(height: 28, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, index) {
              final item = cartItems[index];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Header
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF059669)),
                      const SizedBox(width: 6),
                      Text(
                        item.storeName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Verified Seller',
                          style: TextStyle(fontSize: 10, color: Color(0xFF15803D), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Item Details Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          item.imageUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF64748B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Title, Variant, Price
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A), height: 1.3),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Variant: ${item.variant}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'PKR ${item.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF059669), fontSize: 15),
                            ),
                          ],
                        ),
                      ),

                      // Quantity Selector
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () {
                                if (item.quantity > 1) {
                                  state.removeSingleFromCart(item.id);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.remove,
                                  size: 16,
                                  color: item.quantity > 1 ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '${item.quantity}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                if (item.productRef != null) {
                                  state.addToCart(item.productRef!);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                child: const Icon(Icons.add, size: 16, color: Color(0xFF0F172A)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Action Links: Save for Later & Remove
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.bookmark_border_rounded, size: 15, color: Color(0xFF475569)),
                        label: const Text('Save for Later', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                        onPressed: () {
                          setState(() {
                            _savedForLater.add(item);
                          });
                          state.removeFromCart(item.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Item moved to Saved for Later!'), backgroundColor: Color(0xFF059669)),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                        label: const Text('Remove', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                        onPressed: () => state.removeFromCart(item.id),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- COUPON VOUCHER CARD ---
  Widget _buildCouponCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.confirmation_number_outlined, color: Color(0xFFD97706), size: 20),
              SizedBox(width: 8),
              Text('Discounts & Promo Coupons', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _couponController,
                    enabled: false,
                    decoration: InputDecoration(
                      hintText: 'Promo codes coming soon',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF94A3B8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: null,
                  child: const Text('Apply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- SAVED FOR LATER SECTION ---
  Widget _buildSavedForLaterSection(AppStateProvider state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Saved for Later', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _savedForLater.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final s = _savedForLater[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(s.imageUrl, width: 44, height: 44, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text('PKR ${s.price}', style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        if (s.productRef != null) {
                          state.addToCart(s.productRef!);
                        } else {
                          state.addToCart(AppProduct(
                            id: s.id,
                            sellerId: 'seller_1',
                            name: s.title,
                            price: s.price.toString(),
                            description: 'Saved item',
                            imageUrl: s.imageUrl,
                            category: 'General',
                            variations: [],
                            wholesalePrices: {},
                          ));
                        }
                        setState(() {
                          _savedForLater.removeAt(index);
                        });
                      },
                      child: const Text('Move to Cart', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- ORDER SUMMARY STICKY CARD ---
  Widget _buildOrderSummaryCard(BuildContext context, AppStateProvider state, int subtotal, int uniqueStoresCount, int shippingFee, int finalTotal) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),

          // Subtotal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Items Subtotal', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              Text('PKR ${subtotal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 10),

          // Shipping Fee
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Shipping Fee ($uniqueStoresCount Stores)', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
              Text(
                shippingFee == 0 ? 'FREE' : 'PKR $shippingFee',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: shippingFee == 0 ? const Color(0xFF059669) : const Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Voucher Discount
          if (_couponDiscount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Voucher Discount', style: TextStyle(fontSize: 13, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
                Text('- PKR $_couponDiscount', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),
          ],
          const Divider(height: 24, color: Color(0xFFF1F5F9)),

          // Total Payable
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Payable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
              Text(
                'PKR ${finalTotal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF059669), fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('Inclusive of all taxes & duties', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ),
          const SizedBox(height: 20),

          // Delivery Address Preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, color: Color(0xFF059669), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Deliver to: Ali Khan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('House #12, Street 3, Lahore', style: TextStyle(fontSize: 10, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 24)),
                  child: const Text('Change', style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Checkout Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 2,
                shadowColor: const Color(0xFF059669).withOpacity(0.4),
              ),
              onPressed: () {
                if (!state.isCustomerLoggedIn) {
                  showCustomerAuthDialog(
                    context,
                    targetAction: 'Proceed to Checkout',
                    onAuthSuccess: () {
                      Navigator.pushNamed(context, '/buyer/checkout');
                    },
                  );
                } else {
                  Navigator.pushNamed(context, '/buyer/checkout');
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Proceed to Checkout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Payment Methods Icons
          const Center(
            child: Text('ACCEPTED PAYMENT METHODS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.credit_card, size: 18, color: Color(0xFF64748B)),
              SizedBox(width: 12),
              Icon(Icons.account_balance_wallet_outlined, size: 18, color: Color(0xFF64748B)),
              SizedBox(width: 12),
              Icon(Icons.payments_outlined, size: 18, color: Color(0xFF64748B)),
              SizedBox(width: 12),
              Text('COD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
            ],
          ),
        ],
      ),
    );
  }

  // --- TRUST BADGES ROW ---
  Widget _buildTrustBadgesRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildBadgeItem(Icons.verified_user_outlined, '100% Genuine'),
          _buildBadgeItem(Icons.local_shipping_outlined, 'Fast Delivery'),
          _buildBadgeItem(Icons.assignment_return_outlined, '7-Day Easy Return'),
          _buildBadgeItem(Icons.lock_outline_rounded, 'Safe Checkout'),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF059669)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
      ],
    );
  }
}
