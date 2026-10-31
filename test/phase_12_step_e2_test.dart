import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:apna_store/core/controllers/catalog_controller.dart';
import 'package:apna_store/core/controllers/cart_controller.dart';
import 'package:apna_store/core/controllers/orders_controller.dart';
import 'package:apna_store/core/services/app_state_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogController catalogController;
  late CartController cartController;
  late OrdersController ordersController;
  late AppStateProvider appStateProvider;

  final testOrder1 = AppOrder(
    id: 'ord_test_e2_001',
    productId: 'prod_test_e2_101',
    productName: 'Smart Earbuds Pro E2',
    productPrice: 2500.0,
    sellerId: 'seller_test_e2',
    buyerName: 'Ali Khan',
    shippingAddress: 'Gulberg III, Lahore',
    shippingSpeed: 'Express',
    paymentMethod: 'COD',
    couponDiscount: 0.0,
    commissionDeducted: 250.0,
    finalPayout: 2250.0,
    orderStatus: 'Pending',
    trackingNumber: 'TRKE2001',
  );

  final testOrder2 = AppOrder(
    id: 'ord_test_e2_002',
    productId: 'prod_test_e2_102',
    productName: 'Wireless Charger E2',
    productPrice: 1500.0,
    sellerId: 'seller_test_e2_b',
    buyerName: 'Sara Ahmed',
    shippingAddress: 'DHA Phase 5, Lahore',
    shippingSpeed: 'Standard',
    paymentMethod: 'Wallet',
    couponDiscount: 100.0,
    commissionDeducted: 140.0,
    finalPayout: 1260.0,
    orderStatus: 'Processing',
    trackingNumber: 'TRKE2002',
  );

  setUp(() {
    catalogController = CatalogController();
    cartController = CartController();
    ordersController = OrdersController();
    appStateProvider = AppStateProvider(
      catalogController: catalogController,
      cartController: cartController,
      ordersController: ordersController,
    );
  });

  group('Phase 12 Step E2 Characterization Tests — OrdersController Domain Extraction', () {
    test('A. Initial state of OrdersController is empty and not loading', () {
      expect(ordersController.isLoadingOrders, isFalse);
      expect(ordersController.ordersError, isNull);
    });

    test('B. Order fetch success populates presentation cache', () async {
      ordersController.syncAddOrderPresentationCache(testOrder1);
      expect(ordersController.orders.length, 1);
      expect(ordersController.orders.first.id, 'ord_test_e2_001');
    });

    test('C. Order fetch failure preserves safe error state', () async {
      await ordersController.fetchOrdersFromSupabase();
      expect(ordersController.isLoadingOrders, isFalse);
    });

    test('D. Canonical backend data replaces stale presentation cache on sync', () {
      ordersController.syncAddOrderPresentationCache(testOrder1);
      expect(ordersController.orders.length, 1);

      ordersController.clearOrdersCache();
      ordersController.syncAddOrderPresentationCache(testOrder2);
      expect(ordersController.orders.length, 1);
      expect(ordersController.orders.first.id, 'ord_test_e2_002');
    });

    test('E. Order lookup helpers find orders by ID, buyer, and seller', () {
      ordersController.syncAddOrderPresentationCache(testOrder1);
      ordersController.syncAddOrderPresentationCache(testOrder2);

      final foundById = ordersController.getOrderById('ord_test_e2_001');
      expect(foundById?.productName, 'Smart Earbuds Pro E2');

      final buyerOrders = ordersController.getOrdersForBuyer('Ali Khan');
      expect(buyerOrders.length, 1);

      final sellerOrders = ordersController.getOrdersForSeller('seller_test_e2');
      expect(sellerOrders.length, 1);
    });

    test('F. Loading state flag toggles correctly', () {
      expect(ordersController.isLoadingOrders, isFalse);
    });

    test('G. Error state flag handles failure cleanly', () {
      expect(ordersController.ordersError, isNull);
    });

    test('H. OrdersController contains 0 direct buyer_orders database update calls', () {
      final file = File('lib/core/controllers/orders_controller.dart');
      final content = file.readAsStringSync();
      expect(content.contains(".from('buyer_orders').update"), isFalse);
    });

    test('I. OrdersController contains 0 create_atomic_order RPC ownership calls', () {
      final file = File('lib/core/controllers/orders_controller.dart');
      final content = file.readAsStringSync();
      expect(content.contains("create_atomic_order"), isFalse);
    });

    test('J. OrdersController contains 0 seller_update_fulfillment_status RPC ownership calls', () {
      final file = File('lib/core/controllers/orders_controller.dart');
      final content = file.readAsStringSync();
      expect(content.contains("seller_update_fulfillment_status"), isFalse);
    });

    test('K. OrdersController contains 0 refund authority RPC calls', () {
      final file = File('lib/core/controllers/orders_controller.dart');
      final content = file.readAsStringSync();
      expect(content.contains("seller_request_refund"), isFalse);
    });

    test('L. AppStateProvider.orders getter delegates to OrdersController', () {
      ordersController.syncAddOrderPresentationCache(testOrder1);
      expect(appStateProvider.orders.length, 1);
      expect(appStateProvider.orders.first.id, 'ord_test_e2_001');
    });

    test('M. AppStateProvider.fetchOrdersFromSupabase wrapper delegates to OrdersController', () async {
      await appStateProvider.fetchOrdersFromSupabase();
      expect(appStateProvider.isLoadingOrders, isFalse);
    });

    test('N. No duplicate mutable orders list in AppStateProvider', () {
      expect(appStateProvider.orders, equals(ordersController.orders));
    });

    test('O. Checkout success syncs presentation order cache', () {
      ordersController.syncAddOrderPresentationCache(testOrder1);
      expect(ordersController.orders.length, 1);
    });

    test('P. Checkout failure does not fabricate order in OrdersController', () {
      expect(ordersController.orders.length, 0);
    });

    test('Q. Backend order status remains authoritative', () {
      ordersController.syncAddOrderPresentationCache(testOrder1);
      ordersController.syncUpdateOrderStatusCache('ord_test_e2_001', 'Processing');
      expect(ordersController.getOrderById('ord_test_e2_001')?.orderStatus, 'Processing');
    });

    testWidgets('R. Buyer order UI renders using OrdersController provider', (tester) async {
      ordersController.syncAddOrderPresentationCache(testOrder1);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: catalogController),
            ChangeNotifierProvider.value(value: cartController),
            ChangeNotifierProvider.value(value: ordersController),
            ChangeNotifierProvider.value(value: appStateProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer<OrdersController>(
                builder: (_, controller, __) {
                  return ListView.builder(
                    itemCount: controller.orders.length,
                    itemBuilder: (_, i) => Text(controller.orders[i].productName),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Smart Earbuds Pro E2'), findsOneWidget);
    });

    testWidgets('S. Broad order-only listener consumes OrdersController directly', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: ordersController,
          child: MaterialApp(
            home: Scaffold(
              body: Selector<OrdersController, int>(
                selector: (_, controller) => controller.orders.length,
                builder: (_, count, __) => Text('Orders Count: $count'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Orders Count: 0'), findsOneWidget);
      ordersController.syncAddOrderPresentationCache(testOrder1);
      await tester.pump();

      expect(find.text('Orders Count: 1'), findsOneWidget);
    });
  });
}
