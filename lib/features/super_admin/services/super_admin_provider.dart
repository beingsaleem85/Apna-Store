import 'package:flutter/material.dart';
import '../core/permissions/rbac_engine.dart';

enum AdminRole { owner, superAdmin, financeAdmin, sellerManager, supportAdmin, catalogManager, orderManager, disputeManager, marketingManager, fraudAnalyst, reportingAnalyst, auditor }

class AdminAuditLogItem {
  final String id;
  final String adminName;
  final String actionType;
  final String targetEntity;
  final String details;
  final DateTime timestamp;

  AdminAuditLogItem({
    required this.id,
    required this.adminName,
    required this.actionType,
    required this.targetEntity,
    required this.details,
    required this.timestamp,
  });
}

class SuperAdminProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  String _activeSection = 'dashboard';
  String get activeSection => _activeSection;

  AdminRole _currentRole = AdminRole.superAdmin;
  AdminRole get currentRole => _currentRole;

  String _adminName = '';
  String get adminName => _adminName;

  String _adminEmail = '';
  String get adminEmail => _adminEmail;

  final List<AdminAuditLogItem> _auditLogs = [];

  List<AdminAuditLogItem> get auditLogs => List.unmodifiable(_auditLogs);

  /// Initializes admin provider session from verified backend auth data.
  void initializeAdminSession({
    required String email,
    required String backendRole,
    String? fullName,
  }) {
    _isLoggedIn = true;
    _adminEmail = email;
    _adminName = fullName ?? email.split('@').first.toUpperCase();
    _currentRole = _mapRoleStringToEnum(backendRole);
    logAuditAction('ADMIN_SESSION_INIT', 'Super Admin System', 'Authenticated as ${backendRole.toUpperCase()} role.');
    notifyListeners();
  }

  AdminRole _mapRoleStringToEnum(String role) {
    final lower = role.toLowerCase();
    if (lower == 'owner') return AdminRole.owner;
    if (lower == 'superadmin' || lower == 'super_admin' || lower == 'admin') return AdminRole.superAdmin;
    if (lower == 'finance_admin' || lower == 'financeadmin') return AdminRole.financeAdmin;
    if (lower == 'seller_manager' || lower == 'sellermanager') return AdminRole.sellerManager;
    if (lower == 'support_admin' || lower == 'supportadmin') return AdminRole.supportAdmin;
    if (lower == 'catalog_manager' || lower == 'catalogmanager') return AdminRole.catalogManager;
    if (lower == 'order_manager' || lower == 'ordermanager') return AdminRole.orderManager;
    if (lower == 'dispute_manager' || lower == 'disputemanager') return AdminRole.disputeManager;
    if (lower == 'marketing_manager' || lower == 'marketingmanager') return AdminRole.marketingManager;
    if (lower == 'fraud_analyst' || lower == 'fraudanalyst') return AdminRole.fraudAnalyst;
    if (lower == 'reporting_analyst' || lower == 'reportinganalyst') return AdminRole.reportingAnalyst;
    if (lower == 'auditor') return AdminRole.auditor;
    return AdminRole.auditor;
  }

  void logout() {
    _isLoggedIn = false;
    _adminEmail = '';
    _adminName = '';
    logAuditAction('ADMIN_LOGOUT', 'Super Admin System', 'Admin user session terminated.');
    notifyListeners();
  }

  void setActiveSection(String sectionId) {
    _activeSection = sectionId;
    notifyListeners();
  }

  bool hasPermission(String module, String action) {
    return RbacEngine.evaluate(role: _currentRole, module: module, action: action);
  }

  void logAuditAction(String actionType, String targetEntity, String details) {
    _auditLogs.insert(
      0,
      AdminAuditLogItem(
        id: 'LOG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        adminName: _adminName.isNotEmpty ? _adminName : 'Admin',
        actionType: actionType,
        targetEntity: targetEntity,
        details: details,
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}
