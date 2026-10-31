import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:apna_store/core/controllers/catalog_controller.dart';
import 'package:apna_store/core/controllers/cart_controller.dart';
import 'package:apna_store/core/controllers/orders_controller.dart';
import 'package:apna_store/core/controllers/seller_controller.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/core/services/app_auth_provider.dart';
import 'package:apna_store/features/seller/screens/seller_dashboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Seller Login & Dashboard Access Regression Tests', () {
    testWidgets('A. Unauthenticated seller route shows login required ("Please login")', (tester) async {
      final catalog = CatalogController();
      final cart = CartController();
      final orders = OrdersController();
      final seller = SellerController();
      final appState = AppStateProvider(
        catalogController: catalog,
        cartController: cart,
        ordersController: orders,
        sellerController: seller,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppAuthProvider>(create: (_) => AppAuthProvider()),
            ChangeNotifierProvider<AppStateProvider>.value(value: appState),
          ],
          child: const MaterialApp(
            home: SellerDashboard(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Access Denied'), findsOneWidget);
      expect(find.text('Please login to access the Seller Center dashboard.'), findsOneWidget);
    });

    testWidgets('B. Authenticated Pending seller does NOT show "Please login" and displays Pending Approval state', (tester) async {
      final catalog = CatalogController();
      final cart = CartController();
      final orders = OrdersController();
      final seller = SellerController();
      final appState = AppStateProvider(
        catalogController: catalog,
        cartController: cart,
        ordersController: orders,
        sellerController: seller,
      );

      final pendingStore = AppStore(
        id: 'pending_store_001',
        ownerId: 'user_pending_123',
        shopName: 'Green Organic Store',
        isApproved: false,
        kycStatus: 'Pending',
      );

      seller.syncAddStorePresentationCache(pendingStore);
      appState.setLoggedInSellerId('pending_store_001');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppAuthProvider>(create: (_) => AppAuthProvider()),
            ChangeNotifierProvider<AppStateProvider>.value(value: appState),
          ],
          child: const MaterialApp(
            home: SellerDashboard(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Access Denied'), findsNothing);
      expect(find.text('Please login to access the Seller Center dashboard.'), findsNothing);
      expect(find.text('Application Pending Approval'), findsOneWidget);
      expect(find.textContaining('Green Organic Store'), findsOneWidget);
    });

    testWidgets('C. Approved seller can access active seller dashboard section', (tester) async {
      final catalog = CatalogController();
      final cart = CartController();
      final orders = OrdersController();
      final seller = SellerController();
      final appState = AppStateProvider(
        catalogController: catalog,
        cartController: cart,
        ordersController: orders,
        sellerController: seller,
      );

      final approvedStore = AppStore(
        id: 'approved_store_001',
        ownerId: 'user_approved_456',
        shopName: 'Lahore Tech Superstore',
        isApproved: true,
        kycStatus: 'Approved',
      );

      seller.syncAddStorePresentationCache(approvedStore);
      appState.setLoggedInSellerId('approved_store_001');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppAuthProvider>(create: (_) => AppAuthProvider()),
            ChangeNotifierProvider<AppStateProvider>.value(value: appState),
          ],
          child: const MaterialApp(
            home: SellerDashboard(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Access Denied'), findsNothing);
      expect(find.text('Application Pending Approval'), findsNothing);
      expect(find.textContaining('Lahore Tech Superstore'), findsAtLeastNWidgets(1));
    });

    testWidgets('D. Suspended seller remains blocked with Store Account Suspended message', (tester) async {
      final catalog = CatalogController();
      final cart = CartController();
      final orders = OrdersController();
      final seller = SellerController();
      final appState = AppStateProvider(
        catalogController: catalog,
        cartController: cart,
        ordersController: orders,
        sellerController: seller,
      );

      final suspendedStore = AppStore(
        id: 'suspended_store_001',
        ownerId: 'user_suspended_789',
        shopName: 'Suspended Electronics Shop',
        isApproved: true,
        isSuspended: true,
      );

      seller.syncAddStorePresentationCache(suspendedStore);
      appState.setLoggedInSellerId('suspended_store_001');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppAuthProvider>(create: (_) => AppAuthProvider()),
            ChangeNotifierProvider<AppStateProvider>.value(value: appState),
          ],
          child: const MaterialApp(
            home: SellerDashboard(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Access Denied'), findsNothing);
      expect(find.text('Store Account Suspended'), findsOneWidget);
    });

    test('E. AppStore.fromJson correctly parses owner_id and is_suspended fields', () {
      final jsonMap = {
        'id': 'store_json_001',
        'shop_name': 'JSON Test Store',
        'owner_id': 'owner_uuid_999',
        'is_approved': true,
        'is_suspended': false,
      };

      final store = AppStore.fromJson(jsonMap);
      expect(store.id, 'store_json_001');
      expect(store.shopName, 'JSON Test Store');
      expect(store.ownerId, 'owner_uuid_999');
      expect(store.isApproved, isTrue);
      expect(store.isSuspended, isFalse);
    });

    test('F. SellerController getStoreByOwnerId resolves store by ownerId or id', () {
      final controller = SellerController();
      final store = AppStore(
        id: 'store_owner_test_id',
        ownerId: 'owner_unique_uuid_777',
        shopName: 'Owner Resolution Store',
      );

      controller.syncAddStorePresentationCache(store);

      final resolvedByOwner = controller.getStoreByOwnerId('owner_unique_uuid_777');
      expect(resolvedByOwner, isNotNull);
      expect(resolvedByOwner?.shopName, 'Owner Resolution Store');
    });
  });
}
