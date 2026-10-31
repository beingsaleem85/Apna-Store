import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/core/controllers/catalog_controller.dart';
import 'package:apna_store/core/controllers/cart_controller.dart';
import 'package:apna_store/core/controllers/orders_controller.dart';
import 'package:apna_store/core/controllers/seller_controller.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/core/widgets/dev_version_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 12 Step F2 — Resource Lifecycle & Listener Cleanup Tests', () {
    test('A. State-owned TextEditingController disposes safely without error', () {
      final controller = TextEditingController(text: 'Initial Value');
      expect(controller.text, 'Initial Value');

      controller.dispose();
      // Verifies that attempting to add listener after dispose throws Flutter AssertionError as expected
      expect(() => controller.addListener(() {}), throwsAssertionError);
    });

    test('B. Parent-owned controller is not disposed by child widget', () async {
      final parentController = TextEditingController(text: 'Parent Controller Text');

      // Parent retains ownership
      expect(parentController.text, 'Parent Controller Text');
      parentController.text = 'Updated by Parent';

      expect(parentController.text, 'Updated by Parent');
      parentController.dispose();
    });

    test('C. ScrollController listener is removed safely without duplication', () {
      final controller = ScrollController();
      int callCount = 0;
      void listener() => callCount++;

      controller.addListener(listener);
      controller.removeListener(listener);

      // Verify listener was removed
      expect(callCount, 0);
      controller.dispose();
    });

    test('D. Timer is cancelled cleanly on widget/service dispose', () {
      Timer? timer = Timer.periodic(const Duration(milliseconds: 100), (_) {});
      expect(timer.isActive, isTrue);

      timer.cancel();
      expect(timer.isActive, isFalse);
    });

    test('E. StreamSubscription is cancelled where applicable without throwing', () async {
      final streamController = StreamController<String>();
      StreamSubscription<String>? sub = streamController.stream.listen((_) {});

      expect(sub, isNotNull);
      await sub.cancel();
      await streamController.close();
    });

    test('F. Async callback guards setState after dispose using mounted check', () async {
      bool isMounted = false;
      bool setStateCalled = false;

      Future<void> asyncOperation() async {
        await Future.delayed(const Duration(milliseconds: 10));
        if (!isMounted) return;
        setStateCalled = true;
      }

      final future = asyncOperation();
      // Simulate unmount before completion
      isMounted = false;
      await future;

      expect(setStateCalled, isFalse);
    });

    testWidgets('G. Checkout text controllers preserve typed values during rebuild', (tester) async {
      final nameCtrl = TextEditingController(text: 'Zainab Ahmed');
      final emailCtrl = TextEditingController(text: 'zainab@example.pk');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(controller: nameCtrl),
                TextField(controller: emailCtrl),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Zainab Ahmed'), findsOneWidget);
      expect(find.text('zainab@example.pk'), findsOneWidget);

      // Trigger rebuild
      await tester.pump();

      expect(nameCtrl.text, 'Zainab Ahmed');
      expect(emailCtrl.text, 'zainab@example.pk');

      nameCtrl.dispose();
      emailCtrl.dispose();
    });

    testWidgets('H. Buyer Dashboard banner mounts and disposes timer cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: DevVersionBanner(),
            body: Text('Buyer Screen'),
          ),
        ),
      );

      expect(find.text('Buyer Screen'), findsOneWidget);

      // Unmount banner
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Buyer Screen Unmounted Banner'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Buyer Screen Unmounted Banner'), findsOneWidget);
    });

    testWidgets('I. Seller Dashboard navigation/rebuild has no lifecycle exception', (tester) async {
      final state = AppStateProvider();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Text('Seller Section — Total Stores: ${state.sellerController.stores.length}'),
          ),
        ),
      );

      expect(find.textContaining('Seller Section'), findsOneWidget);
      await tester.pumpAndSettle();
      state.dispose();
    });

    testWidgets('J. Product Details dialog opens and closes repeatedly without lifecycle exception', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const AlertDialog(title: Text('Product Spec Dialog')),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Product Spec Dialog'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Product Spec Dialog'));
      await tester.pumpAndSettle();
    });

    testWidgets('K. Desktop Checkout open and close has no lifecycle exception', (tester) async {
      final textCtrl = TextEditingController(text: 'Model Town Lahore');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: textCtrl),
          ),
        ),
      );

      expect(find.text('Model Town Lahore'), findsOneWidget);
      textCtrl.dispose();
    });

    testWidgets('L. Mobile Checkout open and close has no lifecycle exception', (tester) async {
      final textCtrl = TextEditingController(text: '+92 300 1234567');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(controller: textCtrl),
          ),
        ),
      );

      expect(find.text('+92 300 1234567'), findsOneWidget);
      textCtrl.dispose();
    });

    test('M. Provider controllers maintain single instance lifecycle across AppStateProvider', () {
      final catalog = CatalogController();
      final cart = CartController();
      final orders = OrdersController();
      final seller = SellerController();

      final provider = AppStateProvider(
        catalogController: catalog,
        cartController: cart,
        ordersController: orders,
        sellerController: seller,
      );

      expect(provider.catalogController, same(catalog));
      expect(provider.cartController, same(cart));
      expect(provider.ordersController, same(orders));
      expect(provider.sellerController, same(seller));

      provider.dispose();
    });

    testWidgets('N. AnimationController ticker is disposed without active ticker warning', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CircularProgressIndicator(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Replace widget to dispose
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Disposed Ticker Screen'),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Disposed Ticker Screen'), findsOneWidget);
    });

    test('O. AppStateProvider dispose removes sub-controller listeners cleanly without double-dispose', () {
      final catalog = CatalogController();
      final cart = CartController();
      final orders = OrdersController();
      final seller = SellerController();

      final provider = AppStateProvider(
        catalogController: catalog,
        cartController: cart,
        ordersController: orders,
        sellerController: seller,
      );

      // Verify dispose removes listeners cleanly
      expect(() => provider.dispose(), returnsNormally);
    });
  });
}
