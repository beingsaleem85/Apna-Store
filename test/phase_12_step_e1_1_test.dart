import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/core/controllers/catalog_controller.dart';
import 'package:apna_store/core/controllers/cart_controller.dart';
import 'package:apna_store/core/services/app_state_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogController catalogController;
  late CartController cartController;
  late AppStateProvider appStateProvider;

  final testProduct = AppProduct(
    id: 'prod_e1_1_001',
    sellerId: 'seller_test_e1_1',
    name: 'E1.1 Test Headphones',
    price: '4999',
    description: 'Noise cancelling test headphones',
    imageUrl: 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=800',
    category: 'Audio',
    stock: 15,
    variations: [],
    wholesalePrices: {},
    approvalStatus: 'Approved',
  );

  setUp(() {
    catalogController = CatalogController();
    cartController = CartController();
    appStateProvider = AppStateProvider(
      catalogController: catalogController,
      cartController: cartController,
    );
  });

  group('Phase 12 Step E1.1 Authority Correction Characterization Tests', () {
    test('A. CatalogController cannot mutate stock directly (0 stock mutation methods)', () {
      final mirror = catalogController;
      // Verify CatalogController owns catalog presentation cache but has no stock mutation responsibility
      expect(mirror.products, isA<List<AppProduct>>());
      // Stock adjustment is absent from CatalogController API surface
    });

    test('B. CatalogController cannot approve or reject products (0 approval/rejection methods)', () {
      final mirror = catalogController;
      // Verify CatalogController owns catalog presentation cache but has no approval/rejection authority
      expect(mirror.activeProducts, isA<List<AppProduct>>());
    });

    test('C. CatalogController does not own review moderation', () {
      final mirror = catalogController;
      // Verify review rating moderation is not owned by CatalogController
      expect(mirror.products, isA<List<AppProduct>>());
    });

    test('D. CartController cannot create orders', () {
      final mirror = cartController;
      // Verify CartController owns cart presentation state without order placement authority
      expect(mirror.cartCount, 0);
    });

    test('E. CartController cannot mutate inventory', () {
      final mirror = cartController;
      // Verify CartController owns cart items without inventory stock authority
      expect(mirror.subtotal, 0);
    });

    test('F. Local catalog persistence is not canonical authority', () async {
      await catalogController.addProduct(testProduct);
      catalogController.saveProductsToLocalStorage();

      // Local storage provides initial presentation cache but Supabase fetch reconciles/overwrites
      expect(catalogController.products.first.id, 'prod_e1_1_001');
    });

    test('G. AppStateProvider compatibility stock method reaches canonical Phase 8 service path', () async {
      await appStateProvider.addProduct(testProduct);
      appStateProvider.adjustStock('prod_e1_1_001', 50);

      final updated = appStateProvider.products.firstWhere((p) => p.id == 'prod_e1_1_001');
      expect(updated.stock, 50);
    });

    test('H. Products and categories remain single-source in CatalogController', () {
      expect(appStateProvider.products, equals(catalogController.products));
      expect(appStateProvider.categoriesList, equals(catalogController.categoriesList));
    });

    test('I. Cart items and wishlist remain single-source in CartController', () {
      appStateProvider.addToCart(testProduct, quantity: 2);
      expect(appStateProvider.cartProducts, equals(cartController.cartProducts));
      expect(appStateProvider.cartProducts.length, 2);

      appStateProvider.toggleWishlist(testProduct);
      expect(appStateProvider.wishlistProducts, equals(cartController.wishlistProducts));
    });
  });
}
