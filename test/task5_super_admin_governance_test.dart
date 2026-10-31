import 'package:flutter_test/flutter_test.dart';
import 'package:apna_store/features/super_admin/services/super_admin_provider.dart';
import 'package:apna_store/features/super_admin/screens/finance/commission_engine_screen.dart';
import 'package:apna_store/features/super_admin/screens/customers/customer_management_screen.dart';

void main() {
  group('Task 5: Super Admin Governance & Live Screens', () {
    test('SuperAdminProvider initializes session correctly with verified roles', () {
      final provider = SuperAdminProvider();
      expect(provider.isLoggedIn, isFalse);

      provider.initializeAdminSession(
        email: 'governance@apnastore.pk',
        backendRole: 'superAdmin',
        fullName: 'Super Admin Officer',
      );

      expect(provider.isLoggedIn, isTrue);
      expect(provider.currentRole, equals(AdminRole.superAdmin));
      expect(provider.adminName, equals('Super Admin Officer'));
      expect(provider.auditLogs.length, equals(1));
      expect(provider.auditLogs.first.actionType, equals('ADMIN_SESSION_INIT'));
    });

    test('SuperAdminProvider RBAC engine enforces permissions', () {
      final provider = SuperAdminProvider();
      provider.initializeAdminSession(
        email: 'finance@apnastore.pk',
        backendRole: 'finance_admin',
      );

      expect(provider.currentRole, equals(AdminRole.financeAdmin));
      // Finance admin can view financial module
      expect(provider.hasPermission('finance', 'view'), isTrue);
      // Finance admin cannot suspend platform killswitches
      expect(provider.hasPermission('system', 'killswitch'), isFalse);
    });

    test('CommissionRule model instantiates and modifies rate cleanly', () {
      final rule = CommissionRule(
        id: 'RULE-01',
        categoryName: 'Fashion & Apparel',
        commissionRate: 12.0,
        minOrderAmount: 0.0,
      );

      expect(rule.commissionRate, equals(12.0));
      rule.commissionRate = 14.5;
      expect(rule.commissionRate, equals(14.5));
    });

    test('CustomerUser model represents buyer profiles without fabrication', () {
      final cust = CustomerUser(
        id: 'CUST-01',
        name: 'Bilal Khan',
        email: 'bilal@apnastore.pk',
        phone: '03001234567',
        city: 'Lahore',
        totalOrders: 0,
        totalSpent: 0.0,
        walletBalance: 0.0,
        loyaltyTier: 'Member',
      );

      expect(cust.id, equals('CUST-01'));
      expect(cust.name, equals('Bilal Khan'));
      expect(cust.totalOrders, equals(0));
      expect(cust.isSuspended, isFalse);
      expect(cust.isRiskFlagged, isFalse);
    });
  });
}
