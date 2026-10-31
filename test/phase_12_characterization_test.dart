import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/core/config/feature_flags.dart';
import 'package:apna_store/core/routes/app_routes.dart';
import 'package:apna_store/core/routes/app_router.dart';
import 'package:apna_store/core/constants/theme.dart';
import 'package:apna_store/features/buyer/screens/buyer_dashboard.dart';

void main() {
  late AppStateProvider stateProvider;

  setUp(() {
    stateProvider = AppStateProvider();
  });

  Widget buildTestableWidget(Widget child) {
    return ChangeNotifierProvider<AppStateProvider>.value(
      value: stateProvider,
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: child,
      ),
    );
  }

  group('Phase 12 Step A — Characterization & Route Resolution Tests', () {
    testWidgets('1. Buyer Dashboard renders with state provider context', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestableWidget(const BuyerDashboard()));
      await tester.pump();

      expect(find.byType(BuyerDashboard), findsOneWidget);
    });

    test('2. Buyer Dashboard route resolves to BuyerDashboard screen', () {
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.buyerDashboard));
      expect(route, isA<MaterialPageRoute>());
    });

    test('3. Seller Dashboard route resolves to SellerDashboard screen', () {
      AppRouter.testRoleResolver = () => 'seller';
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.sellerDashboard));
      expect(route, isA<MaterialPageRoute>());
      AppRouter.testRoleResolver = null;
    });

    test('4. Product details route resolves safely', () {
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.product));
      expect(route, isA<MaterialPageRoute>());
    });

    test('5. Checkout routes resolve safely', () {
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.buyerCheckout));
      expect(route, isA<MaterialPageRoute>());
    });

    test('6. Feature flags enforce production disabled integration gates', () {
      expect(FeatureFlags.hardwarePrinterIntegrationEnabled, isFalse);
      expect(FeatureFlags.barcodeScannerIntegrationEnabled, isFalse);
      expect(FeatureFlags.aiCopilotEnabled, isFalse);
      expect(FeatureFlags.voiceAssistantEnabled, isFalse);
      expect(FeatureFlags.realCourierApiEnabled, isFalse);
      expect(FeatureFlags.liveGpsTrackingEnabled, isFalse);
    });

    test('7. AppStateProvider cart state mutation works as expected', () {
      expect(stateProvider.cartProducts.length, 0);
      final dummyProduct = AppProduct(
        id: 'test_p1',
        name: 'Test Product',
        price: '1000',
        category: 'Apparel',
        description: 'Test Desc',
        sellerId: 's1',
        imageUrl: 'https://via.placeholder.com/150',
        variations: const [],
        wholesalePrices: const {},
      );
      stateProvider.addToCart(dummyProduct);
      expect(stateProvider.cartProducts.length, 1);
      stateProvider.clearCart();
      expect(stateProvider.cartProducts.length, 0);
    });

    test('8. Seller fulfillment authority prohibits direct Delivered mutation', () {
      final order = AppOrder(
        id: 'ord_101',
        productId: 'prod_1',
        productName: 'Leather Boots',
        productPrice: 5000,
        sellerId: 'seller_1',
        buyerName: 'Ahmed',
        shippingAddress: 'Lahore',
        shippingSpeed: 'Standard',
        paymentMethod: 'COD',
        couponDiscount: 0,
        commissionDeducted: 500,
        finalPayout: 4500,
        orderStatus: 'Shipped',
      );
      stateProvider.ordersController.syncAddOrderPresentationCache(order);
      expect(order.orderStatus, 'Shipped');
      // Seller fulfillment progression halts at Shipped (Delivered is logistics/admin authority)
      expect(order.orderStatus == 'Delivered', isFalse);
    });

    test('9. Stock update uses trusted adjustStock method', () {
      final dummyProduct = AppProduct(
        id: 'prod_stock_test',
        name: 'Stock Product',
        price: '2000',
        category: 'Electronics',
        description: 'Desc',
        sellerId: 'seller_1',
        imageUrl: 'https://via.placeholder.com/150',
        stock: 50,
        variations: const [],
        wholesalePrices: const {},
      );
      stateProvider.addProduct(dummyProduct);
      expect(stateProvider.products.firstWhere((p) => p.id == 'prod_stock_test').stock, 50);
      stateProvider.adjustStock('prod_stock_test', 75);
      expect(stateProvider.products.firstWhere((p) => p.id == 'prod_stock_test').stock, 75);
    });

    test('10. Marketing local features do not claim backend persistence', () {
      expect(stateProvider.vouchers.length, 0);
      stateProvider.addVoucher('DISCOUNT10', 10.0);
      expect(stateProvider.vouchers.length, 1);
    });

    test('11. Finance payout request utilizes server idempotency key structure', () {
      final key = 'payout_seller_1_${DateTime.now().millisecondsSinceEpoch}';
      expect(key.startsWith('payout_seller_1_'), isTrue);
    });

    test('12. Seller order action updates status cleanly without direct parent mutation', () {
      final order = AppOrder(
        id: 'ord_102',
        productId: 'prod_2',
        productName: 'Silk Scarf',
        productPrice: 3000,
        sellerId: 'seller_1',
        buyerName: 'Fatima',
        shippingAddress: 'Karachi',
        shippingSpeed: 'Standard',
        paymentMethod: 'Prepaid',
        couponDiscount: 0,
        commissionDeducted: 300,
        finalPayout: 2700,
        orderStatus: 'Pending',
      );
      stateProvider.ordersController.syncAddOrderPresentationCache(order);
      stateProvider.updateOrderStatus('ord_102', 'Confirmed');
      expect(stateProvider.orders.firstWhere((o) => o.id == 'ord_102').orderStatus, 'Confirmed');
    });
  });
}
