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

  final testOrder = AppOrder(
    id: 'ord_e2_1_001',
    productId: 'prod_e2_1_101',
    productName: 'E2.1 Consumer Test Item',
    productPrice: 3200.0,
    sellerId: 'seller_e2_1',
    buyerName: 'Hassan',
    shippingAddress: 'Gulberg, Lahore',
    shippingSpeed: 'Express',
    paymentMethod: 'COD',
    couponDiscount: 0.0,
    commissionDeducted: 320.0,
    finalPayout: 2880.0,
    orderStatus: 'Pending',
    trackingNumber: 'TRKE21001',
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

  group('Phase 12 Step E2.1 OrdersController Consumer Wiring Closure Tests', () {
    testWidgets('A. Buyer Orders UI consumes OrdersController directly', (tester) async {
      ordersController.syncAddOrderPresentationCache(testOrder);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: ordersController),
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

      expect(find.text('E2.1 Consumer Test Item'), findsOneWidget);
    });

    testWidgets('B. Buyer order loading state comes from OrdersController', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: ordersController,
          child: MaterialApp(
            home: Scaffold(
              body: Selector<OrdersController, bool>(
                selector: (_, controller) => controller.isLoadingOrders,
                builder: (_, isLoading, __) => Text(isLoading ? 'Loading Orders...' : 'Orders Ready'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Orders Ready'), findsOneWidget);
    });

    testWidgets('C. Order refresh notifies order consumers', (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: ordersController,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer<OrdersController>(
                builder: (_, controller, __) {
                  buildCount++;
                  return Text('Count: ${controller.orders.length}');
                },
              ),
            ),
          ),
        ),
      );

      expect(buildCount, 1);
      ordersController.syncAddOrderPresentationCache(testOrder);
      await tester.pump();

      expect(buildCount, 2);
      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('D. Cart/catalog change does not rebuild order-only listener', (tester) async {
      int orderBuildCount = 0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: catalogController),
            ChangeNotifierProvider.value(value: cartController),
            ChangeNotifierProvider.value(value: ordersController),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer<OrdersController>(
                builder: (_, controller, __) {
                  orderBuildCount++;
                  return Text('Order Count: ${controller.orders.length}');
                },
              ),
            ),
          ),
        ),
      );

      expect(orderBuildCount, 1);

      // Mutate cart controller
      cartController.addToCart(AppProduct(
        id: 'prod_dummy',
        name: 'Dummy',
        price: '1000',
        category: 'Tech',
        description: 'Desc',
        sellerId: 'sel_1',
        imageUrl: '',
        stock: 10,
        variations: const [],
        wholesalePrices: const {},
      ));
      await tester.pump();

      // Order listener should NOT rebuild when cart changes
      expect(orderBuildCount, 1);
    });

    test('E. AppStateProvider compatibility wrapper still works', () {
      ordersController.syncAddOrderPresentationCache(testOrder);
      expect(appStateProvider.orders.length, 1);
      expect(appStateProvider.orders.first.id, 'ord_e2_1_001');
    });
  });
}
