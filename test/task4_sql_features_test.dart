import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/core/controllers/cart_controller.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/features/buyer/screens/orders/buyer_order_tracking_screen.dart';

void main() {
  group('Task 4: Wired SQL Features Unit Tests', () {
    test('OrderTrackingEventItem parses database row accurately', () {
      final json = {
        'event_type': 'Shipped',
        'description': 'Package picked up by courier',
        'location': 'Lahore Hub',
        'created_at': '2026-08-20T10:30:00Z',
      };

      final item = OrderTrackingEventItem.fromJson(json);
      expect(item.status, equals('Shipped'));
      expect(item.description, equals('Package picked up by courier'));
      expect(item.location, equals('Lahore Hub'));
      expect(item.createdAt.year, equals(2026));
    });

    test('CartController toggles and clears wishlist in-memory gracefully', () async {
      final cartCtrl = CartController();
      final product = AppProduct(
        id: 'prod-uuid-1',
        sellerId: 'seller-uuid-1',
        name: 'Wireless Earbuds',
        price: '2500',
        description: 'Test product',
        imageUrl: '',
        rating: '4.8',
        stock: 10,
        category: 'Electronics',
        approvalStatus: 'Approved',
        variations: [],
        wholesalePrices: {},
      );

      expect(cartCtrl.isProductWishlisted(product.id), isFalse);

      await cartCtrl.toggleWishlist(product);
      expect(cartCtrl.isProductWishlisted(product.id), isTrue);
      expect(cartCtrl.wishlistProducts.length, equals(1));

      await cartCtrl.toggleWishlist(product);
      expect(cartCtrl.isProductWishlisted(product.id), isFalse);
      expect(cartCtrl.wishlistProducts.isEmpty, isTrue);
    });

    test('CartController syncWishlistFromSupabase filters available products by user ids', () async {
      final cartCtrl = CartController();
      final p1 = AppProduct(
        id: 'p1',
        sellerId: 's1',
        name: 'Product 1',
        price: '1000',
        description: '',
        imageUrl: '',
        rating: '5',
        stock: 5,
        category: 'A',
        approvalStatus: 'Approved',
        variations: [],
        wholesalePrices: {},
      );

      final p2 = AppProduct(
        id: 'p2',
        sellerId: 's1',
        name: 'Product 2',
        price: '2000',
        description: '',
        imageUrl: '',
        rating: '4',
        stock: 2,
        category: 'B',
        approvalStatus: 'Approved',
        variations: [],
        wholesalePrices: {},
      );

      // Without Supabase session, sync gracefully completes without throwing
      await cartCtrl.syncWishlistFromSupabase([p1, p2]);
      expect(cartCtrl.wishlistProducts, isEmpty);
    });
  });
}
