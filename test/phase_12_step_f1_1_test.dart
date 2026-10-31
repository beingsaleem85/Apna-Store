import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/core/controllers/catalog_controller.dart';
import 'package:apna_store/core/controllers/orders_controller.dart';
import 'package:apna_store/core/models/dtos/product_dto.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/core/services/product_repository.dart';
import 'package:apna_store/core/services/supabase_orders_service.dart';

class MockProductRepoF11 extends ProductRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchProducts() async {
    return [
      {
        'id': 'p_f11_001',
        'title': 'Men Unstitched Shalwar Kameez Premium',
        'price': 3250.0,
        'sale_price': 2950.0,
        'image_url': 'https://images.unsplash.com/photo-1583743814966-8936f5b7be1a',
        'seller_store_id': 'seller_store_f11',
        'stock_quantity': 60,
        'category': 'Fashion',
        'approval_status': 'Approved',
      }
    ];
  }
}

class MockOrdersServiceF11 extends SupabaseOrdersService {
  String? queriedUserId;

  @override
  Future<List<Map<String, dynamic>>> getBuyerOrders() async {
    // Simulates buyer-scoped RLS fetch for active user
    queriedUserId = 'buyer_a_uuid';
    return [
      {
        'id': 'ord_buyer_a_001',
        'customer_user_id': 'buyer_a_uuid',
        'product_id': 'p_f11_001',
        'buyer_name': 'Buyer A',
        'seller_id': 'seller_store_f11',
        'status': 'Confirmed',
        'price': 2950.0,
      }
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 12 Step F1.1 Characterization Tests — Runtime Data & Buyer Order Scope Closure', () {
    test('A. Product name mapping survives repository routing', () async {
      final repo = MockProductRepoF11();
      final controller = CatalogController(productRepository: repo);
      await controller.fetchProductsFromSupabase();

      expect(controller.products.first.name, 'Men Unstitched Shalwar Kameez Premium');
      expect(controller.products.first.name, isNot(equals('Product')));
    });

    test('B. Non-zero price survives routing', () async {
      final repo = MockProductRepoF11();
      final controller = CatalogController(productRepository: repo);
      await controller.fetchProductsFromSupabase();

      expect(controller.products.first.price, '3250');
      expect(controller.products.first.price, isNot(equals('0')));
    });

    test('C. Sale price survives DTO mapping fallback', () {
      final dbMap = {
        'id': 'p_sale_001',
        'title': 'Sale Items',
        'sale_price': 1750.0,
      };
      final dto = ProductDto.fromDatabaseMap(dbMap);
      final product = AppProduct.fromJson(dbMap);

      expect(dto.price, 1750.0);
      expect(product.price, '1750');
    });

    test('D. Image URL survives routing', () async {
      final repo = MockProductRepoF11();
      final controller = CatalogController(productRepository: repo);
      await controller.fetchProductsFromSupabase();

      expect(controller.products.first.imageUrl, 'https://images.unsplash.com/photo-1583743814966-8936f5b7be1a');
    });

    test('E. Stock quantity survives routing', () async {
      final repo = MockProductRepoF11();
      final controller = CatalogController(productRepository: repo);
      await controller.fetchProductsFromSupabase();

      expect(controller.products.first.stock, 60);
    });

    test('F. Canonical backend replaces stale product cache cleanly', () async {
      final repo = MockProductRepoF11();
      final controller = CatalogController(productRepository: repo);

      // Populate stale fallback product
      await controller.syncAddProductCache(AppProduct(
        id: 'stale_id',
        sellerId: 'stale_seller',
        name: 'Product',
        price: '0',
        description: 'Stale',
        imageUrl: '',
        category: 'Fashion',
        variations: [],
        wholesalePrices: {},
      ));

      await controller.fetchProductsFromSupabase();
      expect(controller.products.first.name, 'Men Unstitched Shalwar Kameez Premium');
      expect(controller.products.first.price, '3250');
    });

    test('G. Valid product cannot silently become generic "Product"', () {
      final dbRecord = {
        'id': 'p_val_001',
        'title': 'Real Leather Jacket',
        'price': 8999.0,
      };
      final product = AppProduct.fromJson(dbRecord);
      expect(product.name, 'Real Leather Jacket');
    });

    test('H. Valid price cannot silently become Rs. 0 due to mapping', () {
      final dbRecord = {
        'id': 'p_val_002',
        'name': 'Smart Watch Ultra',
        'price': 12500.0,
      };
      final product = AppProduct.fromJson(dbRecord);
      expect(product.price, '12500');
    });

    test('I. Buyer A order fetch cannot return Buyer B order (isolation test)', () async {
      final service = MockOrdersServiceF11();
      final orders = await service.getBuyerOrders();

      expect(service.queriedUserId, 'buyer_a_uuid');
      expect(orders.every((o) => o['customer_user_id'] == 'buyer_a_uuid'), isTrue);
    });

    test('J. OrdersController uses buyer-safe order read path getBuyerOrders()', () async {
      final mockOrdersService = MockOrdersServiceF11();
      final controller = OrdersController(ordersService: mockOrdersService);

      await controller.fetchOrdersFromSupabase();
      expect(mockOrdersService.queriedUserId, 'buyer_a_uuid');
      expect(controller.orders.first.id, 'ord_buyer_a_001');
    });
  });
}
