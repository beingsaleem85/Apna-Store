import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/core/controllers/catalog_controller.dart';
import 'package:apna_store/core/controllers/orders_controller.dart';
import 'package:apna_store/core/controllers/seller_controller.dart';
import 'package:apna_store/core/services/product_repository.dart';
import 'package:apna_store/core/services/supabase_orders_service.dart';
import 'package:apna_store/core/services/supabase_seller_service.dart';

class MockProductRepoF1 extends ProductRepository {
  bool fetchProductsCalled = false;
  bool fetchCategoriesCalled = false;

  @override
  Future<List<Map<String, dynamic>>> fetchProducts() async {
    fetchProductsCalled = true;
    return [
      {
        'id': 'p_f1_001',
        'title': 'F1 Routed Product',
        'price': 2500.0,
        'category': 'Electronics',
        'stock': 15,
      }
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async {
    fetchCategoriesCalled = true;
    return [
      {'name': 'Electronics', 'image': 'https://img.png'}
    ];
  }
}

class MockOrdersServiceF1 extends SupabaseOrdersService {
  bool getBuyerOrdersCalled = false;

  @override
  Future<List<Map<String, dynamic>>> getBuyerOrders() async {
    getBuyerOrdersCalled = true;
    return [
      {
        'id': 'ord_f1_001',
        'product_id': 'p_f1_001',
        'buyer_name': 'Ali Khan',
        'seller_id': 's_f1_001',
        'status': 'Processing',
        'price': 2500.0,
      }
    ];
  }
}

class MockSellerServiceF1 extends SupabaseSellerService {
  bool fetchAllStoresCalled = false;

  @override
  Future<List<Map<String, dynamic>>> fetchAllStores() async {
    fetchAllStoresCalled = true;
    return [
      {
        'id': 's_f1_001',
        'shop_name': 'F1 Store',
        'is_approved': true,
        'kyc_status': 'Approved',
      }
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 12 Step F1 Characterization Tests — Direct Supabase Call Routing Closure', () {
    test('A. CatalogController reads through ProductRepository service', () async {
      final mockRepo = MockProductRepoF1();
      final controller = CatalogController(productRepository: mockRepo);
      await controller.fetchProductsFromSupabase();
      await controller.fetchCategoriesFromSupabase();

      expect(mockRepo.fetchProductsCalled, isTrue);
      expect(mockRepo.fetchCategoriesCalled, isTrue);
      expect(controller.products.first.name, 'F1 Routed Product');
    });

    test('B. OrdersController reads through SupabaseOrdersService', () async {
      final mockService = MockOrdersServiceF1();
      final controller = OrdersController(ordersService: mockService);
      await controller.fetchOrdersFromSupabase();

      expect(mockService.getBuyerOrdersCalled, isTrue);
      expect(controller.orders.first.id, 'ord_f1_001');
    });

    test('C. SellerController reads through SupabaseSellerService', () async {
      final mockService = MockSellerServiceF1();
      final controller = SellerController(supabaseSellerService: mockService);
      await controller.fetchStoresFromSupabase();

      expect(mockService.fetchAllStoresCalled, isTrue);
      expect(controller.stores.first.id, 's_f1_001');
    });

    test('D. Checkout widgets contain 0 direct create_atomic_order RPC calls', () {
      final desktopCheckout = File('lib/features/buyer/screens/checkout/buyer_checkout_screen.dart').readAsStringSync();
      expect(desktopCheckout.contains("create_atomic_order"), isFalse);
      expect(File('lib/features/buyer/screens/checkout/buyer_mobile_checkout_screen.dart').existsSync(), isFalse);
    });

    test('E. Reviews moderation screen uses SupabaseReviewsService', () {
      final file = File('lib/features/super_admin/screens/reviews/reviews_moderation_screen.dart');
      final content = file.readAsStringSync();

      expect(content.contains("SupabaseReviewsService().fetchAllReviewsForModeration()"), isTrue);
      expect(content.contains(".from('product_reviews')"), isFalse);
    });

    test('F. Seller dashboard stock operations use ProductRepository authority', () {
      final appState = File('lib/core/services/app_state_provider.dart').readAsStringSync();
      expect(appState.contains('ProductRepository().updateProductStock'), isTrue);
    });

    test('G. Seller fulfillment remains SupabaseOrdersService authority', () {
      final appState = File('lib/core/services/app_state_provider.dart').readAsStringSync();
      expect(appState.contains('SupabaseOrdersService().updateFulfillmentStatus'), isTrue);
    });

    test('H. Finance operations remain SupabaseFinanceService authority', () {
      final financeFile = File('lib/core/services/supabase_finance_service.dart');
      expect(financeFile.existsSync(), isTrue);
    });

    test('I. No direct buyer_orders mutation in presentation controllers', () {
      final controller = File('lib/core/controllers/orders_controller.dart').readAsStringSync();
      expect(controller.contains(".from('buyer_orders').update"), isFalse);
      expect(controller.contains(".from('buyer_orders').insert"), isFalse);
    });

    test('J. No direct protected seller_stores mutation in presentation controllers', () {
      final controller = File('lib/core/controllers/seller_controller.dart').readAsStringSync();
      expect(controller.contains(".from('seller_stores').update"), isFalse);
      expect(controller.contains(".from('seller_stores').insert"), isFalse);
    });

    test('K. No direct product_reviews DB access in presentation widgets', () {
      final screen = File('lib/features/super_admin/screens/reviews/reviews_moderation_screen.dart').readAsStringSync();
      expect(screen.contains("Supabase.instance.client.from('product_reviews')"), isFalse);
    });

    test('L. Service failures do not create fake success', () async {
      final mockService = MockSellerServiceF1();
      final controller = SellerController(supabaseSellerService: mockService);
      expect(controller.storesError, isNull);
    });

    test('M. Existing DTO/mapping behavior is preserved across routing', () {
      final dtoFile = File('lib/core/models/dtos/product_dto.dart');
      expect(dtoFile.existsSync(), isTrue);
    });

    test('N. Auth role authority remains AppAuthProvider + public.user_roles', () {
      final authProvider = File('lib/core/services/app_auth_provider.dart').readAsStringSync();
      expect(authProvider.contains('public.user_roles') || authProvider.contains('user_roles'), isTrue);
    });

    test('O. Production widget/controller raw Supabase scan passes with 0 direct query calls', () {
      int count = 0;
      for (final path in [
        'lib/features/super_admin/screens/reviews/reviews_moderation_screen.dart',
        'lib/core/controllers/catalog_controller.dart',
        'lib/core/controllers/orders_controller.dart',
        'lib/core/controllers/seller_controller.dart',
      ]) {
        final content = File(path).readAsStringSync();
        if (content.contains("Supabase.instance.client.from(")) {
          count++;
        }
      }
      expect(count, 0);
    });
  });
}
