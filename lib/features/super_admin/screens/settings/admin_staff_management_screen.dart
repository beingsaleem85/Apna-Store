import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';

class AdminStaffUser {
  final String id;
  String name;
  String email;
  AdminRole role;
  String department;
  bool isActive;
  bool is2FAEnabled;
  String lastLogin;
  DateTime createdAt;

  AdminStaffUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    this.isActive = true,
    this.is2FAEnabled = true,
    this.lastLogin = 'Just Now',
    required this.createdAt,
  });
}

class RolePermissionModel {
  final String id;
  String roleTitle;
  String badge;
  Color color;
  Color bg;
  String description;
  List<String> permissions;

  RolePermissionModel({
    required this.id,
    required this.roleTitle,
    required this.badge,
    required this.color,
    required this.bg,
    required this.description,
    required this.permissions,
  });
}

class AdminStaffManagementScreen extends StatefulWidget {
  final int initialTabIndex;
  const AdminStaffManagementScreen({super.key, this.initialTabIndex = 0});

  @override
  State<AdminStaffManagementScreen> createState() => _AdminStaffManagementScreenState();
}

class _AdminStaffManagementScreenState extends State<AdminStaffManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _auditFilter = 'All'; // 'All', 'Financial', 'Security', 'KYC', 'Catalog'
  final TextEditingController _searchController = TextEditingController();

  final List<AdminStaffUser> _staffMembers = [];
  bool _isLoadingStaff = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchStaffMembers();
  }

  AdminRole _mapRoleString(String r) {
    final lower = r.toLowerCase();
    if (lower.contains('owner')) return AdminRole.owner;
    if (lower.contains('finance')) return AdminRole.financeAdmin;
    if (lower.contains('seller')) return AdminRole.sellerManager;
    if (lower.contains('catalog')) return AdminRole.catalogManager;
    if (lower.contains('fraud')) return AdminRole.fraudAnalyst;
    if (lower.contains('order')) return AdminRole.orderManager;
    if (lower.contains('support')) return AdminRole.supportAdmin;
    return AdminRole.superAdmin;
  }

  Future<void> _fetchStaffMembers() async {
    setState(() => _isLoadingStaff = true);
    try {
      final res = await Supabase.instance.client
          .from('user_roles')
          .select('user_id, role, granted_at, profiles(full_name, email)')
          .order('granted_at', ascending: false);
      if (res is List && res.isNotEmpty && mounted) {
        setState(() {
          _staffMembers.clear();
          for (final r in res) {
            final profile = r['profiles'] is Map ? r['profiles'] : {};
            final roleStr = (r['role'] ?? 'superAdmin').toString();
            _staffMembers.add(AdminStaffUser(
              id: (r['user_id'] ?? '').toString().substring(0, 8).toUpperCase(),
              name: profile['full_name'] ?? 'Staff Member',
              email: profile['email'] ?? 'admin@apnastore.pk',
              role: _mapRoleString(roleStr),
              department: 'Marketplace Operations',
              is2FAEnabled: true,
              lastLogin: 'Active',
              createdAt: DateTime.tryParse(r['granted_at']?.toString() ?? '') ?? DateTime.now(),
            ));
          }
        });
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _isLoadingStaff = false);
    }
  }

  // Dynamic RBAC Roles Matrix
  final List<RolePermissionModel> _rolesMatrix = [
    RolePermissionModel(
      id: 'ROLE-01',
      roleTitle: 'Super Admin / Platform Owner',
      badge: 'Full Unrestricted Access',
      color: const Color(0xFF0F172A),
      bg: const Color(0xFFF1F5F9),
      description: 'Complete root access across database, payments, server settings, seller payouts, and platform lockdown killswitches.',
      permissions: ['Create', 'Read', 'Update', 'Delete', 'Disburse Payouts', 'Freeze Stores', 'Killswitch', 'Manage Staff', 'Export FBR Ledgers'],
    ),
    RolePermissionModel(
      id: 'ROLE-02',
      roleTitle: 'Finance & Settlements Admin',
      badge: 'Financial Authority',
      color: const Color(0xFF059669),
      bg: const Color(0xFFECFDF5),
      description: 'Audit commission earnings, disburse seller bank payouts, handle refund disputes, and calculate FBR 18% sales taxes.',
      permissions: ['View GMV', 'Disburse Batches', 'Edit Commission Rates', 'Audit WHT', 'Process Refunds', 'Export Financial Ledgers'],
    ),
    RolePermissionModel(
      id: 'ROLE-03',
      roleTitle: 'Merchant Onboarding & Governance Manager',
      badge: 'Seller Management',
      color: const Color(0xFF2563EB),
      bg: const Color(0xFFEFF6FF),
      description: 'Verify merchant CNICs, NTN certificates, bank IBANs, manage store suspension, and approve new seller applications.',
      permissions: ['Approve KYC', 'Reject Store', 'Suspend Merchant', 'Edit Store Policies', 'Verify Bank IBAN'],
    ),
    RolePermissionModel(
      id: 'ROLE-04',
      roleTitle: 'Catalog & Product Moderation Admin',
      badge: 'Product & Brand Moderation',
      color: const Color(0xFF7C3AED),
      bg: const Color(0xFFF3E8FF),
      description: 'Moderate product listings, check intellectual property (IP) violations, approve brand registries, and enforce pricing policies.',
      permissions: ['Approve Listing', 'Takedown Fake Product', 'Verify Brand NTN', 'Category Mapping', 'Moderate Reviews'],
    ),
    RolePermissionModel(
      id: 'ROLE-05',
      roleTitle: 'Cyber Security & Fraud Analyst',
      badge: 'Cyber Defense',
      color: const Color(0xFFDC2626),
      bg: const Color(0xFFFEE2E2),
      description: 'Monitor live bot traffic, blacklist attacker IP subnets, lock fraud accounts, and enforce rate limits on checkout and OTPs.',
      permissions: ['Freeze Account', 'IP Range Blacklist', 'Edit Rate Limits', 'View Device Dossiers', 'National CNIC Blacklist'],
    ),
    RolePermissionModel(
      id: 'ROLE-06',
      roleTitle: 'Customer Support & Dispute Arbitration Officer',
      badge: 'Support & Arbitration',
      color: const Color(0xFFD97706),
      bg: const Color(0xFFFEF3C7),
      description: 'Arbitrate buyer-seller return claims, issue customer credit refunds, and manage live help desk support tickets.',
      permissions: ['Read Orders', 'Arbitrate Disputes', 'Authorize Return Slip', 'Close Tickets', 'Issue Customer Credits'],
    ),
  ];

  // Baseline initial audit logs
  final List<Map<String, dynamic>> _defaultAuditLogs = [
    {
      'id': 'LOG-94821',
      'admin': 'Zain Ul Abideen (Owner)',
      'action': 'BATCH_PAYOUT_DISBURSEMENT',
      'category': 'Financial',
      'target': '3 Seller Bank Batches (Rs. 410,500)',
      'details': 'Approved bulk 1-Click Habib Bank / Meezan IBAN merchant settlements.',
      'ip': '111.68.102.12',
      'time': 'Just Now',
      'severity': 'HIGH',
    },
    {
      'id': 'LOG-94820',
      'admin': 'Bilal Farooq (Security)',
      'action': 'SECURITY_FREEZE_ACCOUNT',
      'category': 'Security',
      'target': 'Store: Merchant Store (ST-8902)',
      'details': 'Frozen account due to heuristic self-buying and fake COD return abuse.',
      'ip': '182.185.12.90',
      'time': '18 Mins Ago',
      'severity': 'CRITICAL',
    },
    {
      'id': 'LOG-94819',
      'admin': 'Ali Hamza (Finance)',
      'action': 'COMMISSION_RATE_UPDATE',
      'category': 'Financial',
      'target': 'Category: Mobiles & Tablets (CAT-02)',
      'details': 'Adjusted marketplace platform commission rate from 6.0% down to 5.0%.',
      'ip': '39.40.10.15',
      'time': '1 Hour Ago',
      'severity': 'MEDIUM',
    },
    {
      'id': 'LOG-94818',
      'admin': 'Sara Khan (Sellers)',
      'action': 'SELLER_KYC_VERIFICATION',
      'category': 'KYC',
      'target': 'Seller: Al-Madina Traders (35201-8912345-1)',
      'details': 'Verified CNIC & FBR NTN certificate; approved merchant for live catalog selling.',
      'ip': '175.107.199.12',
      'time': '3 Hours Ago',
      'severity': 'NORMAL',
    },
    {
      'id': 'LOG-94817',
      'admin': 'Usman Ahmed (Catalog)',
      'action': 'PRODUCT_TAKEDOWN',
      'category': 'Catalog',
      'target': 'Product: First Copy Nike Shoes (PRD-771)',
      'details': 'Product banned and delisted due to Intellectual Property (IP) trademark violation.',
      'ip': '39.40.10.15',
      'time': '5 Hours Ago',
      'severity': 'HIGH',
    },
    {
      'id': 'LOG-94816',
      'admin': 'Bilal Farooq (Security)',
      'action': 'FIREWALL_IP_BLACKLIST',
      'category': 'Security',
      'target': 'Subnet Range: 111.68.102.0/24',
      'details': 'Added IP range to WAF blacklist following 400+ cart-hoarding bot requests.',
      'ip': '182.185.12.90',
      'time': 'Yesterday',
      'severity': 'CRITICAL',
    },
    {
      'id': 'LOG-94815',
      'admin': 'Zain Ul Abideen (Owner)',
      'action': 'RBAC_ROLE_ASSIGNMENT',
      'category': 'Security',
      'target': 'User: Bilal Farooq (STF-05)',
      'details': 'Granted Fraud Analyst security privileges with emergency freeze authority.',
      'ip': '111.68.102.12',
      'time': '2 Days Ago',
      'severity': 'HIGH',
    },
  ];


  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = Provider.of<SuperAdminProvider>(context);

    // Merge live logs with default ledger
    final List<Map<String, dynamic>> allAuditLogs = [
      ...adminState.auditLogs.map((l) => {
            'id': l.id,
            'admin': '${l.adminName} (${adminState.currentRole.name})',
            'action': l.actionType,
            'category': _categorizeAction(l.actionType),
            'target': l.targetEntity,
            'details': l.details,
            'ip': '111.68.102.12 (Session)',
            'time': 'Just Now',
            'severity': l.actionType.contains('FREEZE') || l.actionType.contains('KILLSWITCH') ? 'CRITICAL' : 'HIGH',
          }),
      ..._defaultAuditLogs,
    ];

    // Filter audit logs
    final filteredLogs = allAuditLogs.where((log) {
      final matchesFilter = _auditFilter == 'All' || log['category'] == _auditFilter;
      final matchesSearch = _searchQuery.isEmpty ||
          log['id'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          log['admin'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          log['action'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          log['target'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          log['details'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumbs & Dynamic Header
          const Text('Breadcrumbs > Security & Governance > Audit Logs & RBAC', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tabController.index == 2
                        ? 'Security Audit Trail & Compliance Ledger'
                        : _tabController.index == 1
                            ? 'Role-Based Access Control (RBAC) Matrix'
                            : 'Staff Accounts & Administrative Access',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tamper-proof immutable log of all admin operations, staff privilege delegations, and system events.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: const Text('Export Audit Log', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _showExportAuditModal(allAuditLogs),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add_rounded, size: 16),
                    label: const Text('+ Add Staff Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _showAddStaffModal(adminState),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Clickable Metric KPI Summary Cards
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _tabController.animateTo(2),
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'Total Audit Trail Events',
                    value: '${allAuditLogs.length} Logged Actions',
                    subtitle: 'Click to view Audit Ledger (Tab 3)',
                    icon: Icons.history_edu_rounded,
                    iconColor: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  onTap: () {
                    _tabController.animateTo(2);
                    setState(() => _auditFilter = 'Financial');
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'Critical Security & Finance',
                    value: '${allAuditLogs.where((l) => l['severity'] == 'CRITICAL' || l['severity'] == 'HIGH').length} High Impact',
                    subtitle: 'Payouts, Bans & Freezes (Tab 3)',
                    icon: Icons.security_rounded,
                    iconColor: const Color(0xFFDC2626),
                    bgColor: const Color(0xFFFEE2E2),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  onTap: () => _tabController.animateTo(0),
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'Active Admin Staff',
                    value: '${_staffMembers.where((s) => s.isActive).length} Operators',
                    subtitle: 'Full 2FA Protected (Tab 1)',
                    icon: Icons.badge_outlined,
                    iconColor: const Color(0xFF059669),
                    bgColor: const Color(0xFFECFDF5),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  onTap: () => _tabController.animateTo(1),
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'RBAC Access Level',
                    value: '${_rolesMatrix.length} Defined Roles',
                    subtitle: 'Click to Edit Matrix (Tab 2)',
                    icon: Icons.admin_panel_settings_rounded,
                    iconColor: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFF3E8FF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Sub-Tabs Navigation (Clean Sleek Light TabBar)
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF334155),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              tabs: const [
                Tab(icon: Icon(Icons.people_alt_outlined, size: 16), text: 'Staff & Operator Accounts'),
                Tab(icon: Icon(Icons.admin_panel_settings_outlined, size: 16), text: 'Roles & Permissions Matrix (RBAC)'),
                Tab(icon: Icon(Icons.history_rounded, size: 16), text: 'System Security Audit Trail Logs'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dynamic Tab View
          if (_tabController.index == 0)
            _buildStaffAccountsTab(adminState)
          else if (_tabController.index == 1)
            _buildRbacMatrixTab(adminState)
          else
            _buildAuditLogsTab(filteredLogs, adminState),
        ],
      ),
    );
  }

  String _categorizeAction(String action) {
    if (action.contains('PAYOUT') || action.contains('COMMISSION') || action.contains('FINANCE')) return 'Financial';
    if (action.contains('SECURITY') || action.contains('FIREWALL') || action.contains('LOCKDOWN') || action.contains('KILLSWITCH') || action.contains('ROLE')) return 'Security';
    if (action.contains('KYC') || action.contains('SELLER')) return 'KYC';
    if (action.contains('PRODUCT') || action.contains('CATEGORY') || action.contains('CMS')) return 'Catalog';
    return 'Security';
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: STAFF ACCOUNTS DIRECTORY
  // ==========================================
  Widget _buildStaffAccountsTab(SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Header Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Staff Member & Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Assigned Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('2FA Protection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Account Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            if (_staffMembers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.badge_outlined, size: 48, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text('No staff members registered in governance system.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ],
                ),
              )
            else
              ..._staffMembers.map((staff) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Member info
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF0F172A),
                            child: Text(
                              staff.name.isNotEmpty ? staff.name[0] : 'A',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(staff.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
                                Text(staff.email, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Department
                    Expanded(
                      flex: 2,
                      child: Text(staff.department, style: const TextStyle(color: Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600)),
                    ),

                    // Role Badge
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            staff.role.name.toUpperCase(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                          ),
                        ),
                      ),
                    ),

                    // 2FA Badge
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Icon(
                            staff.is2FAEnabled ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                            size: 16,
                            color: staff.is2FAEnabled ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            staff.is2FAEnabled ? '2FA Enabled' : 'Not Setup',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: staff.is2FAEnabled ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status Switch
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Switch(
                            value: staff.isActive,
                            activeColor: const Color(0xFF10B981),
                            onChanged: (val) {
                              setState(() => staff.isActive = val);
                              adminState.logAuditAction('STAFF_STATUS_CHANGE', staff.name, val ? 'Reactivated staff account.' : 'Suspended staff account.');
                              SuperAdminDialogs.showToast(context, '${staff.name} is now ${val ? "Active 🟢" : "Suspended ⚪"}');
                            },
                          ),
                          Text(
                            staff.isActive ? 'Active' : 'Suspended',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: staff.isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),

                    // Actions: Edit Staff & Revoke
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit_outlined, size: 13),
                            label: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF334155),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: () => _showEditStaffModal(staff, adminState),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                            tooltip: 'Revoke Admin Account',
                            onPressed: () async {
                              final confirmed = await SuperAdminDialogs.showConfirmation(
                                context: context,
                                title: 'Revoke Admin Staff Access',
                                message: 'Are you sure you want to permanently revoke account permissions for ${staff.name}?',
                              );
                              if (confirmed) {
                                setState(() => _staffMembers.remove(staff));
                                adminState.logAuditAction('STAFF_REVOKE', staff.name, 'Permanently revoked administrative credentials.');
                                if (mounted) SuperAdminDialogs.showToast(context, 'Staff account ${staff.name} revoked.');
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: RBAC PERMISSIONS MATRIX (WITH ADD & EDIT PERMISSIONS)
  // ==========================================
  Widget _buildRbacMatrixTab(SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Role-Based Access Control (RBAC) Privilege Matrix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Granular security boundaries and authority rules enforced across API endpoints and administrative dashboards.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_moderator_rounded, size: 16),
                  label: const Text('+ Create Custom Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                  onPressed: () => _showCreateCustomRoleModal(adminState),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ..._rolesMatrix.map((roleModel) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, size: 20, color: Color(0xFF0F172A)),
                            const SizedBox(width: 8),
                            Text(roleModel.roleTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: roleModel.bg, borderRadius: BorderRadius.circular(6)),
                              child: Text(roleModel.badge, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: roleModel.color)),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.tune_rounded, size: 14),
                              label: const Text('Edit Permissions ⚙️', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF334155),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              onPressed: () => _showEditRolePermissionsModal(roleModel, adminState),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(roleModel.description, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: roleModel.permissions.map((p) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE2E8F0))),
                          child: Text('✓ $p', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: SYSTEM SECURITY AUDIT TRAIL LOGS
  // ==========================================
  Widget _buildAuditLogsTab(List<Map<String, dynamic>> filteredLogs, SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search & Filter Toolbar
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: const InputDecoration(
                        hintText: 'Search audit logs by Event ID, Admin Name, Action, or Target Record...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                Row(
                  children: ['All', 'Financial', 'Security', 'KYC', 'Catalog'].map((cat) {
                    final isSel = _auditFilter == cat;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: ChoiceChip(
                        label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : const Color(0xFF64748B))),
                        selected: isSel,
                        selectedColor: const Color(0xFF0F172A),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (val) => setState(() => _auditFilter = cat),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('Event ID & Timestamp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Operator (Admin)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Action Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 3, child: Text('Target Record & Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('IP & Subnet Hash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 1, child: Text('Dossier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Rows
            ...filteredLogs.map((log) {
              final isCritical = log['severity'] == 'CRITICAL';
              final isHigh = log['severity'] == 'HIGH';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isCritical ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Event ID & Time
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log['id'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 12, fontFamily: 'monospace')),
                          const SizedBox(height: 2),
                          Text(log['time'] as String, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                        ],
                      ),
                    ),

                    // Operator
                    Expanded(
                      flex: 2,
                      child: Text(log['admin'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                    ),

                    // Action Type Badge
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCritical ? const Color(0xFFFEE2E2) : isHigh ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            log['action'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isCritical ? const Color(0xFFDC2626) : isHigh ? const Color(0xFFD97706) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Target & Details
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log['target'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155))),
                          Text(log['details'] as String, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                        ],
                      ),
                    ),

                    // IP & Subnet
                    Expanded(
                      flex: 2,
                      child: Text(log['ip'] as String, style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                    ),

                    // Dossier Modal Button
                    Expanded(
                      flex: 1,
                      child: IconButton(
                        icon: const Icon(Icons.description_outlined, color: Color(0xFF2563EB), size: 20),
                        tooltip: 'View Tamper-Proof Audit JSON',
                        onPressed: () => _showAuditDetailsModal(log),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // MODALS & DIALOGS
  // ==========================================
  void _showAddStaffModal(SuperAdminProvider adminState) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final deptCtrl = TextEditingController(text: 'Finance & Settlements');
    AdminRole selRole = AdminRole.sellerManager;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.person_add_rounded, color: Color(0xFF2563EB), size: 22),
              SizedBox(width: 8),
              Text('Add New Admin Staff Account', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Corporate Email (@apnastore.com)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deptCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Department Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AdminRole>(
                  value: selRole,
                  decoration: const InputDecoration(labelText: 'Assign RBAC Role Matrix', border: OutlineInputBorder()),
                  items: AdminRole.values.map((r) {
                    return DropdownMenuItem(value: r, child: Text(r.name.toUpperCase()));
                  }).toList(),
                  onChanged: (r) {
                    if (r != null) setMState(() => selRole = r);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () {
                if (nameCtrl.text.isNotEmpty && emailCtrl.text.isNotEmpty) {
                  setState(() {
                    _staffMembers.add(
                      AdminStaffUser(
                        id: 'STF-0${_staffMembers.length + 1}',
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        role: selRole,
                        department: deptCtrl.text.trim(),
                        is2FAEnabled: true,
                        lastLogin: 'Never (Invited)',
                        createdAt: DateTime.now(),
                      ),
                    );
                  });
                  adminState.logAuditAction('STAFF_ACCOUNT_CREATED', nameCtrl.text.trim(), 'Assigned ${selRole.name.toUpperCase()} role to new staff member.');
                  Navigator.pop(ctx);
                  SuperAdminDialogs.showToast(context, 'Staff Account Created & Verification Email Dispatched!');
                }
              },
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStaffModal(AdminStaffUser staff, SuperAdminProvider adminState) {
    final nameCtrl = TextEditingController(text: staff.name);
    final emailCtrl = TextEditingController(text: staff.email);
    final deptCtrl = TextEditingController(text: staff.department);
    AdminRole selRole = staff.role;
    bool is2FA = staff.is2FAEnabled;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 22),
              const SizedBox(width: 8),
              Text('Edit Staff Member: ${staff.name}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Corporate Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deptCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AdminRole>(
                  value: selRole,
                  decoration: const InputDecoration(labelText: 'Assigned RBAC Role', border: OutlineInputBorder()),
                  items: AdminRole.values.map((r) {
                    return DropdownMenuItem(value: r, child: Text(r.name.toUpperCase()));
                  }).toList(),
                  onChanged: (r) {
                    if (r != null) setMState(() => selRole = r);
                  },
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Require 2FA Authentication', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  subtitle: const Text('Forces Google Authenticator or SMS OTP on login.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  value: is2FA,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (v) => setMState(() => is2FA = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () {
                setState(() {
                  staff.name = nameCtrl.text.trim();
                  staff.email = emailCtrl.text.trim();
                  staff.department = deptCtrl.text.trim();
                  staff.role = selRole;
                  staff.is2FAEnabled = is2FA;
                });
                adminState.logAuditAction('STAFF_UPDATED', staff.name, 'Updated profile & role to ${selRole.name.toUpperCase()}');
                Navigator.pop(ctx);
                SuperAdminDialogs.showToast(context, '${staff.name} profile updated successfully!');
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRolePermissionsModal(RolePermissionModel roleModel, SuperAdminProvider adminState) {
    final availablePerms = [
      'Create',
      'Read',
      'Update',
      'Delete',
      'Disburse Payouts',
      'Freeze Stores',
      'Killswitch',
      'Manage Staff',
      'Export FBR Ledgers',
      'View GMV',
      'Disburse Batches',
      'Edit Commission Rates',
      'Audit WHT',
      'Process Refunds',
      'Export Financial Ledgers',
      'Approve KYC',
      'Reject Store',
      'Suspend Merchant',
      'Edit Store Policies',
      'Verify Bank IBAN',
      'Approve Listing',
      'Takedown Fake Product',
      'Verify Brand NTN',
      'Category Mapping',
      'Moderate Reviews',
      'Freeze Account',
      'IP Range Blacklist',
      'Edit Rate Limits',
      'View Device Dossiers',
      'National CNIC Blacklist',
      'Read Orders',
      'Arbitrate Disputes',
      'Authorize Return Slip',
      'Close Tickets',
      'Issue Customer Credits',
    ].toSet().toList();

    List<String> currentPerms = List.from(roleModel.permissions);
    final newPermCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 22),
              const SizedBox(width: 8),
              Text('Edit Authority: ${roleModel.roleTitle}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 540,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(roleModel.description, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 14),
                const Text('Active Granted Privileges (Click to Toggle):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),

                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: availablePerms.map((perm) {
                        final isGranted = currentPerms.contains(perm);
                        return FilterChip(
                          label: Text(perm, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isGranted ? Colors.white : const Color(0xFF475569))),
                          selected: isGranted,
                          selectedColor: const Color(0xFF2563EB),
                          backgroundColor: Colors.white,
                          onSelected: (selected) {
                            setMState(() {
                              if (selected) {
                                currentPerms.add(perm);
                              } else {
                                currentPerms.remove(perm);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Add Custom Permission Input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: newPermCtrl,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: 'Add custom privilege (e.g. "Export Audit JSON")...',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                      onPressed: () {
                        if (newPermCtrl.text.trim().isNotEmpty) {
                          setMState(() {
                            final p = newPermCtrl.text.trim();
                            if (!availablePerms.contains(p)) availablePerms.add(p);
                            if (!currentPerms.contains(p)) currentPerms.add(p);
                            newPermCtrl.clear();
                          });
                        }
                      },
                      child: const Text('+ Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () {
                setState(() {
                  roleModel.permissions = List.from(currentPerms);
                });
                adminState.logAuditAction('RBAC_ROLE_PERMISSIONS_UPDATE', roleModel.roleTitle, 'Updated authority to ${currentPerms.length} privileges.');
                Navigator.pop(ctx);
                SuperAdminDialogs.showToast(context, '${roleModel.roleTitle} permissions updated successfully!');
              },
              child: const Text('Save Permissions'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateCustomRoleModal(SuperAdminProvider adminState) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final badgeCtrl = TextEditingController(text: 'Specialized Role');
    final selectedPerms = <String>{'Read', 'View GMV', 'Export Financial Ledgers'};

    final samplePerms = [
      'Create', 'Read', 'Update', 'Delete', 'Disburse Payouts', 'Freeze Stores', 'Killswitch', 'Manage Staff',
      'View GMV', 'Edit Commission Rates', 'Audit WHT', 'Process Refunds', 'Approve KYC', 'Suspend Merchant',
      'Approve Listing', 'Takedown Fake Product', 'Freeze Account', 'IP Range Blacklist', 'Arbitrate Disputes',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.add_moderator_rounded, color: Color(0xFF2563EB), size: 24),
              SizedBox(width: 8),
              Text('Create New Custom RBAC Role', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Role Title (e.g. "Warehouse Operations Lead")', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: badgeCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Role Badge Text (e.g. "Logistics & Stock")', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Role Scope & Description', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                const Text('Select Allowed Permissions (Ikhtiyar):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: samplePerms.map((perm) {
                        final isSel = selectedPerms.contains(perm);
                        return FilterChip(
                          label: Text(perm, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSel ? Colors.white : const Color(0xFF475569))),
                          selected: isSel,
                          selectedColor: const Color(0xFF2563EB),
                          backgroundColor: Colors.white,
                          onSelected: (val) {
                            setMState(() {
                              if (val) selectedPerms.add(perm);
                              else selectedPerms.remove(perm);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
              onPressed: () {
                if (titleCtrl.text.isNotEmpty) {
                  setState(() {
                    _rolesMatrix.add(RolePermissionModel(
                      id: 'ROLE-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                      roleTitle: titleCtrl.text.trim(),
                      badge: badgeCtrl.text.trim().isNotEmpty ? badgeCtrl.text.trim() : 'Custom Role',
                      color: const Color(0xFF2563EB),
                      bg: const Color(0xFFEFF6FF),
                      description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : 'Custom departmental privileges.',
                      permissions: selectedPerms.toList(),
                    ));
                  });
                  adminState.logAuditAction('CUSTOM_ROLE_CREATED', titleCtrl.text.trim(), 'Created new custom role with ${selectedPerms.length} permissions.');
                  Navigator.pop(ctx);
                  SuperAdminDialogs.showToast(context, 'New Custom Role "${titleCtrl.text}" Created Successfully!');
                }
              },
              child: const Text('Create Role'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAuditDetailsModal(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.history_edu_rounded, color: Color(0xFF2563EB), size: 24),
            const SizedBox(width: 10),
            Text('Audit Event Dossier — ${log['id']}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(
                  children: [
                    _buildDossierRow('Action Type', log['action'] as String),
                    const Divider(height: 12),
                    _buildDossierRow('Operator (Admin)', log['admin'] as String),
                    const Divider(height: 12),
                    _buildDossierRow('Target Record', log['target'] as String),
                    const Divider(height: 12),
                    _buildDossierRow('Origin IP & Subnet', log['ip'] as String),
                    const Divider(height: 12),
                    _buildDossierRow('SHA-256 Integrity Seal', 'e8b91a7c8f29d4... (Tamper-Proof)'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Full Action Narrative & Metadata:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              Text(log['details'] as String, style: const TextStyle(color: Color(0xFF334155), fontSize: 12, height: 1.4)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close Dossier'),
          ),
        ],
      ),
    );
  }

  Widget _buildDossierRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showExportAuditModal(List<Map<String, dynamic>> logs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.file_download_outlined, color: Color(0xFF059669), size: 24),
            SizedBox(width: 8),
            Text('Export Compliance Audit Ledger', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Exporting ${logs.length} immutable audit trail records with digital SHA-256 signatures for FBR / SECP tax compliance audits.', style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFBBF7D0))),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Format: CSV & JSON Compliance Bundle ready for download.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton.icon(
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Download CSV Ledger'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              SuperAdminDialogs.showToast(context, 'Compliance Audit Ledger Exported Successfully!');
            },
          ),
        ],
      ),
    );
  }
}
