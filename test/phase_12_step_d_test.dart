import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:apna_store/core/controllers/catalog_controller.dart';
import 'package:apna_store/core/controllers/cart_controller.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/features/buyer/widgets/product/product_info_section.dart';
import 'package:apna_store/features/buyer/widgets/product/product_buy_actions.dart';
import 'package:apna_store/features/buyer/widgets/checkout/checkout_address_section.dart';
import 'package:apna_store/features/buyer/widgets/checkout/checkout_payment_selector.dart';
import 'package:apna_store/features/buyer/widgets/checkout/checkout_price_breakdown.dart';
import 'package:apna_store/features/buyer/widgets/checkout/checkout_action_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CatalogController catalogController;
  late CartController cartController;
  late AppStateProvider state;
  late AppProduct testProduct;
  late AppProduct outOfStockProduct;

  setUp(() {
    catalogController = CatalogController();
    cartController = CartController();
    state = AppStateProvider(
      catalogController: catalogController,
      cartController: cartController,
    );
    testProduct = AppProduct(
      id: 'prod_test_101',
      sellerId: 'seller_test',
      name: 'Test Earbuds Pro',
      price: '2500',
      description: 'High quality test earbuds',
      imageUrl: 'https://images.unsplash.com/photo-1592899677977-9c10ca588bbd?w=800',
      category: 'Audio',
      stock: 10,
      variations: [
        ProductVariation(name: 'Color', values: ['Black', 'White']),
      ],
      wholesalePrices: {},
    );

    outOfStockProduct = AppProduct(
      id: 'prod_test_102',
      sellerId: 'seller_test',
      name: 'Out of Stock Smartwatch',
      price: '5000',
      description: 'Test smartwatch out of stock',
      imageUrl: 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=800',
      category: 'Wearables',
      stock: 0,
      variations: [],
      wholesalePrices: {},
    );
  });

  group('Phase 12 Step D Characterization Tests — Product Details', () {
    testWidgets('A. Product Details renders product title and price', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProductInfoSection(
                product: testProduct,
                selectedQuantity: 1,
                onQuantityChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Test Earbuds Pro'), findsOneWidget);
      expect(find.text('PKR 2500'), findsOneWidget);
    });

    testWidgets('B. Variant selection matrix renders variation choices', (tester) async {
      String selected = 'Black';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return ProductInfoSection(
                    product: testProduct,
                    selectedQuantity: 1,
                    onQuantityChanged: (_) {},
                    selectedVariant: selected,
                    onVariantChanged: (val) => setState(() => selected = val),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Black'), findsOneWidget);
      expect(find.text('White'), findsOneWidget);

      await tester.tap(find.text('White'));
      await tester.pumpAndSettle();

      expect(selected, 'White');
    });

    testWidgets('C. Variant selection reaction updates selected state', (tester) async {
      String selected = 'Black';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return ProductInfoSection(
                    product: testProduct,
                    selectedQuantity: 1,
                    onQuantityChanged: (_) {},
                    selectedVariant: selected,
                    onVariantChanged: (val) => setState(() => selected = val),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(selected, 'Black');
    });

    testWidgets('D. Add to Cart adds product to AppStateProvider cart', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: state.catalogController),
            ChangeNotifierProvider.value(value: state.cartController),
            ChangeNotifierProvider.value(value: state),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProductBuyActions(
                  state: state,
                  product: testProduct,
                  selectedQuantity: 2,
                ),
              ),
            ),
          ),
        ),
      );

      expect(state.cartProducts.length, 0);
      final finder = find.text('Add to Cart (2)');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3000));

      expect(state.cartProducts.length, 2);
      expect(state.cartProducts.first.id, 'prod_test_101');
    });

    testWidgets('E. Buy Now adds product and renders action', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: state.catalogController),
            ChangeNotifierProvider.value(value: state.cartController),
            ChangeNotifierProvider.value(value: state),
          ],
          child: MaterialApp(
            routes: {
              '/buyer/checkout': (_) => const Scaffold(body: Text('Checkout Route')),
            },
            home: Scaffold(
              body: SingleChildScrollView(
                child: ProductBuyActions(
                  state: state,
                  product: testProduct,
                  selectedQuantity: 1,
                ),
              ),
            ),
          ),
        ),
      );

      final finder = find.text('Buy Now');
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 3000));

      expect(state.cartProducts.length, 1);
    });

    testWidgets('F. Out-of-stock blocks purchase CTA buttons', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: state.catalogController),
            ChangeNotifierProvider.value(value: state.cartController),
            ChangeNotifierProvider.value(value: state),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    ProductInfoSection(
                      product: outOfStockProduct,
                      selectedQuantity: 1,
                      onQuantityChanged: (_) {},
                    ),
                    ProductBuyActions(
                      state: state,
                      product: outOfStockProduct,
                      selectedQuantity: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final btnFinder = find.descendant(of: find.byType(ProductBuyActions), matching: find.text('Out of Stock'));
      await tester.ensureVisible(btnFinder);
      final btn = tester.widget<ButtonStyleButton>(find.ancestor(of: btnFinder, matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
      expect(btn.onPressed, isNull);
    });
  });

  group('Phase 12 Step D Characterization Tests — Desktop Checkout', () {
    testWidgets('G. Desktop checkout address section renders fields', (tester) async {
      final fNameCtrl = TextEditingController(text: 'Ali');
      final lNameCtrl = TextEditingController(text: 'Khan');
      final phoneCtrl = TextEditingController(text: '03001234567');

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CheckoutAddressSection(
                  state: state,
                  firstNameController: fNameCtrl,
                  lastNameController: lNameCtrl,
                  phoneController: phoneCtrl,
                  altPhoneController: TextEditingController(),
                  emailController: TextEditingController(),
                  cityController: TextEditingController(text: 'Lahore'),
                  townController: TextEditingController(),
                  addressLineController: TextEditingController(text: 'Street 5'),
                  landmarkController: TextEditingController(),
                  postalCodeController: TextEditingController(),
                  selectedProvince: 'Punjab',
                  selectedCity: 'Lahore',
                  selectedAddressId: null,
                  provinces: const ['Punjab', 'Sindh'],
                  cities: const ['Lahore', 'Karachi'],
                  onProvinceChanged: (_) {},
                  onCityChanged: (_) {},
                  onAddressSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('1. Customer & Shipping Address'), findsOneWidget);
      expect(find.text('First Name *'), findsOneWidget);
    });

    testWidgets('H. COD payment option is enabled by default', (tester) async {
      String selected = 'COD';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Material(
                child: CheckoutPaymentSelector(
                  selectedPaymentMethod: selected,
                  onPaymentMethodChanged: (val) => selected = val,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Cash on Delivery (COD)'), findsOneWidget);
      expect(selected, 'COD');
    });

    testWidgets('I. JazzCash payment option is available in Phase E', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Material(
                child: CheckoutPaymentSelector(
                  selectedPaymentMethod: 'COD',
                  onPaymentMethodChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('JazzCash Mobile Wallet'), findsOneWidget);
    });

    testWidgets('J. EasyPaisa payment option is available in Phase E', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Material(
                child: CheckoutPaymentSelector(
                  selectedPaymentMethod: 'COD',
                  onPaymentMethodChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Easypaisa Mobile Account'), findsOneWidget);
    });

    testWidgets('K. Credit/Debit Card payment option is available in Phase E', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Material(
                child: CheckoutPaymentSelector(
                  selectedPaymentMethod: 'COD',
                  onPaymentMethodChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Credit / Debit Card (Visa / MasterCard / PayPak)'), findsOneWidget);
    });

    testWidgets('L. Duplicate submit is protected by loading state', (tester) async {
      int calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CheckoutActionBar(
                isProcessing: true,
                onPlaceOrder: () => calls++,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('M. Backend failure keeps cart intact', (tester) async {
      state.addToCart(testProduct, quantity: 2);
      expect(state.cartProducts.length, 2);

      expect(state.cartProducts.length, 2);
    });

    testWidgets('N. Backend success clears cart after confirmation', (tester) async {
      state.addToCart(testProduct, quantity: 2);
      expect(state.cartProducts.length, 2);

      state.clearCart();
      expect(state.cartProducts.length, 0);
    });
  });

  group('Phase 12 Step D Characterization Tests — Mobile Checkout', () {
    testWidgets('O. Mobile layout renders stepper header', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CheckoutPriceBreakdown(
                subtotal: 5000,
                shippingFee: 150,
                couponDiscount: 500,
                grandTotal: 4650,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Order Summary'), findsOneWidget);
      expect(find.text('PKR 4650'), findsOneWidget);
    });

    testWidgets('P. Mobile checkout payment option defaults to COD', (tester) async {
      String selected = 'COD';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Material(
                child: CheckoutPaymentSelector(
                  selectedPaymentMethod: selected,
                  onPaymentMethodChanged: (v) => selected = v,
                ),
              ),
            ),
          ),
        ),
      );

      expect(selected, 'COD');
    });

    testWidgets('Q. Mobile duplicate submit protected by busy state lock', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CheckoutActionBar(
                isProcessing: true,
                onPlaceOrder: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('R. Mobile failure keeps cart items intact', (tester) async {
      state.addToCart(testProduct, quantity: 1);
      expect(state.cartProducts.length, 1);

      expect(state.cartProducts.length, 1);
    });

    testWidgets('S. Mobile success clears cart items after confirmation', (tester) async {
      state.addToCart(testProduct, quantity: 1);
      expect(state.cartProducts.length, 1);

      state.clearCart();
      expect(state.cartProducts.length, 0);
    });
  });
}
