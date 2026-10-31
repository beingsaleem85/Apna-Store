import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/core/constants/app_breakpoints.dart';
import 'package:apna_store/core/widgets/responsive_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 13 Step 2 — Responsive Breakpoint & Layout Standardization Tests', () {
    test('A. Canonical breakpoint boundaries classify viewports accurately', () {
      expect(AppBreakpoints.mobileMax, 599.0);
      expect(AppBreakpoints.tabletMin, 600.0);
      expect(AppBreakpoints.tabletMax, 899.0);
      expect(AppBreakpoints.desktopMin, 900.0);
      expect(AppBreakpoints.desktopMax, 1199.0);
      expect(AppBreakpoints.wideMin, 1200.0);
      expect(AppBreakpoints.checkoutDesktopThreshold, 850.0);
    });

    test('B. Grid column count scales cleanly across breakpoints', () {
      expect(AppBreakpoints.getGridColumnCount(400), 2);
      expect(AppBreakpoints.getGridColumnCount(700), 3);
      expect(AppBreakpoints.getGridColumnCount(1000), 4);
      expect(AppBreakpoints.getGridColumnCount(1400), 5);
    });

    testWidgets('C. ResponsiveBuilder renders mobile layout < 600 and web layout >= 600', (tester) async {
      // Mobile screen: 390x844
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveBuilder(
              mobileLayout: Text('Mobile Version'),
              webLayout: Text('Web Version'),
            ),
          ),
        ),
      );

      expect(find.text('Mobile Version'), findsOneWidget);
      expect(find.text('Web Version'), findsNothing);

      // Desktop screen: 1366x768
      tester.view.physicalSize = const Size(1366, 768);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveBuilder(
              mobileLayout: Text('Mobile Version'),
              webLayout: Text('Web Version'),
            ),
          ),
        ),
      );

      expect(find.text('Web Version'), findsOneWidget);
      expect(find.text('Mobile Version'), findsNothing);
    });

    testWidgets('D. Boundary test 599 vs 600 vs 601', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 599px
      tester.view.physicalSize = const Size(599, 800);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveBuilder(
              mobileLayout: Text('Boundary Mobile'),
              webLayout: Text('Boundary Web'),
            ),
          ),
        ),
      );
      expect(find.text('Boundary Mobile'), findsOneWidget);

      // 600px
      tester.view.physicalSize = const Size(600, 800);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveBuilder(
              mobileLayout: Text('Boundary Mobile'),
              webLayout: Text('Boundary Web'),
            ),
          ),
        ),
      );
      expect(find.text('Boundary Web'), findsOneWidget);

      // 601px
      tester.view.physicalSize = const Size(601, 800);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveBuilder(
              mobileLayout: Text('Boundary Mobile'),
              webLayout: Text('Boundary Web'),
            ),
          ),
        ),
      );
      expect(find.text('Boundary Web'), findsOneWidget);
    });

    testWidgets('E. Responsive dialog width calculation handles mobile viewports safely without overflow', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // 360px mobile
      tester.view.physicalSize = const Size(360, 800);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              final w = AppBreakpoints.getResponsiveDialogWidth(ctx, defaultDesktopWidth: 580);
              return Scaffold(
                body: Container(
                  width: w,
                  child: const Text('Responsive Dialog Content'),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Responsive Dialog Content'), findsOneWidget);

      // 1440px desktop
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              final w = AppBreakpoints.getResponsiveDialogWidth(ctx, defaultDesktopWidth: 580);
              return Scaffold(
                body: Container(
                  width: w,
                  child: const Text('Responsive Dialog Content Desktop'),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Responsive Dialog Content Desktop'), findsOneWidget);
    });

    testWidgets('F. 360x800 Mobile viewport render test without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Text('Header 360'),
                  SizedBox(height: 200),
                  Text('Footer 360'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Header 360'), findsOneWidget);
    });

    testWidgets('G. 768x1024 Tablet viewport render test without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Text('Tablet Header'),
                  SizedBox(height: 400),
                  Text('Tablet Footer'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tablet Header'), findsOneWidget);
    });

    testWidgets('H. 1366x768 Desktop viewport render test', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Desktop Layout 1366'),
          ),
        ),
      );

      expect(find.text('Desktop Layout 1366'), findsOneWidget);
    });

    testWidgets('I. 1920x1080 Wide Desktop viewport render test', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Text('Wide Desktop 1920'),
          ),
        ),
      );

      expect(find.text('Wide Desktop 1920'), findsOneWidget);
    });

    testWidgets('J. Checkout boundary test around 850px', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      tester.view.physicalSize = const Size(849, 900);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              final isDesktop = MediaQuery.of(ctx).size.width >= AppBreakpoints.checkoutDesktopThreshold;
              return Scaffold(
                body: Text(isDesktop ? 'Desktop Checkout' : 'Mobile Checkout'),
              );
            },
          ),
        ),
      );
      expect(find.text('Mobile Checkout'), findsOneWidget);

      tester.view.physicalSize = const Size(850, 900);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              final isDesktop = MediaQuery.of(ctx).size.width >= AppBreakpoints.checkoutDesktopThreshold;
              return Scaffold(
                body: Text(isDesktop ? 'Desktop Checkout' : 'Mobile Checkout'),
              );
            },
          ),
        ),
      );
      expect(find.text('Desktop Checkout'), findsOneWidget);
    });
  });
}
