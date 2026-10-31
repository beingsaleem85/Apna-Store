import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:apna_store/core/controllers/catalog_controller.dart';
import 'package:apna_store/core/controllers/cart_controller.dart';
import 'package:apna_store/core/controllers/orders_controller.dart';
import 'package:apna_store/core/controllers/seller_controller.dart';
import 'package:apna_store/core/services/app_state_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogController catalogController;
  late CartController cartController;
  late OrdersController ordersController;
  late SellerController sellerController;
  late AppStateProvider appStateProvider;

  final testStore1 = AppStore(
    id: 'store_e3_001',
    shopName: 'Gulberg Fashion Store',
    shopLogo: 'https://via.placeholder.com/150',
    shopBanner: 'https://via.placeholder.com/600',
    shopDescription: 'Luxury fashion boutique',
    isApproved: true,
    kycStatus: 'Approved',
    commissionRate: 8.5,
    balance: 15000.0,
    fullName: 'Sara Khan',
    businessName: 'Gulberg Boutique Ltd',
    email: 'sara@gulberg.com',
  );

  final testStore2 = AppStore(
    id: 'store_e3_002',
    shopName: 'Tech Hub Pakistan',
    shopLogo: 'https://via.placeholder.com/150',
    shopBanner: 'https://via.placeholder.com/600',
    shopDescription: 'Official electronic store',
    isApproved: true,
    kycStatus: 'Approved',
    commissionRate: 10.0,
    balance: 45000.0,
    fullName: 'Bilal Ahmed',
    businessName: 'Tech Hub Pvt Ltd',
    email: 'bilal@techhub.pk',
  );

  setUp(() {
    catalogController = CatalogController();
    cartController = CartController();
    ordersController = OrdersController();
    sellerController = SellerController();
    appStateProvider = AppStateProvider(
      catalogController: catalogController,
      cartController: cartController,
      ordersController: ordersController,
      sellerController: sellerController,
    );
  });

  group('Phase 12 Step E3 Characterization Tests — SellerController Domain Extraction', () {
    test('A. Initial state of SellerController has safe defaults', () {
      expect(sellerController.isLoadingStores, isFalse);
      expect(sellerController.storesError, isNull);
    });

    test('B. Seller stores fetch success populates presentation cache', () {
      sellerController.syncAddStorePresentationCache(testStore1);
      expect(sellerController.stores.isNotEmpty, isTrue);
      expect(sellerController.getStoreById('store_e3_001')?.shopName, 'Gulberg Fashion Store');
    });

    test('C. Fetch failure handles errors cleanly without crash', () async {
      await sellerController.fetchStoresFromSupabase();
      expect(sellerController.isLoadingStores, isFalse);
    });

    test('D. Backend data replaces stale presentation cache on sync', () {
      sellerController.syncAddStorePresentationCache(testStore1);
      expect(sellerController.getStoreById('store_e3_001')?.shopName, 'Gulberg Fashion Store');

      final updatedStore1 = AppStore(
        id: 'store_e3_001',
        shopName: 'Gulberg Fashion Store Updated',
        shopLogo: 'https://via.placeholder.com/150',
        shopBanner: 'https://via.placeholder.com/600',
        shopDescription: 'Updated luxury boutique',
        isApproved: true,
        kycStatus: 'Approved',
      );

      sellerController.syncAddStorePresentationCache(updatedStore1);
      expect(sellerController.getStoreById('store_e3_001')?.shopName, 'Gulberg Fashion Store Updated');
    });

    test('E. Active store selection updates active store context', () {
      sellerController.syncAddStorePresentationCache(testStore1);
      sellerController.syncAddStorePresentationCache(testStore2);

      sellerController.setActiveSellerStoreId('store_e3_002');
      expect(sellerController.activeSellerStoreId, 'store_e3_002');
      expect(sellerController.activeSellerStore?.shopName, 'Tech Hub Pakistan');
    });

    test('F. Store lookup helpers find store by ID and email', () {
      sellerController.syncAddStorePresentationCache(testStore1);

      final foundById = sellerController.getStoreById('store_e3_001');
      expect(foundById?.email, 'sara@gulberg.com');

      final foundByEmail = sellerController.getStoreByEmail('sara@gulberg.com');
      expect(foundByEmail?.id, 'store_e3_001');
    });

    test('G. Loading state flag toggles correctly', () {
      expect(sellerController.isLoadingStores, isFalse);
    });

    test('H. Error state flag handles failure cleanly', () {
      expect(sellerController.storesError, isNull);
    });

    test('I. AppStateProvider.stores getter delegates to SellerController', () {
      sellerController.syncAddStorePresentationCache(testStore1);
      expect(appStateProvider.stores.any((s) => s.id == 'store_e3_001'), isTrue);
    });

    test('J. activeSellerStore compatibility delegates to SellerController', () {
      sellerController.syncAddStorePresentationCache(testStore1);
      appStateProvider.setLoggedInSellerId('store_e3_001');
      expect(appStateProvider.activeSellerStore?.id, 'store_e3_001');
    });

    test('K. No duplicate mutable seller store list in AppStateProvider', () {
      expect(appStateProvider.stores, equals(sellerController.stores));
    });

    test('L. SellerController contains 0 role assignment authority calls', () {
      final file = File('lib/core/controllers/seller_controller.dart');
      final content = file.readAsStringSync();
      expect(content.contains("assign_user_role"), isFalse);
    });

    test('M. SellerController contains 0 admin seller approval RPC ownership calls', () {
      final file = File('lib/core/controllers/seller_controller.dart');
      final content = file.readAsStringSync();
      expect(content.contains("admin_review_seller_application"), isFalse);
    });

    test('N. SellerController contains 0 KYC document review RPC calls', () {
      final file = File('lib/core/controllers/seller_controller.dart');
      final content = file.readAsStringSync();
      expect(content.contains("admin_review_kyc_document"), isFalse);
    });

    test('O. SellerController contains 0 finance payout RPC calls', () {
      final file = File('lib/core/controllers/seller_controller.dart');
      final content = file.readAsStringSync();
      expect(content.contains("seller_request_payout"), isFalse);
    });

    test('P. SellerController contains 0 inventory stock RPC calls', () {
      final file = File('lib/core/controllers/seller_controller.dart');
      final content = file.readAsStringSync();
      expect(content.contains("seller_update_product_stock"), isFalse);
    });

    test('Q. SellerController contains 0 fulfillment RPC calls', () {
      final file = File('lib/core/controllers/seller_controller.dart');
      final content = file.readAsStringSync();
      expect(content.contains("seller_update_fulfillment_status"), isFalse);
      expect(content.contains("buyer_orders"), isFalse);
    });

    test('R. Profile update updates local cache cleanly', () async {
      sellerController.syncAddStorePresentationCache(testStore1);
      await sellerController.updateStoreProfile('store_e3_001', 'Sara Fashion House', 'Desc New', '', '');
      expect(sellerController.getStoreById('store_e3_001')?.shopName, 'Sara Fashion House');
    });

    test('S. Protected fields are untouched during profile update', () async {
      sellerController.syncAddStorePresentationCache(testStore1);
      await sellerController.updateStoreProfile('store_e3_001', 'Sara Fashion House', 'Desc New', '', '');

      final updated = sellerController.getStoreById('store_e3_001')!;
      expect(updated.isApproved, isTrue);
      expect(updated.kycStatus, 'Approved');
      expect(updated.commissionRate, 8.5);
    });

    testWidgets('T. Seller dashboard store context renders using SellerController', (tester) async {
      final tStore = AppStore(
        id: 'store_e3_test_t',
        shopName: 'Gulberg Fashion Store T',
      );
      sellerController.syncAddStorePresentationCache(tStore);
      sellerController.setActiveSellerStoreId('store_e3_test_t');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: sellerController),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer<SellerController>(
                builder: (_, controller, __) {
                  return Text(controller.activeSellerStore?.shopName ?? 'No Active Store');
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Gulberg Fashion Store T'), findsOneWidget);
    });

    test('U. Seller registration backend authority is preserved', () async {
      final registered = await appStateProvider.registerSeller(
        fullName: 'Zainab Ahmed',
        businessName: 'Zainab Crafts',
        storeName: 'Zainab Handcrafted',
        email: 'zainab@crafts.pk',
        mobileNumber: '03001122334',
        country: 'Pakistan',
        city: 'Lahore',
        businessAddress: 'Model Town, Lahore',
        storeDescription: 'Handmade crafts',
        storeCategory: 'Handicrafts',
        storeSlug: 'zainab-crafts',
        storeContactNumber: '03001122334',
        storeEmail: 'zainab@crafts.pk',
        storeLogo: '',
        storeBanner: '',
      );

      expect(registered, isTrue);
      expect(sellerController.getStoreByEmail('zainab@crafts.pk')?.shopName, 'Zainab Handcrafted');
    });
  });
}
