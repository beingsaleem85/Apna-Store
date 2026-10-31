import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/core/controllers/catalog_controller.dart';
import 'package:apna_store/core/models/dtos/product_dto.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/core/services/product_repository.dart';

class MockProductRepoRegression extends ProductRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchProducts() async {
    return [
      {
        'id': 'p_real_001',
        'title': 'Men Unstitched Shalwar Kameez',
        'price': 2499.0,
        'sale_price': 1999.0,
        'image_url': 'https://images.unsplash.com/photo-1583743814966-8936f5b7be1a?w=500',
        'seller_store_id': 'seller_store_001',
        'stock_quantity': 45,
        'category': 'Fashion',
        'approval_status': 'Approved',
      },
      {
        'id': 'p_real_002',
        'name': 'Wireless Bluetooth Earbuds',
        'product_price': '1899',
        'image': 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=500',
        'seller_id': 'seller_store_002',
        'stock': 30,
        'category': 'Electronics',
        'approval_status': 'Approved',
      }
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 12 Step F1 — Catalog Data Pipeline & Mapping Regression Tests', () {
    test('A. Real product name (title/name) survives repository mapping', () {
      final dbMapTitle = {
        'id': 'p_test_1',
        'title': 'Men Unstitched Shalwar Kameez',
        'price': 2499.0,
        'image_url': 'https://img.com/1.png',
      };

      final product = AppProduct.fromJson(dbMapTitle);
      final dto = ProductDto.fromDatabaseMap(dbMapTitle);

      expect(product.name, 'Men Unstitched Shalwar Kameez');
      expect(dto.name, 'Men Unstitched Shalwar Kameez');
      expect(product.name, isNot(equals('Product')));
    });

    test('B. Non-zero price (double or int) survives mapping without becoming 0', () {
      final dbMapNum = {
        'id': 'p_test_2',
        'title': 'Test Item',
        'price': 2499.0,
        'image_url': 'https://img.com/2.png',
      };

      final product = AppProduct.fromJson(dbMapNum);
      final dto = ProductDto.fromDatabaseMap(dbMapNum);

      expect(product.price, '2499');
      expect(dto.price, 2499.0);
      expect(product.price, isNot(equals('0')));
    });

    test('C. Sale price survives mapping fallback when price is missing', () {
      final dbMapSale = {
        'id': 'p_test_3',
        'name': 'Sale Item',
        'sale_price': 1499.0,
        'image_url': 'https://img.com/3.png',
      };

      final product = AppProduct.fromJson(dbMapSale);
      final dto = ProductDto.fromDatabaseMap(dbMapSale);

      expect(product.price, '1499');
      expect(dto.price, 1499.0);
    });

    test('D. Image URL (image_url/image/imageUrl) survives mapping', () {
      final dbMapImg = {
        'id': 'p_test_4',
        'title': 'Image Item',
        'price': 999.0,
        'image_url': 'https://images.unsplash.com/photo-test.jpg',
      };

      final product = AppProduct.fromJson(dbMapImg);
      final dto = ProductDto.fromDatabaseMap(dbMapImg);

      expect(product.imageUrl, 'https://images.unsplash.com/photo-test.jpg');
      expect(dto.imageUrl, 'https://images.unsplash.com/photo-test.jpg');
    });

    test('E. Stock quantity (stock_quantity/stock) survives mapping', () {
      final dbMapStock = {
        'id': 'p_test_5',
        'name': 'Stock Item',
        'price': 500.0,
        'stock_quantity': 88,
      };

      final product = AppProduct.fromJson(dbMapStock);
      final dto = ProductDto.fromDatabaseMap(dbMapStock);

      expect(product.stock, 88);
      expect(dto.stock, 88);
    });

    test('F. CatalogController receives canonical mapped values from ProductRepository', () async {
      final mockRepo = MockProductRepoRegression();
      final controller = CatalogController(productRepository: mockRepo);

      await controller.fetchProductsFromSupabase();

      expect(controller.products.length, 2);
      expect(controller.products.first.name, 'Men Unstitched Shalwar Kameez');
      expect(controller.products.first.price, '2499');
      expect(controller.products.first.imageUrl, 'https://images.unsplash.com/photo-1583743814966-8936f5b7be1a?w=500');

      expect(controller.products.last.name, 'Wireless Bluetooth Earbuds');
      expect(controller.products.last.price, '1899');
    });

    test('G. Backend fetched products replace stale local fallback cleanly', () async {
      final mockRepo = MockProductRepoRegression();
      final controller = CatalogController(productRepository: mockRepo);

      await controller.fetchProductsFromSupabase();
      expect(controller.products.every((p) => p.name != 'Product' && p.price != '0'), isTrue);
    });

    test('H. Loaded valid product never becomes generic "Product" or Rs. 0 due to mapping', () {
      final rawDbRecord = {
        'id': 'p_db_99',
        'title': 'Women Embroidered Lawn Suit',
        'price': 3499.0,
        'image_url': 'https://images.unsplash.com/photo-lawn.jpg',
        'seller_store_id': 'seller_3',
        'stock_quantity': 12,
        'category': 'Fashion',
      };

      final product = AppProduct.fromJson(rawDbRecord);

      expect(product.name, 'Women Embroidered Lawn Suit');
      expect(product.price, '3499');
      expect(product.imageUrl, 'https://images.unsplash.com/photo-lawn.jpg');
      expect(product.sellerId, 'seller_3');
      expect(product.stock, 12);
    });
  });
}
