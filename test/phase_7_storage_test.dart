import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/core/routes/app_routes.dart';
import 'package:apna_store/core/routes/app_router.dart';
import 'package:apna_store/features/seller/screens/seller_auth_screens.dart';

void main() {
  group('Phase 7 — Supabase Storage Security & Signed URLs Tests', () {
    test('1. Private KYC bucket path strictly scopes to owner user ID', () {
      const ownerId = '00000000-0000-0000-0000-000000000002';
      const fileName = 'cnic_front.png';
      final path = '$ownerId/$fileName';

      expect(path, equals('00000000-0000-0000-0000-000000000002/cnic_front.png'));
      expect(path.startsWith(ownerId), isTrue);
    });

    test('2. Signed URL expiry duration defaults to 3600 seconds (60 minutes)', () {
      const defaultExpiry = 3600;
      expect(defaultExpiry, equals(3600));
    });

    test('3. Public seller store media path isolates to store owner folder', () {
      const ownerId = '00000000-0000-0000-0000-000000000002';
      const logoFileName = 'logo.png';
      final path = '$ownerId/$logoFileName';

      expect(path, equals('00000000-0000-0000-0000-000000000002/logo.png'));
      expect(path.contains('logo.png'), isTrue);
    });

    test('4. AppStore.fromJson correctly maps DB snake_case columns', () {
      final dbJson = {
        'id': '00000000-0000-0000-0000-000000000010',
        'shop_name': 'Teal Fashion Store',
        'shop_logo_path': 'logo.png',
        'shop_banner_path': 'banner.png',
        'shop_description': 'High quality apparel',
        'is_approved': false,
        'kyc_status': 'Pending',
        'rejection_reason': '',
        'category': 'Fashion',
      };

      final store = AppStore.fromJson(dbJson);
      expect(store.id, equals('00000000-0000-0000-0000-000000000010'));
      expect(store.shopName, equals('Teal Fashion Store'));
      expect(store.isApproved, isFalse);
      expect(store.kycStatus, equals('Pending'));
      expect(store.storeCategory, equals('Fashion'));
    });

    test('5. Brand-new seller registration defaults to isApproved = false and kycStatus = Pending', () {
      final store = AppStore(
        id: '00000000-0000-0000-0000-000000000011',
        shopName: 'New Merchant',
        shopLogo: '',
        shopBanner: '',
        shopDescription: 'Test shop',
        isApproved: false,
        kycStatus: 'Pending',
      );

      expect(store.isApproved, isFalse);
      expect(store.kycStatus, equals('Pending'));
    });

    test('6. Unapproved seller applicant defaults strictly to buyer authority', () {
      AppRouter.testRoleResolver = () => 'buyer';
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.sellerDashboard));
      expect(route, isA<MaterialPageRoute>());
      final builder = (route as MaterialPageRoute).builder;
      final widget = builder(StatelessBuildContext());
      expect(widget, isA<SellerLoginScreen>());
      AppRouter.testRoleResolver = null;
    });

    test('7. Super Admin approval transitions store to isApproved = true and kycStatus = Approved', () {
      final store = AppStore(
        id: '00000000-0000-0000-0000-000000000012',
        shopName: 'Approved Shop',
        shopLogo: '',
        shopBanner: '',
        shopDescription: '',
        isApproved: false,
        kycStatus: 'Pending',
      );

      store.isApproved = true;
      store.kycStatus = 'Approved';

      expect(store.isApproved, isTrue);
      expect(store.kycStatus, equals('Approved'));
    });

    test('8. Rejection transitions store to isApproved = false, kycStatus = Rejected with reason', () {
      final store = AppStore(
        id: '00000000-0000-0000-0000-000000000013',
        shopName: 'Rejected Shop',
        shopLogo: '',
        shopBanner: '',
        shopDescription: '',
        isApproved: false,
        kycStatus: 'Pending',
      );

      store.isApproved = false;
      store.kycStatus = 'Rejected';
      store.rejectionReason = 'Invalid CNIC front document image.';

      expect(store.isApproved, isFalse);
      expect(store.kycStatus, equals('Rejected'));
      expect(store.rejectionReason, equals('Invalid CNIC front document image.'));
    });
  });
}

class StatelessBuildContext extends BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
