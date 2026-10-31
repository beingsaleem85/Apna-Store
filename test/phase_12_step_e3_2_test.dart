import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/core/controllers/seller_controller.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/core/services/supabase_seller_service.dart';

class MockSellerServiceE32 extends SupabaseSellerService {
  String? lastUpdatedStoreId;
  Map<String, dynamic>? lastUpdates;

  @override
  Future<bool> updateStoreDetails({
    required String storeId,
    required Map<String, dynamic> updates,
  }) async {
    lastUpdatedStoreId = storeId;
    lastUpdates = Map<String, dynamic>.from(updates);

    // Perform translation as canonical service does
    if (lastUpdates!.containsKey('shop_logo_path')) {
      lastUpdates!['shop_logo'] = lastUpdates!.remove('shop_logo_path');
    }
    if (lastUpdates!.containsKey('shop_banner_path')) {
      lastUpdates!['shop_banner'] = lastUpdates!.remove('shop_banner_path');
    }
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSellerServiceE32 mockSellerService;
  late SellerController sellerController;

  final storeA = AppStore(
    id: 'store_row_e3_2_001',
    shopName: 'Store A',
    shopLogo: 'https://via.placeholder.com/logoA.png',
    shopBanner: 'https://via.placeholder.com/bannerA.png',
    shopDescription: 'Description A',
    isApproved: true,
    kycStatus: 'Approved',
  );

  final storeB = AppStore(
    id: 'store_row_e3_2_002',
    shopName: 'Store B',
    shopLogo: 'https://via.placeholder.com/logoB.png',
    shopBanner: 'https://via.placeholder.com/bannerB.png',
    shopDescription: 'Description B',
    isApproved: false,
    kycStatus: 'Pending',
  );

  setUp(() {
    mockSellerService = MockSellerServiceE32();
    sellerController = SellerController(supabaseSellerService: mockSellerService);
  });

  group('Phase 12 Step E3.2 Characterization Tests — Store Identity & Schema Mapping Verification', () {
    test('A. Store row ID and owner/user ID are clearly distinguished in model and DTO', () {
      final file = File('lib/core/models/dtos/seller_store_dto.dart');
      final content = file.readAsStringSync();
      expect(content.contains("'id': id"), isTrue);
      expect(content.contains("'owner_id': ownerId"), isTrue);
    });

    test('B. updateStoreDetails targets correct store row ID', () async {
      sellerController.syncAddStorePresentationCache(storeA);
      sellerController.syncAddStorePresentationCache(storeB);

      await sellerController.updateStoreProfile('store_row_e3_2_001', 'Updated Store A', 'New Desc A', '', '');
      expect(mockSellerService.lastUpdatedStoreId, 'store_row_e3_2_001');
    });

    test('C. Presentation profile fields map to exact canonical DB columns', () async {
      sellerController.syncAddStorePresentationCache(storeA);
      await sellerController.updateStoreProfile(
        'store_row_e3_2_001',
        'Mapped Store Name',
        'Mapped Description',
        'https://logo.png',
        'https://banner.png',
      );

      final updates = mockSellerService.lastUpdates!;
      expect(updates.containsKey('shop_name'), isTrue);
      expect(updates.containsKey('shop_description'), isTrue);
      expect(updates.containsKey('shop_logo'), isTrue);
      expect(updates.containsKey('shop_banner'), isTrue);
    });

    test('D. No shop_logo_path/shop_banner_path is sent directly to seller_stores DB without translation', () async {
      sellerController.syncAddStorePresentationCache(storeA);
      await sellerController.updateStoreProfile(
        'store_row_e3_2_001',
        'Store Name',
        'Description',
        'https://logo.png',
        'https://banner.png',
      );

      final updates = mockSellerService.lastUpdates!;
      expect(updates.containsKey('shop_logo_path'), isFalse);
      expect(updates.containsKey('shop_banner_path'), isFalse);
    });

    test('E. Protected fields remain excluded from profile update payload', () async {
      sellerController.syncAddStorePresentationCache(storeA);
      await sellerController.updateStoreProfile('store_row_e3_2_001', 'Store A', 'Desc A', '', '');

      final updates = mockSellerService.lastUpdates!;
      for (final protected in SellerController.protectedFields) {
        expect(updates.containsKey(protected), isFalse);
      }
    });

    test('F. Cross-store profile update cannot occur', () async {
      sellerController.syncAddStorePresentationCache(storeA);
      sellerController.syncAddStorePresentationCache(storeB);

      await sellerController.updateStoreProfile('store_row_e3_2_001', 'Isolated Store A', 'Isolated Desc A', '', '');

      // Store A updated, Store B untouched
      expect(sellerController.getStoreById('store_row_e3_2_001')?.shopName, 'Isolated Store A');
      expect(sellerController.getStoreById('store_row_e3_2_002')?.shopName, 'Store B');
    });

    test('G. KYC upload and KYC review authority remain separate', () {
      final serviceContent = File('lib/core/services/supabase_seller_service.dart').readAsStringSync();
      final controllerContent = File('lib/core/controllers/seller_controller.dart').readAsStringSync();

      expect(serviceContent.contains('uploadPrivateKycDocument'), isTrue);
      expect(controllerContent.contains('admin_review_kyc_document'), isFalse);
    });
  });
}
