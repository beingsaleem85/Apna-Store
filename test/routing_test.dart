import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:apna_store/core/routes/app_router.dart';
import 'package:apna_store/core/routes/app_routes.dart';
import 'package:apna_store/core/routes/unknown_route_screen.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/core/services/supabase_seller_service.dart';
import 'package:apna_store/core/services/supabase_service.dart';
import 'package:apna_store/features/buyer/screens/buyer_dashboard.dart';
import 'package:apna_store/features/seller/screens/seller_auth_screens.dart';
import 'package:apna_store/features/seller/screens/seller_dashboard.dart';
import 'package:apna_store/features/super_admin/screens/admin_shell.dart';
import 'package:apna_store/features/super_admin/screens/auth/admin_login_screen.dart';
import 'package:apna_store/features/super_admin/services/super_admin_provider.dart';

Widget _createTestApp({required Widget home, RouteFactory? onGenerateRoute, String? initialRoute}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SupabaseService()),
      ChangeNotifierProvider(create: (_) => SupabaseSellerService()),
      ChangeNotifierProvider(create: (_) => AppStateProvider()),
      ChangeNotifierProvider(create: (_) => SuperAdminProvider()),
    ],
    child: MaterialApp(
      initialRoute: initialRoute,
      onGenerateRoute: onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      home: initialRoute == null ? home : null,
    ),
  );
}

