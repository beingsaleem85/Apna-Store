import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:apna_store/core/services/app_auth_provider.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/core/routes/app_routes.dart';
import 'package:apna_store/core/routes/app_router.dart';
import 'package:apna_store/features/super_admin/services/super_admin_provider.dart';
import 'package:apna_store/features/super_admin/screens/auth/admin_login_screen.dart';
import 'package:apna_store/features/seller/screens/seller_auth_screens.dart';

void main() {
  group('Phase 5 — Complete Auth & Session Security Tests', () {
    tearDown(() {
      AppRouter.testRoleResolver = null;
    });

    test('1. Valid seller role authorization allows privileged seller route', () {
      AppRouter.testRoleResolver = () => 'seller';
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.sellerDashboard));
      expect(route, isA<MaterialPageRoute>());
      final builder = (route as MaterialPageRoute).builder;
      final widget = builder(StatelessBuildContext());
      expect(widget.runtimeType.toString(), equals('SellerDashboard'));
    });

    test('2. Valid admin role authorization allows privileged super-admin route', () {
      AppRouter.testRoleResolver = () => 'admin';
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.superAdmin));
      expect(route, isA<MaterialPageRoute>());
      final builder = (route as MaterialPageRoute).builder;
      final widget = builder(StatelessBuildContext());
      expect(widget.runtimeType.toString(), equals('SuperAdminShell'));
    });

    test('3. Buyer user CANNOT access seller routes (Redirects to SellerLoginScreen)', () {
      AppRouter.testRoleResolver = () => 'buyer';
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.sellerDashboard));
      expect(route, isA<MaterialPageRoute>());
      final builder = (route as MaterialPageRoute).builder;
      final widget = builder(StatelessBuildContext());
      expect(widget, isA<SellerLoginScreen>());
    });

    test('4. Buyer user CANNOT access admin routes (Redirects to SuperAdminLoginScreen)', () {
      AppRouter.testRoleResolver = () => 'buyer';
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.superAdmin));
      expect(route, isA<MaterialPageRoute>());
      final builder = (route as MaterialPageRoute).builder;
      final widget = builder(StatelessBuildContext());
      expect(widget, isA<SuperAdminLoginScreen>());
    });

    test('5. Seller user CANNOT access admin routes (Redirects to SuperAdminLoginScreen)', () {
      AppRouter.testRoleResolver = () => 'seller';
      final route = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.superAdmin));
      expect(route, isA<MaterialPageRoute>());
      final builder = (route as MaterialPageRoute).builder;
      final widget = builder(StatelessBuildContext());
      expect(widget, isA<SuperAdminLoginScreen>());
    });

    test('6. Unauthenticated / UNKNOWN auth state blocks privileged routes', () {
      AppRouter.testRoleResolver = () => null;
      final routeSeller = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.sellerDashboard));
      final routeAdmin = AppRouter.generateRoute(const RouteSettings(name: AppRoutes.superAdmin));

      final sellerWidget = (routeSeller as MaterialPageRoute).builder(StatelessBuildContext());
      final adminWidget = (routeAdmin as MaterialPageRoute).builder(StatelessBuildContext());

      expect(sellerWidget, isA<SellerLoginScreen>());
      expect(adminWidget, isA<SuperAdminLoginScreen>());
    });

    testWidgets('7. SuperAdmin login screen has NO role selection dropdown', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppAuthProvider()),
            ChangeNotifierProvider(create: (_) => SuperAdminProvider()),
          ],
          child: const MaterialApp(home: SuperAdminLoginScreen()),
        ),
      );

      // Verify no DropdownButtonFormField exists in UI
      expect(find.byType(DropdownButtonFormField<AdminRole>), findsNothing);
      expect(find.text('Select Admin Role Module'), findsNothing);
    });

    testWidgets('8. SuperAdmin login fields do NOT pre-fill default credentials', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppAuthProvider()),
            ChangeNotifierProvider(create: (_) => SuperAdminProvider()),
          ],
          child: const MaterialApp(home: SuperAdminLoginScreen()),
        ),
      );

      final emailField = tester.widget<TextFormField>(find.byType(TextFormField).first);
      expect(emailField.controller?.text.isEmpty ?? true, isTrue);
    });

    testWidgets('9. Seller forgot password screen uses email reset without mock OTP 4321', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppAuthProvider()),
            ChangeNotifierProvider(create: (_) => AppStateProvider()),
          ],
          child: const MaterialApp(home: SellerForgotPasswordScreen()),
        ),
      );

      expect(find.text('Send Reset Link'), findsOneWidget);
      expect(find.textContaining('4321'), findsNothing);
    });
  });
}

class StatelessBuildContext extends BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
