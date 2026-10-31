import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/core/constants/app_breakpoints.dart';
import 'package:apna_store/core/routes/app_routes.dart';
import 'package:apna_store/core/routes/app_router.dart';
import 'package:apna_store/core/widgets/safe_network_image.dart';
import 'package:apna_store/core/widgets/app_footer.dart';
import 'package:apna_store/features/seller/screens/onboarding/seller_kyc_onboarding_screen.dart';

void main() {
  group('Phase D — UX, Responsiveness, Performance & Cleanup Tests', () {
    test('1. Verify 11 duplicate mobile screens and dead files are removed from codebase', () {
      final deletedPaths = [
        'lib/features/buyer/screens/auth/buyer_mobile_sign_in_screen.dart',
        'lib/features/buyer/screens/auth/buyer_mobile_otp_screen.dart',
        'lib/features/buyer/screens/home/buyer_mobile_home_screen.dart',
        'lib/features/buyer/screens/category/buyer_mobile_categories_screen.dart',
        'lib/features/buyer/screens/product/buyer_mobile_product_details_screen.dart',
        'lib/features/buyer/screens/cart/buyer_mobile_cart_screen.dart',
        'lib/features/buyer/screens/checkout/buyer_mobile_checkout_screen.dart',
        'lib/features/buyer/screens/checkout/buyer_mobile_order_success_screen.dart',
        'lib/features/buyer/screens/orders/buyer_mobile_order_history_screen.dart',
        'lib/features/buyer/screens/orders/buyer_mobile_order_tracking_screen.dart',
        'lib/features/buyer/screens/profile/buyer_mobile_account_screen.dart',
        'lib/core/models/product.dart',
        'lib/core/repositories/order_repository.dart',
        'lib/core/repositories/seller_repository.dart',
        'lib/features/buyer/screens/product/buyer_product_details_screen.dart',
        'lib/features/super_admin/core/widgets/admin_data_table.dart',
      ];

      for (final path in deletedPaths) {
        final file = File(path);
        expect(file.existsSync(), isFalse, reason: '$path should be deleted');
      }
    });

    testWidgets('2. AppBreakpoints.getResponsiveDialogWidth adapts across mobile and desktop viewports', (WidgetTester tester) async {
      late BuildContext testContext;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(320, 640)), // Small mobile
            child: Builder(
              builder: (context) {
                testContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      final widthAt320 = AppBreakpoints.getResponsiveDialogWidth(testContext, defaultDesktopWidth: 600);
      expect(widthAt320, lessThanOrEqualTo(320.0));
      expect(widthAt320, 288.0); // 320 - 32 = 288

      // Desktop test
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1440, 900)), // Desktop
            child: Builder(
              builder: (context) {
                testContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      final widthAt1440 = AppBreakpoints.getResponsiveDialogWidth(testContext, defaultDesktopWidth: 600);
      expect(widthAt1440, 600.0);
    });

    testWidgets('3. SafeNetworkImage handles null or empty URLs gracefully without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SafeNetworkImage(
              imageUrl: '',
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });

    testWidgets('4. Seller KYC onboarding blocks submission if policy is not accepted', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: SellerKycOnboardingScreen(),
        ),
      );

      // Advance through stepper to final step
      for (int i = 0; i < 3; i++) {
        final continueFinder = find.text('Continue').at(i);
        await tester.ensureVisible(continueFinder);
        await tester.tap(continueFinder);
        await tester.pumpAndSettle();
      }

      // Step 4 is active, attempt continue without checking policy
      final step4Continue = find.text('Continue').at(3);
      await tester.ensureVisible(step4Continue);
      await tester.tap(step4Continue);
      await tester.pumpAndSettle();

      expect(find.text('Please accept the Marketplace Seller Policy to submit your KYC application.'), findsOneWidget);

      // Accept policy and retry
      final checkbox = find.byType(CheckboxListTile);
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      await tester.ensureVisible(step4Continue);
      await tester.tap(step4Continue);
      await tester.pumpAndSettle();

      expect(find.text('KYC Verification Documents Submitted for Review!'), findsOneWidget);
    });

    testWidgets('5. AppFooter renders and shows modal on policy link tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: AppFooter()),
          ),
        ),
      );

      expect(find.text('Quick Links'), findsOneWidget);
      expect(find.text('© 2026 Apna Store. All Rights Reserved.'), findsOneWidget);

      // Tap Privacy Policy
      final privacyPolicyFinder = find.text('Privacy Policy').first;
      await tester.ensureVisible(privacyPolicyFinder);
      await tester.tap(privacyPolicyFinder);
      await tester.pumpAndSettle();

      expect(find.text('Apna Store respects your privacy. All customer data, KYC documents, and financial records are encrypted and protected under strict role-based access control and Pakistan data protection regulations.'), findsOneWidget);
    });
  });
}
