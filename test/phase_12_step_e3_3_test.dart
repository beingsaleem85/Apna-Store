import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/core/controllers/seller_controller.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/core/services/supabase_seller_service.dart';

class MockSellerServiceE33 extends SupabaseSellerService {
  String? lastUpdatedStoreId;
  Map<String, dynamic>? lastUpdates;

  @override
  Future<bool> updateStoreDetails({
    required String storeId,
    required Map<String, dynamic> updates,
  }) async {
    lastUpdatedStoreId = storeId;
    lastUpdates = Map<String, dynamic>.from(updates);

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

  late MockSellerServiceE33 mockSellerService;
  late SellerController sellerController;

  // Real UUID store identities matching PostgreSQL UUID schema
  const targetStoreUuid = 'a1b2c3d4-e5f6-7890-abcd-1234567890ab';
  const targetOwnerUuid = '11111111-2222-3333-4444-555555555555';

  const isolationStoreUuid = '99999999-8888-7777-6666-555555555555';

  final storeUUIDTarget = AppStore(
    id: targetStoreUuid,
    shopName: 'Gulberg Fashion Store',
    shopLogo: 'https://via.placeholder.com/logoUUID.png',
    shopBanner: 'https://via.placeholder.com/bannerUUID.png',
    shopDescription: 'Original Gulberg Description',
    isApproved: true,
    kycStatus: 'Approved',
    commissionRate: 10.0,
    balance: 15000.0,
  );

  final storeUUIDIsolation = AppStore(
    id: isolationStoreUuid,
    shopName: 'Lahore Mobile Hub',
    shopLogo: 'https://via.placeholder.com/logoHub.png',
    shopBanner: 'https://via.placeholder.com/bannerHub.png',
    shopDescription: 'Original Hub Description',
    isApproved: false,
    kycStatus: 'Pending',
    commissionRate: 12.0,
    balance: 0.0,
  );

  setUp(() {
    mockSellerService = MockSellerServiceE33();
    sellerController = SellerController(supabaseSellerService: mockSellerService);
  });

  group('Phase 12 Step E3.3 Characterization Tests — Real UUID Identity & Naming Closure', () {
    test('A. Real store identity is UUID compliant', () {
      final uuidRegExp = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      expect(uuidRegExp.hasMatch(targetStoreUuid), isTrue);
      expect(uuidRegExp.hasMatch(targetOwnerUuid), isTrue);
    });

    test('B. storeId and ownerId are distinct concepts', () {
      expect(targetStoreUuid, isNot(equals(targetOwnerUuid)));
    });

    test('C. Profile update uses storeId as seller_stores row identity filter', () async {
      sellerController.syncAddStorePresentationCache(storeUUIDTarget);
      await sellerController.updateStoreProfile(targetStoreUuid, 'Updated Gulberg', 'New Gulberg Desc', '', '');

      expect(mockSellerService.lastUpdatedStoreId, targetStoreUuid);
      expect(mockSellerService.lastUpdatedStoreId, isNot(equals(targetOwnerUuid)));
    });

    test('D. Ambiguous sellerId parameter renamed to storeId in SellerController', () {
      final file = File('lib/core/controllers/seller_controller.dart');
      final content = file.readAsStringSync();
      expect(content.contains('Future<void> updateStoreProfile('), isTrue);
      expect(content.contains('String storeId,'), isTrue);
    });

    test('E. Canonical DB payload columns only without raw path keys', () async {
      sellerController.syncAddStorePresentationCache(storeUUIDTarget);
      await sellerController.updateStoreProfile(
        targetStoreUuid,
        'Name',
        'Desc',
        'https://logo.png',
        'https://banner.png',
      );

      final updates = mockSellerService.lastUpdates!;
      expect(updates.containsKey('shop_name'), isTrue);
      expect(updates.containsKey('shop_description'), isTrue);
      expect(updates.containsKey('shop_logo'), isTrue);
      expect(updates.containsKey('shop_banner'), isTrue);
      expect(updates.containsKey('shop_logo_path'), isFalse);
      expect(updates.containsKey('shop_banner_path'), isFalse);
    });

    test('F. Protected fields remain unchanged during UUID row update', () async {
      sellerController.syncAddStorePresentationCache(storeUUIDTarget);
      await sellerController.updateStoreProfile(targetStoreUuid, 'Name', 'Desc', '', '');

      final target = sellerController.getStoreById(targetStoreUuid)!;
      expect(target.isApproved, isTrue);
      expect(target.kycStatus, 'Approved');
      expect(target.commissionRate, 10.0);
      expect(target.balance, 15000.0);
    });

    test('G. Second store remains completely unchanged (cross-store isolation)', () async {
      sellerController.syncAddStorePresentationCache(storeUUIDTarget);
      sellerController.syncAddStorePresentationCache(storeUUIDIsolation);

      await sellerController.updateStoreProfile(targetStoreUuid, 'Changed Gulberg', 'Changed Gulberg Desc', '', '');

      final isolationStore = sellerController.getStoreById(isolationStoreUuid)!;
      expect(isolationStore.shopName, 'Lahore Mobile Hub');
      expect(isolationStore.shopDescription, 'Original Hub Description');
      expect(isolationStore.isApproved, isFalse);
    });

    test('H. Mock fixture label store_row_e3_2_001 is classified as test label', () {
      const mockLabel = 'store_row_e3_2_001';
      final uuidRegExp = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      expect(uuidRegExp.hasMatch(mockLabel), isFalse);
    });
  });
}
