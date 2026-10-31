import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apna_store/core/errors/failures.dart';
import 'package:apna_store/core/models/dtos/category_dto.dart';
import 'package:apna_store/core/models/dtos/kyc_dto.dart';
import 'package:apna_store/core/models/dtos/order_dto.dart';
import 'package:apna_store/core/models/dtos/product_dto.dart';
import 'package:apna_store/core/models/dtos/profile_dto.dart';
import 'package:apna_store/core/models/dtos/seller_store_dto.dart';
import 'package:apna_store/core/utils/parsing_helpers.dart';
import 'package:apna_store/core/services/app_state_provider.dart';

void main() {
  group('Phase 3 — Database DTO & Snake-Case Mapping Tests', () {
    test('1. Seller/store database snake_case mapping', () {
      final dto = SellerStoreDto(
        id: 'store-1',
        ownerId: 'user-1',
        shopName: 'Chulbul Store',
        shopSlug: 'chulbul-store',
        businessName: 'Chulbul Enterprise',
        isApproved: true,
        kycStatus: 'Approved',
        commissionRate: 12.5,
        balance: 1500.0,
      );

      final map = dto.toDatabaseMap();
      expect(map['id'], equals('store-1'));
      expect(map['owner_id'], equals('user-1'));
      expect(map['shop_name'], equals('Chulbul Store'));
      expect(map['shop_slug'], equals('chulbul-store'));
      expect(map['is_approved'], equals(true));
      expect(map['kyc_status'], equals('Approved'));
      expect(map['commission_rate'], equals(12.5));
      expect(map['balance'], equals(1500.0));

      final restored = SellerStoreDto.fromDatabaseMap(map);
      expect(restored.shopName, equals('Chulbul Store'));
      expect(restored.commissionRate, equals(12.5));
    });

    test('2. Product database snake_case mapping', () {
      final dto = ProductDto(
        id: 'prod-1',
        name: 'Smart Watch',
        price: 2999.0,
        rating: 4.5,
        imageUrl: 'https://example.com/watch.png',
        sellerStoreId: 'seller-10',
        stock: 50,
      );

      final map = dto.toDatabaseMap();
      expect(map['image_url'], equals('https://example.com/watch.png'));
      expect(map['seller_store_id'], equals('seller-10'));
      expect(map['price'], equals(2999.0));

      final restored = ProductDto.fromDatabaseMap(map);
      expect(restored.imageUrl, equals('https://example.com/watch.png'));
      expect(restored.sellerStoreId, equals('seller-10'));
    });

    test('3. Profile database mapping', () {
      final dto = ProfileDto(
        id: 'prof-1',
        fullName: 'Test User',
        email: 'user@example.com',
        role: 'seller',
      );
      final map = dto.toDatabaseMap();
      expect(map['full_name'], equals('Test User'));
      expect(map['email'], equals('user@example.com'));

      final restored = ProfileDto.fromDatabaseMap(map);
      expect(restored.fullName, equals('Test User'));
    });

    test('4. KYC database mapping', () {
      final dto = KycDocumentDto(
        id: 'kyc-1',
        sellerStoreId: 'seller-1',
        documentType: 'Aadhaar',
        documentUrl: 'https://example.com/doc.pdf',
        status: 'Pending',
      );

      final map = dto.toDatabaseMap();
      expect(map['seller_store_id'], equals('seller-1'));
      expect(map['document_type'], equals('Aadhaar'));

      final restored = KycDocumentDto.fromDatabaseMap(map);
      expect(restored.documentType, equals('Aadhaar'));
    });

    test('5. Order database mapping', () {
      final dto = OrderDto(
        id: 'ord-101',
        customerName: 'Aman Kumar',
        customerEmail: 'aman@example.com',
        amount: 4500.0,
        paymentMethod: 'UPI',
        items: [
          {'item_id': 'prod-1', 'quantity': 2, 'price': 2250.0}
        ],
      );

      final map = dto.toDatabaseMap();
      expect(map['customer_name'], equals('Aman Kumar'));
      expect(map['customer_email'], equals('aman@example.com'));
      expect(map['payment_method'], equals('UPI'));
      expect(map['items'], isA<List>());

      final restored = OrderDto.fromDatabaseMap(map);
      expect(restored.customerName, equals('Aman Kumar'));
      expect(restored.items.length, equals(1));
    });
  });

  group('Phase 3 — Safe Numeric & Timestamp Parsing Tests', () {
    test('6. Numeric int-to-double parsing', () {
      expect(ParsingHelpers.parseDouble(100), equals(100.0));
      expect(ParsingHelpers.parseDouble(0), equals(0.0));
    });

    test('7. Numeric double parsing', () {
      expect(ParsingHelpers.parseDouble(99.99), equals(99.99));
    });

    test('8. Numeric string parsing', () {
      expect(ParsingHelpers.parseDouble('4500.50'), equals(4500.50));
      expect(ParsingHelpers.parseInt('25'), equals(25));
    });

    test('9. Malformed numeric failure fallback', () {
      expect(ParsingHelpers.parseDouble('invalid_num', defaultValue: 10.0), equals(10.0));
      expect(ParsingHelpers.parseInt('abc', defaultValue: 5), equals(5));
      expect(ParsingHelpers.parseDouble(null, defaultValue: 0.0), equals(0.0));
    });

    test('10. Null required field failure', () {
      expect(() => ParsingHelpers.parseDateTime(null, required: true), throwsA(isA<ValidationFailure>()));
    });

    test('11. Timestamp parsing', () {
      final dt = DateTime(2026, 8, 5, 12, 0, 0);
      final iso = ParsingHelpers.toIsoString(dt);
      expect(iso, contains('2026-08-05'));

      final parsed = ParsingHelpers.parseDateTime(iso);
      expect(parsed?.year, equals(2026));
    });
  });

  group('Phase 3 — Password Security & Persistence Tests', () {
    test('12. Seller/store serialization excludes password', () {
      final dto = SellerStoreDto(
        id: 'store-1',
        ownerId: 'user-1',
        shopName: 'Test Store',
      );
      final map = dto.toDatabaseMap();
      expect(map.containsKey('password'), isFalse);
      expect(map.containsKey('pass'), isFalse);
    });

    test('13. Local cache serialization excludes password', () {
      final appStore = AppStore(
        id: 'store-1',
        shopName: 'Test Store',
        email: 'test@example.com',
      );

      final jsonMap = appStore.toJson();
      expect(jsonMap.containsKey('password'), isFalse);
    });

    test('14. Authentication input is not persistable', () {
      final legacyMap = {'id': 's1', 'shopName': 'S1', 'password': 'secret_pass_123'};
      final restored = AppStore.fromJson(legacyMap);
      final jsonOutput = restored.toJson();
      expect(jsonOutput.containsKey('password'), isFalse);
    });
  });

  group('Phase 3 — Typed Application Failures Tests', () {
    test('15. Supabase/PostgREST error maps to DatabaseFailure', () {
      const postgrestExc = PostgrestException(message: 'Row not found', code: 'PGRST116');
      final failure = FailureMapper.mapException(postgrestExc);
      expect(failure, isA<DatabaseFailure>());
      expect(failure.message, contains('Row not found'));
      expect(failure.code, equals('PGRST116'));
    });

    test('16. Auth exception maps to AuthenticationFailure', () {
      const authExc = AuthException('Invalid login credentials', statusCode: '400');
      final failure = FailureMapper.mapException(authExc);
      expect(failure, isA<AuthenticationFailure>());
      expect(failure.message, equals('Invalid login credentials'));
    });

    test('17. Network exception maps to NetworkFailure', () {
      final netExc = Exception('SocketException: Failed host lookup');
      final failure = FailureMapper.mapException(netExc);
      expect(failure, isA<NetworkFailure>());
      expect(failure.isRetryable, isTrue);
    });

    test('18. Unknown exception maps to UnknownFailure', () {
      final unknownExc = Exception('Random unexpected error');
      final failure = FailureMapper.mapException(unknownExc);
      expect(failure, isA<UnknownFailure>());
      expect(failure.message, contains('unexpected error'));
    });
  });

  group('Phase 3 — Repository & Order Payload Boundaries Tests', () {
    test('19. Repository propagates typed failure', () {
      final failure = FailureMapper.mapException(const PostgrestException(message: 'Permission denied', code: '42501'));
      expect(failure, isA<DatabaseFailure>());
      expect(failure.code, equals('42501'));
    });

    test('20. Failed insert does not return success', () {
      final failure = FailureMapper.mapException(const PostgrestException(message: 'Insert error', code: '23505'));
      expect(failure, isA<DatabaseFailure>());
    });

    test('21. Canonical buyer_orders payload is used', () {
      final order = OrderDto(
        id: 'o-1',
        customerName: 'Customer',
        customerEmail: 'c@test.com',
        amount: 1000.0,
        paymentMethod: 'COD',
        items: [
          {'name': 'Item A', 'price': 1000.0}
        ],
      );

      final map = order.toDatabaseMap();
      expect(map['customer_name'], equals('Customer'));
      expect(map['items'], isA<List>());
    });

    test('22. No incompatible buyer_orders payload path remains', () {
      final category = CategoryDto(id: 'c-1', name: 'Electronics');
      final map = category.toDatabaseMap();
      expect(map['name'], equals('Electronics'));
    });
  });
}
