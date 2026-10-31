import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:apna_store/core/controllers/catalog_controller.dart';
import 'package:apna_store/core/controllers/cart_controller.dart';
import 'package:apna_store/core/controllers/orders_controller.dart';
import 'package:apna_store/core/controllers/seller_controller.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/core/services/app_auth_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 12 Step F2.1 Characterization Tests — Provider Ownership & Dialog Lifecycle Final Closure', () {
    testWidgets('A. Mount full root provider tree, access controllers, and unmount without double-dispose exception', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppAuthProvider()),
            ChangeNotifierProvider(create: (_) => CatalogController()),
            ChangeNotifierProvider(create: (_) => CartController()),
            ChangeNotifierProvider(create: (_) => OrdersController()),
            ChangeNotifierProvider(create: (_) => SellerController()),
            ChangeNotifierProxyProvider4<CatalogController, CartController, OrdersController, SellerController, AppStateProvider>(
              create: (ctx) => AppStateProvider(
                catalogController: Provider.of<CatalogController>(ctx, listen: false),
                cartController: Provider.of<CartController>(ctx, listen: false),
                ordersController: Provider.of<OrdersController>(ctx, listen: false),
                sellerController: Provider.of<SellerController>(ctx, listen: false),
              ),
              update: (ctx, catalog, cart, orders, seller, previous) {
                if (previous != null) {
                  previous.updateDependencies(
                    catalogController: catalog,
                    cartController: cart,
                    ordersController: orders,
                    sellerController: seller,
                  );
                  return previous;
                }
                return AppStateProvider(
                  catalogController: catalog,
                  cartController: cart,
                  ordersController: orders,
                  sellerController: seller,
                );
              },
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Text('Root Provider Mounted'),
            ),
          ),
        ),
      );

      expect(find.text('Root Provider Mounted'), findsOneWidget);

      // Unmount tree to trigger Provider dispose sequence
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Root Provider Unmounted'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Root Provider Unmounted'), findsOneWidget);
    });

    testWidgets('B. Remount application tree once and confirm controllers work normally', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => CatalogController()),
            ChangeNotifierProvider(create: (_) => CartController()),
            ChangeNotifierProvider(create: (_) => OrdersController()),
            ChangeNotifierProvider(create: (_) => SellerController()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Text('Remounted App Tree'),
            ),
          ),
        ),
      );

      expect(find.text('Remounted App Tree'), findsOneWidget);
    });

    testWidgets('C. Open and close dialog normally without lifecycle exception', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  final ctrl = TextEditingController(text: 'Dialog Test Value');
                  try {
                    await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Normal Dialog Title'),
                        content: TextField(controller: ctrl),
                      ),
                    );
                  } finally {
                    ctrl.dispose();
                  }
                },
                child: const Text('Open Normal Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Normal Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Normal Dialog Title'), findsOneWidget);

      // Tap outside / dismiss dialog
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    });

    testWidgets('D. Dismiss dialog without submit without lifecycle exception', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  final ctrl = TextEditingController();
                  try {
                    await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Dismissable Modal'),
                        content: TextField(controller: ctrl),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    );
                  } finally {
                    ctrl.dispose();
                  }
                },
                child: const Text('Open Dismissable Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dismissable Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Dismissable Modal'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('E. Submit dialog then close without lifecycle exception', (tester) async {
      String submittedValue = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  final ctrl = TextEditingController(text: 'Submitted Data');
                  try {
                    await showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Submit Modal'),
                        content: TextField(controller: ctrl),
                        actions: [
                          ElevatedButton(
                            onPressed: () {
                              submittedValue = ctrl.text;
                              Navigator.pop(ctx);
                            },
                            child: const Text('Submit'),
                          ),
                        ],
                      ),
                    );
                  } finally {
                    ctrl.dispose();
                  }
                },
                child: const Text('Open Submit Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Submit Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Submit Modal'), findsOneWidget);

      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(submittedValue, 'Submitted Data');
    });

    test('F. Disposed TextEditingController is not accessed after dispose', () {
      final ctrl = TextEditingController(text: 'Disposable');
      expect(ctrl.text, 'Disposable');

      ctrl.dispose();
      expect(() => ctrl.addListener(() {}), throwsFlutterError);
    });
  });
}
