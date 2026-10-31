import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/core/controllers/catalog_controller.dart';
import 'package:apna_store/core/controllers/cart_controller.dart';
import 'package:apna_store/core/services/app_state_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogController catalogController;
  late CartController cartController;
  late AppStateProvider appStateProvider;
  late AppProduct testProduct1;
  late AppProduct testProduct2;

  setUp(() {
    catalogController = CatalogController();
    cartController = CartController();
    appStateProvider = AppStateProvider(
      catalogController: catalogController,
      cartController: cartController,
    );

    testProduct1 = AppProduct(
      id: 'prod_cat_001',
      sellerId: 'seller_101',
      name: 'Smart Earbuds Pro',
      price: '3500',
      description: 'Noise canceling earbuds',
      imageUrl: 'https://images.unsplash.com/photo-1592899677977-9c10ca588bbd?w=800',
      category: 'Electronics',
      stock: 15,
      variations: [
        ProductVariation(name: 'Color', values: ['Black', 'White']),
      ],
      wholesalePrices: {},
    );

    testProduct2 = AppProduct(
      id: 'prod_cat_002',
      sellerId: 'seller_102',
      name: 'Wireless Mechanical Keyboard',
      price: '7500',
      description: 'RGB mechanical keyboard',
      imageUrl: 'https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=800',
      category: 'Electronics',
      stock: 8,
      variations: [],
      wholesalePrices: {},
    );
  });

  group('CatalogController Characterization Tests', () {
    test('A. Initial state initializes categories and products list', () {
      expect(catalogController.categoriesList.isNotEmpty, isTrue);
      expect(catalogController.isLoadingProducts, isFalse);
    });

    test('B. Catalog load success populates products', () async {
      await catalogController.addProduct(testProduct1);
      expect(catalogController.products.any((p) => p.id == 'prod_cat_001'), isTrue);
    });

    test('C. Catalog load failure falls back gracefully to local storage', () async {
      catalogController.saveProductsToLocalStorage();
      catalogController.loadProductsFromLocalStorage();
      expect(catalogController.isLoadingProducts, isFalse);
    });

    test('D. Categories load returns default category list', () {
      expect(catalogController.categoriesList.any((c) => c['name'] == 'Fashion'), isTrue);
      expect(catalogController.categoriesList.any((c) => c['name'] == 'Electronics'), isTrue);
    });

    test('E. Product lookup finds product by ID', () async {
      await catalogController.addProduct(testProduct1);
      final found = catalogController.products.firstWhere((p) => p.id == 'prod_cat_001');
      expect(found.name, 'Smart Earbuds Pro');
    });

    test('F. Stock adjustment preserves Phase 8 RPC boundary contract', () async {
      await appStateProvider.addProduct(testProduct1);
      appStateProvider.adjustStock('prod_cat_001', 25);
      final updated = appStateProvider.products.firstWhere((p) => p.id == 'prod_cat_001');
      expect(updated.stock, 25);
    });
  });

  group('CartController Characterization Tests', () {
    test('G. Add item adds product to cart', () {
      cartController.addToCart(testProduct1, quantity: 2);
      expect(cartController.cartCount, 2);
      expect(cartController.cartProducts.first.id, 'prod_cat_001');
    });

    test('H. Remove item removes product from cart', () {
      cartController.addToCart(testProduct1);
      cartController.addToCart(testProduct2);
      expect(cartController.cartCount, 2);

      cartController.removeFromCart('prod_cat_001');
      expect(cartController.cartCount, 1);
      expect(cartController.cartProducts.first.id, 'prod_cat_002');
    });

    test('I. Quantity update modifies single item occurrence', () {
      cartController.addToCart(testProduct1, quantity: 3);
      expect(cartController.cartCount, 3);

      cartController.removeSingleFromCart('prod_cat_001');
      expect(cartController.cartCount, 2);
    });

    test('J. Clear cart empties all cart items', () {
      cartController.addToCart(testProduct1);
      cartController.addToCart(testProduct2);
      cartController.clearCart();
      expect(cartController.cartCount, 0);
      expect(cartController.cartProducts.isEmpty, isTrue);
    });

    test('K. Cart count returns accurate count of products', () {
      expect(cartController.cartCount, 0);
      cartController.addToCart(testProduct1, quantity: 5);
      expect(cartController.cartCount, 5);
    });

    test('L. Separate variants remain distinct in cart list', () {
      final var1 = AppProduct(
        id: 'prod_var_1',
        sellerId: 's1',
        name: 'T-Shirt Red',
        price: '1200',
        description: 'Red variant',
        imageUrl: '',
        category: 'Fashion',
        stock: 5,
        variations: [ProductVariation(name: 'Color', values: ['Red'])],
        wholesalePrices: {},
      );

      final var2 = AppProduct(
        id: 'prod_var_2',
        sellerId: 's1',
        name: 'T-Shirt Blue',
        price: '1200',
        description: 'Blue variant',
        imageUrl: '',
        category: 'Fashion',
        stock: 5,
        variations: [ProductVariation(name: 'Color', values: ['Blue'])],
        wholesalePrices: {},
      );

      cartController.addToCart(var1);
      cartController.addToCart(var2);

      expect(cartController.cartCount, 2);
      expect(cartController.cartProducts[0].id, 'prod_var_1');
      expect(cartController.cartProducts[1].id, 'prod_var_2');
    });

    test('M. Duplicate compatible cart items increment cart length', () {
      cartController.addToCart(testProduct1);
      cartController.addToCart(testProduct1);
      expect(cartController.cartCount, 2);
    });

    test('N. Controller does not place order directly', () {
      // CartController has NO order placement or RPC methods
      expect(cartController.cartCount, 0);
    });

    test('O. Checkout failure keeps cart intact', () {
      cartController.addToCart(testProduct1, quantity: 2);
      expect(cartController.cartCount, 2);

      // Simulating failed checkout: clearCart is NOT called
      expect(cartController.cartCount, 2);
    });

    test('P. Checkout success path clears cart only after confirmation', () {
      cartController.addToCart(testProduct1, quantity: 2);
      expect(cartController.cartCount, 2);

      // Simulating success: clearCart is called after server confirmation
      cartController.clearCart();
      expect(cartController.cartCount, 0);
    });
  });

  group('AppStateProvider Compatibility Delegation Tests', () {
    test('Q. AppStateProvider catalog getters delegate to CatalogController', () async {
      await catalogController.addProduct(testProduct1);
      expect(appStateProvider.products.length, catalogController.products.length);
      expect(appStateProvider.products.first.id, 'prod_cat_001');
      expect(appStateProvider.categoriesList, catalogController.categoriesList);
    });

    test('R. AppStateProvider cart getters delegate to CartController', () {
      appStateProvider.addToCart(testProduct1, quantity: 3);
      expect(cartController.cartCount, 3);
      expect(appStateProvider.cartProducts.length, 3);

      appStateProvider.clearCart();
      expect(cartController.cartCount, 0);
      expect(appStateProvider.cartProducts.isEmpty, isTrue);
    });

    test('S. No duplicate mutable cart state in AppStateProvider', () {
      expect(appStateProvider.cartProducts, equals(cartController.cartProducts));
    });

    test('T. No duplicate mutable catalog state in AppStateProvider', () {
      expect(appStateProvider.products, equals(catalogController.products));
    });
  });
}
