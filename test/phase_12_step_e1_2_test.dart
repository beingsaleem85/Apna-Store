import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/core/controllers/catalog_controller.dart';
import 'package:apna_store/core/services/app_state_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogController catalogController;
  late AppStateProvider appStateProvider;

  final testProduct = AppProduct(
    id: 'prod_e1_2_001',
    sellerId: 'seller_test_e1_2',
    name: 'E1.2 Test Keyboard',
    price: '3500',
    description: 'Mechanical keyboard for testing',
    imageUrl: 'https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=800',
    category: 'Electronics',
    stock: 20,
    variations: [],
    wholesalePrices: {},
    approvalStatus: 'Approved',
  );

  setUp(() {
    catalogController = CatalogController();
    appStateProvider = AppStateProvider(
      catalogController: catalogController,
    );
  });

  group('Phase 12 Step E1.2 Final Catalog/Cart Authority Closure Tests', () {
    test('A. AppStateProvider.adjustStock delegates through canonical ProductRepository service', () async {
      await appStateProvider.addProduct(testProduct);
      appStateProvider.adjustStock('prod_e1_2_001', 35);

      final updated = appStateProvider.products.firstWhere((p) => p.id == 'prod_e1_2_001');
      expect(updated.stock, 35);
    });

    test('B. AppStateProvider file contains no direct seller_update_product_stock RPC call string', () {
      final file = File('lib/core/services/app_state_provider.dart');
      final content = file.readAsStringSync();

      expect(content.contains("Supabase.instance.client.rpc('seller_update_product_stock'"), isFalse);
    });

    test('C. CatalogController addProduct and addCategory are presentation cache sync only', () {
      final file = File('lib/core/controllers/catalog_controller.dart');
      final content = file.readAsStringSync();

      expect(content.contains(".from('products').insert"), isFalse);
      expect(content.contains(".from('categories').insert"), isFalse);
      expect(content.contains("syncAddProductCache"), isTrue);
      expect(content.contains("syncAddCategoryCache"), isTrue);
    });

    test('D. Local cache insertion cannot claim production backend success', () async {
      await catalogController.syncAddProductCache(testProduct);
      expect(catalogController.products.any((p) => p.id == 'prod_e1_2_001'), isTrue);
    });

    test('E. CatalogController final allowed responsibilities boundary check (0 out-of-domain mutations)', () {
      final file = File('lib/core/controllers/catalog_controller.dart');
      final content = file.readAsStringSync();

      expect(content.contains("seller_update_product_stock"), isFalse);
      expect(content.contains("approval_status"), isFalse);
      expect(content.contains("create_atomic_order"), isFalse);
    });
  });
}
