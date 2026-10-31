import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:apna_store/core/services/app_state_provider.dart';
import 'package:apna_store/features/super_admin/services/super_admin_provider.dart';
import 'package:apna_store/features/super_admin/core/auth/admin_auth_guard.dart';

void main() {
  group('Phase C — M14 & M15 Admin Governance & RBAC Tests', () {
    late AppStateProvider appState;
    late SuperAdminProvider adminProvider;

    setUp(() {
      appState = AppStateProvider();
      adminProvider = SuperAdminProvider();

      // Seed a test store & product
      appState.sellerController.syncAddStorePresentationCache(
        AppStore(
          id: 'test-store-001',
          shopName: 'Khaadi Official Flagship',
          isApproved: false,
          kycStatus: 'Pending',
          commissionRate: 10.0,
        ),
      );

      appState.catalogController.syncAddProductCache(
        AppProduct(
          id: 'prod-001',
          name: 'Embroidered Lawn Kurti',
          category: 'Fashion & Apparel',
          price: '4990',
          description: 'Premium summer embroidered lawn',
          imageUrl: 'https://example.com/kurti.jpg',
          sellerId: 'test-store-001',
          approvalStatus: 'Pending',
          variations: [],
          wholesalePrices: {},
        ),
      );
    });

    test('AppStateProvider approves and rejects stores cleanly', () async {
      // Find the seeded store
      expect(appState.stores.isNotEmpty, isTrue);
      final store = appState.stores.first;
      final storeId = store.id;

      // Approve store
      await appState.approveStore(storeId, commissionRate: 15.0);
      expect(store.isApproved, isTrue);
      expect(store.kycStatus, 'Approved');
      expect(store.commissionRate, 15.0);

      // Adjust commission
      await appState.adjustCommission(storeId, 18.5);
      expect(store.commissionRate, 18.5);

      // Reject store
      await appState.rejectStore(storeId, 'Missing CNIC document verification');
      expect(store.isApproved, isFalse);
      expect(store.kycStatus, 'Rejected');
      expect(store.rejectionReason, 'Missing CNIC document verification');
    });

    test('AppStateProvider approves and rejects products cleanly', () async {
      expect(appState.products.isNotEmpty, isTrue);
      final product = appState.products.first;
      final productId = product.id;

      // Approve product
      await appState.approveProduct(productId);
      expect(product.approvalStatus, 'Approved');

      // Reject product
      await appState.rejectProduct(productId, 'Prohibited counterfeit goods');
      expect(product.approvalStatus, 'Rejected');
      expect(product.rejectionReason, 'Prohibited counterfeit goods');
    });

    test('SuperAdminProvider maps roles securely and fails closed to least-privilege', () {
      // Super admin
      adminProvider.initializeAdminSession(
        email: 'admin@apnastore.pk',
        backendRole: 'super_admin',
        fullName: 'Super Admin',
      );
      expect(adminProvider.currentRole, AdminRole.superAdmin);
      expect(adminProvider.hasPermission('sellers', 'approve'), isTrue);
      expect(adminProvider.hasPermission('finance', 'view'), isTrue);

      // Finance Admin
      adminProvider.initializeAdminSession(
        email: 'finance@apnastore.pk',
        backendRole: 'finance_admin',
      );
      expect(adminProvider.currentRole, AdminRole.financeAdmin);
      expect(adminProvider.hasPermission('finance', 'view'), isTrue);
      expect(adminProvider.hasPermission('payouts', 'approve'), isTrue);

      // Unknown role must default to least-privileged auditor
      adminProvider.initializeAdminSession(
        email: 'unknown@apnastore.pk',
        backendRole: 'unknown_untrusted_role',
      );
      expect(adminProvider.currentRole, AdminRole.auditor);
      expect(adminProvider.hasPermission('sellers', 'approve'), isFalse);
      expect(adminProvider.hasPermission('finance', 'payout'), isFalse);
    });

    testWidgets('AdminAuthGuard blocks unauthenticated access with login prompt', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SuperAdminProvider>.value(
            value: adminProvider,
            child: Builder(
              builder: (context) => AdminAuthGuard.guardRoute(
                context: context,
                targetScreen: const Scaffold(body: Text('Protected Admin Data')),
                requiredModule: 'sellers',
                requiredAction: 'view',
              ),
            ),
          ),
        ),
      );

      // Expect login prompt since not logged in
      expect(find.text('Super Admin Authentication Required'), findsOneWidget);
      expect(find.text('Protected Admin Data'), findsNothing);
    });

    testWidgets('AdminAuthGuard blocks unauthorized roles with privilege error', (WidgetTester tester) async {
      adminProvider.initializeAdminSession(
        email: 'auditor@apnastore.pk',
        backendRole: 'auditor',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SuperAdminProvider>.value(
            value: adminProvider,
            child: Builder(
              builder: (context) => AdminAuthGuard.guardRoute(
                context: context,
                targetScreen: const Scaffold(body: Text('Secret Finance Screen')),
                requiredModule: 'finance',
                requiredAction: 'payout',
              ),
            ),
          ),
        ),
      );

      // Expect insufficient privilege warning
      expect(find.text('Insufficient Privilege Level'), findsOneWidget);
      expect(find.text('Secret Finance Screen'), findsNothing);
    });

    testWidgets('AdminAuthGuard grants access to authorized roles', (WidgetTester tester) async {
      adminProvider.initializeAdminSession(
        email: 'super@apnastore.pk',
        backendRole: 'super_admin',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SuperAdminProvider>.value(
            value: adminProvider,
            child: Builder(
              builder: (context) => AdminAuthGuard.guardRoute(
                context: context,
                targetScreen: const Scaffold(body: Text('Secret Finance Screen')),
                requiredModule: 'finance',
                requiredAction: 'payout',
              ),
            ),
          ),
        ),
      );

      // Expect access granted
      expect(find.text('Secret Finance Screen'), findsOneWidget);
      expect(find.text('Insufficient Privilege Level'), findsNothing);
    });
  });
}