void main() {
  tearDown(() {
    AppRouter.testRoleResolver = null;
  });

  group('Positive Route Authorization Tests', () {
    testWidgets('1. appMetadata role = seller resolves and renders SellerDashboard', (WidgetTester tester) async {
      AppRouter.testRoleResolver = () => 'seller';
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.sellerDashboard)) as MaterialPageRoute;
      late Widget createdWidget;
      await tester.pumpWidget(
        _createTestApp(
          home: Builder(
            builder: (context) {
              createdWidget = route.builder(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(createdWidget, isA<SellerDashboard>());
    });

    testWidgets('2. appMetadata role = admin resolves and renders SuperAdminShell', (WidgetTester tester) async {
      AppRouter.testRoleResolver = () => 'admin';
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.superAdmin)) as MaterialPageRoute;
      late Widget createdWidget;
      await tester.pumpWidget(
        _createTestApp(
          home: Builder(
            builder: (context) {
              createdWidget = route.builder(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(createdWidget, isA<SuperAdminShell>());
    });

    testWidgets('3. appMetadata role = superadmin resolves and renders SuperAdminShell', (WidgetTester tester) async {
      AppRouter.testRoleResolver = () => 'superadmin';
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.superAdmin)) as MaterialPageRoute;
      late Widget createdWidget;
      await tester.pumpWidget(
        _createTestApp(
          home: Builder(
            builder: (context) {
              createdWidget = route.builder(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(createdWidget, isA<SuperAdminShell>());
    });

    testWidgets('4. appMetadata role = super_admin resolves and renders SuperAdminShell', (WidgetTester tester) async {
      AppRouter.testRoleResolver = () => 'super_admin';
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.superAdmin)) as MaterialPageRoute;
      late Widget createdWidget;
      await tester.pumpWidget(
        _createTestApp(
          home: Builder(
            builder: (context) {
              createdWidget = route.builder(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(createdWidget, isA<SuperAdminShell>());
    });

    testWidgets('5. appMetadata role = owner resolves and renders SuperAdminShell', (WidgetTester tester) async {
      AppRouter.testRoleResolver = () => 'owner';
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.superAdmin)) as MaterialPageRoute;
      late Widget createdWidget;
      await tester.pumpWidget(
        _createTestApp(
          home: Builder(
            builder: (context) {
              createdWidget = route.builder(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(createdWidget, isA<SuperAdminShell>());
    });
  });

  group('Denial & Security Tests', () {
    testWidgets('6. userMetadata role = seller does not authorize seller route (defaults to deny)', (WidgetTester tester) async {
      AppRouter.testRoleResolver = () => null; // No appMetadata claim
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.sellerDashboard)) as MaterialPageRoute;
      late Widget createdWidget;
      await tester.pumpWidget(
        _createTestApp(
          home: Builder(
            builder: (context) {
              createdWidget = route.builder(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(createdWidget, isA<SellerLoginScreen>());
    });

    testWidgets('7. userMetadata role = admin does not authorize admin route (defaults to deny)', (WidgetTester tester) async {
      AppRouter.testRoleResolver = () => null;
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.superAdmin)) as MaterialPageRoute;
      late Widget createdWidget;
      await tester.pumpWidget(
        _createTestApp(
          home: Builder(
            builder: (context) {
              createdWidget = route.builder(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(createdWidget, isA<SuperAdminLoginScreen>());
    });

    testWidgets('8. appMetadata role = buyer denies seller routes', (WidgetTester tester) async {
      AppRouter.testRoleResolver = () => 'buyer';
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.sellerInventoryManagement)) as MaterialPageRoute;
      late Widget createdWidget;
      await tester.pumpWidget(
        _createTestApp(
          home: Builder(
            builder: (context) {
              createdWidget = route.builder(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(createdWidget, isA<SellerLoginScreen>());
    });

    testWidgets('9. appMetadata role = buyer denies admin routes', (WidgetTester tester) async {
      AppRouter.testRoleResolver = () => 'buyer';
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.superAdmin)) as MaterialPageRoute;
      late Widget createdWidget;
      await tester.pumpWidget(
        _createTestApp(
          home: Builder(
            builder: (context) {
              createdWidget = route.builder(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(createdWidget, isA<SuperAdminLoginScreen>());
    });

    testWidgets('10. appMetadata role = seller denies admin routes', (WidgetTester tester) async {
      AppRouter.testRoleResolver = () => 'seller';
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.superAdmin)) as MaterialPageRoute;
      late Widget createdWidget;
      await tester.pumpWidget(
        _createTestApp(
          home: Builder(
            builder: (context) {
              createdWidget = route.builder(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(createdWidget, isA<SuperAdminLoginScreen>());
    });

    testWidgets('11. Unknown or missing appMetadata role defaults to deny', (WidgetTester tester) async {
      AppRouter.testRoleResolver = () => 'unknown_role';
      final routeSeller = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.sellerOrders)) as MaterialPageRoute;
      final routeAdmin = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.superAdmin)) as MaterialPageRoute;
      late Widget widgetSeller;
      late Widget widgetAdmin;

      await tester.pumpWidget(
        _createTestApp(
          home: Builder(
            builder: (context) {
              widgetSeller = routeSeller.builder(context);
              widgetAdmin = routeAdmin.builder(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(widgetSeller, isA<SellerLoginScreen>());
      expect(widgetAdmin, isA<SuperAdminLoginScreen>());
    });

    testWidgets('12. Privileged screen is not rendered before authorization succeeds', (WidgetTester tester) async {
      AppRouter.testRoleResolver = () => null;
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.sellerExecutiveDashboard)) as MaterialPageRoute;
      late Widget createdWidget;

      await tester.pumpWidget(
        _createTestApp(
          home: Builder(
            builder: (context) {
              createdWidget = route.builder(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(createdWidget, isA<SellerLoginScreen>());
    });
  });

  group('Route Resolution & Fallback Tests', () {
    testWidgets('13. Known public route resolves to BuyerDashboard', (WidgetTester tester) async {
      AppRouter.testRoleResolver = null;
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.home)) as MaterialPageRoute;
      late Widget createdWidget;
      await tester.pumpWidget(
        _createTestApp(
          home: Builder(
            builder: (context) {
              createdWidget = route.builder(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(createdWidget, isA<BuyerDashboard>());
    });

    testWidgets('14. Unknown route renders safe fallback UnknownRouteScreen', (WidgetTester tester) async {
      AppRouter.testRoleResolver = null;
      await tester.pumpWidget(
        _createTestApp(
          home: const SizedBox(),
          onGenerateRoute: AppRouter.generateRoute,
          initialRoute: '/non-existent-route-xyz',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UnknownRouteScreen), findsOneWidget);
      expect(find.text('Page Not Found'), findsWidgets);
      expect(find.text('Go to Home'), findsOneWidget);
    });
  });
}
