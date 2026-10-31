import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:apna_store/core/config/feature_flags.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/core/services/supabase_orders_service.dart';
import 'package:apna_store/features/buyer/screens/wishlist/buyer_wishlist_gifting_screen.dart';
import 'package:apna_store/features/buyer/widgets/checkout/checkout_payment_selector.dart';

void main() {
  group('Phase E — Growth Features & Multi-Payment Tests', () {
    late AppStateProvider appState;

    final testProduct1 = AppProduct(
      id: 'prod_growth_1',
      name: 'Wireless Bluetooth Headset',
      category: 'Electronics',
      price: '4500',
      description: 'Premium noise cancelling wireless headset',
      imageUrl: 'https://example.com/headset.jpg',
      additionalImages: [
        'https://example.com/headset_side.jpg',
        'https://example.com/headset_case.jpg',
      ],
      sellerId: 'seller_growth_1',
      approvalStatus: 'Approved',
      variations: [],
      wholesalePrices: {},
    );

    final testProduct2 = AppProduct(
      id: 'prod_growth_2',
      name: 'Embroidered Silk Kurti',
      category: 'Fashion',
      price: '3200',
      description: 'Hand-crafted pure silk embroidered shirt',
      imageUrl: 'https://example.com/kurti.jpg',
      sellerId: 'seller_growth_2',
      approvalStatus: 'Approved',
      variations: [
        ProductVariation(name: 'Size', values: ['S', 'M', 'L', 'XL']),
        ProductVariation(name: 'Color', values: ['Maroon', 'Emerald', 'Navy']),
      ],
      wholesalePrices: {},
    );

    setUp(() {
      appState = AppStateProvider();
    });

    test('1. Wishlist item persistence and state management in AppStateProvider', () {
      expect(appState.wishlistCount, 0);
      expect(appState.isInWishlist(testProduct1.id), isFalse);

      // Add product 1 to wishlist
      appState.toggleWishlist(testProduct1);
      expect(appState.wishlistCount, 1);
      expect(appState.isInWishlist(testProduct1.id), isTrue);

      // Add product 2 to wishlist
      appState.toggleWishlist(testProduct2);
      expect(appState.wishlistCount, 2);
      expect(appState.isInWishlist(testProduct2.id), isTrue);

      // Remove product 1 by toggle
      appState.toggleWishlist(testProduct1);
      expect(appState.wishlistCount, 1);
      expect(appState.isInWishlist(testProduct1.id), isFalse);

      // Clear remaining wishlist
      appState.clearWishlist();
      expect(appState.wishlistCount, 0);
    });

    test('2. Product variations and additional images map correctly', () {
      expect(testProduct1.additionalImages, hasLength(2));
      expect(testProduct1.additionalImages!.first, 'https://example.com/headset_side.jpg');

      expect(testProduct2.variations, hasLength(2));
      expect(testProduct2.variations.first.name, 'Size');
      expect(testProduct2.variations.first.values, contains('XL'));
      expect(testProduct2.variations.last.name, 'Color');
      expect(testProduct2.variations.last.values, contains('Emerald'));
    });

    testWidgets('3. CheckoutPaymentSelector renders payment methods with safety flag enforcement', (WidgetTester tester) async {
      String selected = 'COD';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CheckoutPaymentSelector(
                  selectedPaymentMethod: selected,
                  onPaymentMethodChanged: (val) {
                    setState(() => selected = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      // Verify all 4 payment options are visible
      expect(find.text('Cash on Delivery (COD)'), findsOneWidget);
      expect(find.text('JazzCash Mobile Wallet'), findsOneWidget);
      expect(find.text('Easypaisa Mobile Account'), findsOneWidget);
      expect(find.text('Credit / Debit Card (Visa / MasterCard / PayPak)'), findsOneWidget);

      if (!FeatureFlags.onlinePaymentsEnabled) {
        expect(find.text('Coming Soon'), findsNWidgets(3));
      } else {
        // Tap JazzCash
        await tester.tap(find.text('JazzCash Mobile Wallet'));
        await tester.pumpAndSettle();
        expect(selected, 'JazzCash');

        // Tap Easypaisa
        await tester.tap(find.text('Easypaisa Mobile Account'));
        await tester.pumpAndSettle();
        expect(selected, 'Easypaisa');

        // Tap Card
        await tester.tap(find.text('Credit / Debit Card (Visa / MasterCard / PayPak)'));
        await tester.pumpAndSettle();
        expect(selected, 'Debit/Credit Card');
      }
    });

    testWidgets('4. BuyerWishlistGiftingScreen renders wishlist and supports Add to Cart', (WidgetTester tester) async {
      appState.toggleWishlist(testProduct1);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppStateProvider>.value(
            value: appState,
            child: const BuyerWishlistGiftingScreen(),
          ),
        ),
      );

      // Check product is rendered in wishlist
      expect(find.text('Saved Wishlist Items (1)'), findsOneWidget);
      expect(find.text('Wireless Bluetooth Headset'), findsOneWidget);
      expect(find.text('PKR 4500 | Electronics'), findsOneWidget);

      // Tap Add to Cart button
      await tester.tap(find.text('Add to Cart').first);
      await tester.pumpAndSettle();

      // Verify product added to cart
      expect(appState.cartProducts.length, 1);
      expect(appState.cartProducts.first.name, 'Wireless Bluetooth Headset');
    });

    test('5. SupabaseOrdersService safely maps mock tracking timeline events', () async {
      final service = SupabaseOrdersService();
      final events = await service.getOrderTrackingEvents('test-ord-001');
      expect(events, isA<List<Map<String, dynamic>>>());
    });
  });
}
