import '../../services/super_admin_provider.dart';

class RbacEngine {
  static const Map<AdminRole, Map<String, List<String>>> permissionMatrix = {
    AdminRole.owner: {
      '*': ['*'], // Full unrestricted permissions across all modules
    },
    AdminRole.superAdmin: {
      '*': ['*'],
    },
    AdminRole.financeAdmin: {
      'finance': ['view', 'approve', 'export', 'adjust'],
      'commission': ['view', 'edit', 'approve'],
      'payouts': ['view', 'approve', 'hold', 'export'],
      'disputes': ['view', 'refund'],
      'reports': ['view', 'export'],
    },
    AdminRole.sellerManager: {
      'sellers': ['view', 'approve', 'reject', 'suspend', 'edit'],
      'kyc': ['view', 'verify', 'reject'],
      'products': ['view', 'moderate'],
      'support': ['view', 'respond'],
    },
    AdminRole.supportAdmin: {
      'support': ['view', 'assign', 'respond', 'close'],
      'customers': ['view', 'assist'],
      'orders': ['view', 'hold'],
      'disputes': ['view', 'escalate'],
    },
    AdminRole.catalogManager: {
      'categories': ['view', 'create', 'edit', 'delete'],
      'products': ['view', 'approve', 'reject', 'suspend'],
      'brands': ['view', 'verify'],
    },
    AdminRole.orderManager: {
      'orders': ['view', 'cancel', 'hold', 'release', 'reassign'],
      'shipping': ['view', 'update'],
    },
    AdminRole.disputeManager: {
      'disputes': ['view', 'approve', 'reject', 'refund', 'appeal'],
      'orders': ['view'],
    },
    AdminRole.marketingManager: {
      'promotions': ['view', 'create', 'edit', 'approve'],
      'cms': ['view', 'edit'],
      'notifications': ['view', 'send', 'schedule'],
    },
    AdminRole.fraudAnalyst: {
      'fraud': ['view', 'blacklist', 'score', 'audit'],
      'customers': ['view', 'suspend'],
      'orders': ['view', 'hold'],
    },
    AdminRole.reportingAnalyst: {
      'reports': ['view', 'export'],
      'dashboard': ['view'],
      'sellers': ['view'],
      'orders': ['view'],
    },
    AdminRole.auditor: {
      '*': ['view'], // View-only access across all system modules
    },
  };

  static bool evaluate({
    required AdminRole role,
    required String module,
    required String action,
  }) {
    final rolePermissions = permissionMatrix[role];
    if (rolePermissions == null) return false;

    // Check wildcard all-module permission
    if (rolePermissions.containsKey('*')) {
      final actions = rolePermissions['*']!;
      if (actions.contains('*') || actions.contains(action) || action == 'view') return true;
    }

    // Check specific module permissions
    final moduleActions = rolePermissions[module];
    if (moduleActions != null) {
      return moduleActions.contains('*') || moduleActions.contains(action) || (action == 'view' && role == AdminRole.auditor);
    }

    return false;
  }
}
