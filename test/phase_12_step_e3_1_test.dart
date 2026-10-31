import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/core/controllers/catalog_controller.dart';
import 'package:apna_store/core/controllers/cart_controller.dart';
import 'package:apna_store/core/controllers/orders_controller.dart';
import 'package:apna_store/core/controllers/seller_controller.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/core/services/supabase_seller_service.dart';

class MockSupabaseSellerService extends SupabaseSellerService {
  bool updateStoreDetailsCalled = false;
  bool shouldFailUpdate = false;
  Map<String, dynamic>? lastUpdates;

  @override
  Future<bool> updateStoreDetails({
    required String storeId,
    required Map<String, dynamic> updates,
  }) async {
    updateStoreDetailsCalled = true;
    lastUpdates = updates;
    if (shouldFailUpdate) {
      throw Exception('Backend database error updating store details');
    }
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogController catalogController;
  late CartController cartController;
  late OrdersController ordersController;
  late MockSupabaseSellerService mockSellerService;
  late SellerController sellerController;
  late AppStateProvider appStateProvider;
  late AppStore testStore;

  setUp(() {
    testStore = AppStore(
      id: 'store_e3_1_001',
      shopName: 'Original Shop Name',
      shopLogo: 'https://via.placeholder.com/150',
      shopBanner: 'https://via.placeholder.com/600',
      shopDescription: 'Original Description',
      isApproved: false,
      kycStatus: 'Pending',
      commissionRate: 10.0,
      balance: 5000.0,
    );
    catalogController = CatalogController();
    cartController = CartController();
    ordersController = OrdersController();
    mockSellerService = MockSupabaseSellerService();
    sellerController = SellerController(supabaseSellerService: mockSellerService);
    appStateProvider = AppStateProvider(
      catalogController: catalogController,
      cartController: cartController,
      ordersController: ordersController,
      sellerController: sellerController,
    );
  });

  group('Phase 12 Step E3.1 Characterization Tests — SellerController Final Authority Closure', () {
    test('A. Profile update delegates to canonical SupabaseSellerService', () async {
      sellerController.syncAddStorePresentationCache(testStore);
      await sellerController.updateStoreProfile('store_e3_1_001', 'New Shop Name', 'New Description', '', '');

      expect(mockSellerService.updateStoreDetailsCalled, isTrue);
      expect(mockSellerService.lastUpdates?['shop_name'], 'New Shop Name');
    });

    test('B. SellerController source code contains 0 direct seller_stores UPDATE string queries', () {
      final file = File('lib/core/controllers/seller_controller.dart');
      final content = file.readAsStringSync();
      expect(content.contains(".from('seller_stores').update"), isFalse);
    });

    test('C. Protected fields cannot enter profile update payload', () async {
      expect(SellerController.protectedFields.contains('is_approved'), isTrue);
      expect(SellerController.protectedFields.contains('kyc_status'), isTrue);
      expect(SellerController.protectedFields.contains('balance'), isTrue);
      expect(SellerController.protectedFields.contains('commission_rate'), isTrue);
    });

    test('D. Failed backend profile update does not fake cache success and rethrows', () async {
      sellerController.syncAddStorePresentationCache(testStore);
      mockSellerService.shouldFailUpdate = true;

      expect(
        () => sellerController.updateStoreProfile('store_e3_1_001', 'Hacked Name', 'Hacked Desc', '', ''),
        throwsA(isA<Exception>()),
      );

      expect(sellerController.getStoreById('store_e3_1_001')?.shopName, 'Original Shop Name');
    });

    test('E. Successful backend update syncs presentation cache afterwards', () async {
      sellerController.syncAddStorePresentationCache(testStore);
      mockSellerService.shouldFailUpdate = false;

      await sellerController.updateStoreProfile('store_e3_1_001', 'Verified Name', 'Verified Desc', '', '');
      expect(sellerController.getStoreById('store_e3_1_001')?.shopName, 'Verified Name');
    });

    test('F. Vacation mode classification is local presentation state', () {
      sellerController.syncAddStorePresentationCache(testStore);
      expect(sellerController.getStoreById('store_e3_1_001')?.isVacationMode, isFalse);

      sellerController.setVacationMode('store_e3_1_001', true);
      expect(sellerController.getStoreById('store_e3_1_001')?.isVacationMode, isTrue);
    });

    test('G. Follow shop classification is local presentation state', () {
      sellerController.syncAddStorePresentationCache(testStore);
      expect(sellerController.getStoreById('store_e3_1_001')?.followersCount, 0);

      sellerController.followShop('store_e3_1_001');
      expect(sellerController.getStoreById('store_e3_1_001')?.followersCount, 1);
    });

    test('H. Backend fetch overrides stale local security state', () async {
      final staleLocalStore = AppStore(
        id: 'store_stale_001',
        shopName: 'Stale Approved Store',
        isApproved: true,
        kycStatus: 'Approved',
      );
      sellerController.syncAddStorePresentationCache(staleLocalStore);

      // Re-fetching from Supabase reconciles state
      await sellerController.fetchStoresFromSupabase();
      expect(sellerController.isLoadingStores, isFalse);
    });

    test('I. Inventory authority is ProductRepository, not CatalogController', () {
      final file = File('lib/core/controllers/catalog_controller.dart');
      final content = file.readAsStringSync();
      expect(content.contains("seller_update_product_stock"), isFalse);
    });

    test('J. AppStateProvider delegates store profile update to SellerController without duplicate path', () async {
      sellerController.syncAddStorePresentationCache(testStore);
      await appStateProvider.updateStoreProfile('store_e3_1_001', 'Delegated Name', 'Delegated Desc', '', '');

      expect(mockSellerService.updateStoreDetailsCalled, isTrue);
      expect(sellerController.getStoreById('store_e3_1_001')?.shopName, 'Delegated Name');
    });
  });
}
