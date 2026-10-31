import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/core/config/feature_flags.dart';
import 'package:apna_store/features/buyer/widgets/checkout/checkout_payment_selector.dart';

void main() {
  group('Task 1 — Interim Payment Safety Guard Tests', () {
    test('1. onlinePaymentsEnabled feature flag is false by default', () {
      expect(FeatureFlags.onlinePaymentsEnabled, isFalse);
    });

    testWidgets('2. CheckoutPaymentSelector enables COD and disables online payment options with Coming Soon chip',
        (tester) async {
      String selected = 'COD';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CheckoutPaymentSelector(
                selectedPaymentMethod: selected,
                onPaymentMethodChanged: (val) {
                  selected = val;
                },
              ),
            ),
          ),
        ),
      );

      // Verify COD is present and enabled
      expect(find.text('Cash on Delivery (COD)'), findsOneWidget);
      expect(find.text('JazzCash Mobile Wallet'), findsOneWidget);
      expect(find.text('Easypaisa Mobile Account'), findsOneWidget);
      expect(find.text('Credit / Debit Card (Visa / MasterCard / PayPak)'), findsOneWidget);

      // When onlinePaymentsEnabled is false, 3 "Coming Soon" badges should appear
      expect(find.text('Coming Soon'), findsNWidgets(3));

      // Attempt tapping disabled JazzCash
      await tester.tap(find.text('JazzCash Mobile Wallet'));
      await tester.pumpAndSettle();

      // Selection must remain COD
      expect(selected, equals('COD'));

      // Attempt tapping disabled Easypaisa
      await tester.tap(find.text('Easypaisa Mobile Account'));
      await tester.pumpAndSettle();

      expect(selected, equals('COD'));

      // Attempt tapping disabled Card
      await tester.tap(find.text('Credit / Debit Card (Visa / MasterCard / PayPak)'));
      await tester.pumpAndSettle();

      expect(selected, equals('COD'));
    });
  });
}
