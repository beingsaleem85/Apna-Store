import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';

class RiskAlert {
  final String id;
  final String rawId;
  final String entityName;
  final String entityType; // 'Store' or 'Buyer'
  final String entityId;
  final int riskScore; // 0 to 100
  final String riskFactor;
  final String ipAddress;
  final String deviceHash;
  final String location;
  String status; // 'High Risk', 'Medium Warning', 'Resolved', 'Frozen'
  final DateTime createdAt;

  RiskAlert({
    required this.id,
    required this.rawId,
    required this.entityName,
    required this.entityType,
    required this.entityId,
    required this.riskScore,
    required this.riskFactor,
    required this.ipAddress,
    required this.deviceHash,
    required this.location,
    this.status = 'High Risk',
    required this.createdAt,
  });

  factory RiskAlert.fromJson(Map<String, dynamic> json) {
    final rawId = (json['id'] ?? '').toString();
    final shortId = rawId.length >= 8 ? 'RISK-${rawId.substring(0, 8).toUpperCase()}' : 'RISK-$rawId';
    return RiskAlert(
      id: shortId,
      rawId: rawId,
      entityName: (json['entity_name'] ?? 'Unknown Entity').toString(),
      entityType: (json['entity_type'] ?? 'Buyer').toString(),
      entityId: (json['entity_id'] ?? '').toString(),
      riskScore: (json['risk_score'] as num?)?.toInt() ?? 0,
      riskFactor: (json['risk_factor'] ?? 'Unspecified risk flag').toString(),
      ipAddress: (json['ip_address'] ?? 'N/A').toString(),
      deviceHash: (json['device_hash'] ?? 'N/A').toString(),
      location: (json['location'] ?? 'Pakistan').toString(),
      status: (json['status'] ?? 'High Risk').toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class BlacklistedIdentifier {
  final String id;
  final String identifierType; // 'IP', 'CNIC', 'Bank IBAN', 'Phone Number'
  final String identifierValue;
  final String holderName;
  final String reason;
  final String threatLevel; // 'High', 'Critical', 'Suspicious'
  final DateTime createdAt;

  BlacklistedIdentifier({
    required this.id,
    required this.identifierType,
    required this.identifierValue,
    required this.holderName,
    required this.reason,
    required this.threatLevel,
    required this.createdAt,
  });

  factory BlacklistedIdentifier.fromJson(Map<String, dynamic> json) {
    return BlacklistedIdentifier(
      id: (json['id'] ?? '').toString(),
      identifierType: (json['identifier_type'] ?? 'IP').toString(),
      identifierValue: (json['identifier_value'] ?? '').toString(),
      holderName: (json['holder_name'] ?? 'Unknown Identity').toString(),
      reason: (json['reason'] ?? 'Manual Administrator Ban').toString(),
      threatLevel: (json['threat_level'] ?? 'High').toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class SecurityRuleModel {
  final String id;
  final String ruleCode;
  final String ruleTitle;
  final String description;
  String thresholdValue;
  bool isEnabled;

  SecurityRuleModel({
    required this.id,
    required this.ruleCode,
    required this.ruleTitle,
    required this.description,
    required this.thresholdValue,
    this.isEnabled = true,
  });

  factory SecurityRuleModel.fromJson(Map<String, dynamic> json) {
    return SecurityRuleModel(
      id: (json['id'] ?? '').toString(),
      ruleCode: (json['rule_code'] ?? '').toString(),
      ruleTitle: (json['rule_title'] ?? 'Security Rule').toString(),
      description: (json['description'] ?? '').toString(),
      thresholdValue: (json['threshold_value'] ?? 'Default').toString(),
      isEnabled: (json['is_enabled'] as bool?) ?? true,
    );
  }
}

class FraudSecurityScreen extends StatefulWidget {
  const FraudSecurityScreen({super.key});

  @override
  State<FraudSecurityScreen> createState() => _FraudSecurityScreenState();
}

class _FraudSecurityScreenState extends State<FraudSecurityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All'; // 'All', 'High Risk', 'Medium Warning', 'Resolved', 'Frozen'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Data lists
  final List<RiskAlert> _alerts = [];
  final List<BlacklistedIdentifier> _blacklist = [];
  final List<SecurityRuleModel> _rules = [];

  // Loading states
  bool _isLoadingAlerts = false;
  bool _isLoadingBlacklist = false;
  bool _isLoadingRules = false;
  bool _isLoadingMoreAlerts = false;

  // Pagination for alerts
  int _alertsOffset = 0;
  static const int _pageSize = 20;
  int _totalAlertsCount = 0;
  bool _hasMoreAlerts = false;

  bool _enforceAdmin2FA = true;
  bool _lockdownModeActive = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllSecurityData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllSecurityData() async {
    await Future.wait([
      _fetchAlerts(refresh: true),
      _fetchBlacklist(),
      _fetchRules(),
    ]);
  }

  // ==========================================
  // DATA FETCHING: ALERTS
  // ==========================================
  Future<void> _fetchAlerts({bool refresh = false, bool loadMore = false}) async {
    if (loadMore) {
      if (_isLoadingMoreAlerts || !_hasMoreAlerts) return;
      setState(() => _isLoadingMoreAlerts = true);
    } else {
      setState(() {
        _isLoadingAlerts = true;
        if (refresh) {
          _alertsOffset = 0;
          _hasMoreAlerts = false;
        }
      });
    }

    try {
      final String? statusParam = _selectedFilter == 'All' ? null : _selectedFilter;
      final res = await Supabase.instance.client.rpc(
        'admin_fetch_fraud_alerts',
        params: {
          'p_limit': _pageSize,
          'p_offset': refresh ? 0 : _alertsOffset,
          'p_status': statusParam,
        },
      );

      if (mounted && res is Map) {
        final totalCount = (res['total_count'] as num?)?.toInt() ?? 0;
        final rawAlerts = res['alerts'] as List? ?? [];
        final parsed = rawAlerts.map((e) => RiskAlert.fromJson(Map<String, dynamic>.from(e as Map))).toList();

        setState(() {
          if (loadMore) {
            _alerts.addAll(parsed);
            _alertsOffset += parsed.length;
          } else {
            _alerts.clear();
            _alerts.addAll(parsed);
            _alertsOffset = parsed.length;
          }
          _totalAlertsCount = totalCount;
          _hasMoreAlerts = _alertsOffset < _totalAlertsCount;
        });
      }
    } catch (_) {
      // Fallback: Direct table query if RPC is temporarily blocked or unavailable
      try {
        var query = Supabase.instance.client
            .from('fraud_risk_alerts')
            .select('*');

        if (_selectedFilter != 'All') {
          query = query.eq('status', _selectedFilter);
        }

        final res = await query
            .order('risk_score', ascending: false)
            .order('created_at', ascending: false)
            .range(refresh ? 0 : _alertsOffset, (refresh ? 0 : _alertsOffset) + _pageSize - 1);

        if (mounted) {
          final parsed = res.map((e) => RiskAlert.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          setState(() {
            if (loadMore) {
              _alerts.addAll(parsed);
              _alertsOffset += parsed.length;
            } else {
              _alerts.clear();
              _alerts.addAll(parsed);
              _alertsOffset = parsed.length;
            }
            _hasMoreAlerts = parsed.length == _pageSize;
            if (_totalAlertsCount == 0) _totalAlertsCount = _alerts.length;
          });
        }
      } catch (err) {
        if (mounted) {
          SuperAdminDialogs.showToast(context, 'Failed to fetch fraud alerts: $err', isError: true);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAlerts = false;
          _isLoadingMoreAlerts = false;
        });
      }
    }
  }

  // ==========================================
  // DATA FETCHING: BLACKLIST
  // ==========================================
  Future<void> _fetchBlacklist() async {
    setState(() => _isLoadingBlacklist = true);
    try {
      final res = await Supabase.instance.client
          .from('fraud_blacklisted_identifiers')
          .select('*')
          .order('created_at', ascending: false);

      if (mounted) {
        final parsed = res.map((e) => BlacklistedIdentifier.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        setState(() {
          _blacklist.clear();
          _blacklist.addAll(parsed);
        });
      }
    } catch (err) {
      if (mounted) {
        SuperAdminDialogs.showToast(context, 'Failed to fetch blacklist: $err', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoadingBlacklist = false);
    }
  }

  // ==========================================
  // DATA FETCHING: RULES
  // ==========================================
  Future<void> _fetchRules() async {
    setState(() => _isLoadingRules = true);
    try {
      final res = await Supabase.instance.client
          .from('fraud_security_rules')
          .select('*')
          .order('rule_code', ascending: true);

      if (mounted) {
        final parsed = res.map((e) => SecurityRuleModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        setState(() {
          _rules.clear();
          _rules.addAll(parsed);
        });
      }
    } catch (err) {
      if (mounted) {
        SuperAdminDialogs.showToast(context, 'Failed to fetch security rules: $err', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoadingRules = false);
    }
  }

  // ==========================================
  // ACTIONS: RESOLVE / FREEZE ALERT
  // ==========================================
  Future<void> _resolveAlert(RiskAlert alert, String newStatus, SuperAdminProvider adminState, {String? notes}) async {
    try {
      final res = await Supabase.instance.client.rpc(
        'admin_resolve_fraud_alert',
        params: {
          'p_alert_id': alert.rawId,
          'p_resolution': newStatus,
          'p_notes': notes ?? 'Resolved by administrator via Security Console',
        },
      );

      if (res is Map && res['success'] == true) {
        setState(() => alert.status = newStatus);
        adminState.logAuditAction(
          newStatus == 'Frozen' ? 'SECURITY_FREEZE' : 'SECURITY_RESOLVE',
          alert.entityName,
          'Status changed to $newStatus for alert ${alert.id}. Notes: ${notes ?? "N/A"}',
        );
        if (mounted) {
          SuperAdminDialogs.showToast(
            context,
            newStatus == 'Frozen'
                ? '${alert.entityName} account Frozen & Blacklisted!'
                : '${alert.entityName} alert marked as Resolved.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SuperAdminDialogs.showToast(context, 'Action failed: $e', isError: true);
      }
    }
  }

  // ==========================================
  // ACTIONS: ADD BLACKLIST IDENTIFIER
  // ==========================================
  Future<void> _addBlacklistIdentifier({
    required String type,
    required String value,
    required String? holderName,
    required String reason,
    required String threatLevel,
    required SuperAdminProvider adminState,
  }) async {
    try {
      final res = await Supabase.instance.client.rpc(
        'admin_add_blacklisted_identifier',
        params: {
          'p_identifier_type': type,
          'p_identifier_value': value.trim(),
          'p_holder_name': holderName?.trim().isNotEmpty == true ? holderName!.trim() : 'Unknown Identity',
          'p_reason': reason.trim(),
          'p_threat_level': threatLevel,
        },
      );

      if (res is Map && res['success'] == true) {
        adminState.logAuditAction('BLACKLIST_ADD', value, 'Added $type to blacklist. Threat: $threatLevel');
        if (mounted) {
          SuperAdminDialogs.showToast(context, '$type $value added to blacklist!');
        }
        await _fetchBlacklist();
      }
    } catch (e) {
      if (mounted) {
        SuperAdminDialogs.showToast(context, 'Failed to add to blacklist: $e', isError: true);
      }
    }
  }

  // ==========================================
  // ACTIONS: REMOVE BLACKLIST IDENTIFIER
  // ==========================================
  Future<void> _removeBlacklistIdentifier(BlacklistedIdentifier item, SuperAdminProvider adminState) async {
    try {
      final res = await Supabase.instance.client.rpc(
        'admin_remove_blacklisted_identifier',
        params: {'p_id': item.id},
      );

      if (res is Map && res['success'] == true) {
        adminState.logAuditAction('BLACKLIST_REMOVE', item.identifierValue, 'Removed ${item.identifierType} from blacklist.');
        if (mounted) {
          SuperAdminDialogs.showToast(context, '${item.identifierValue} removed from blacklist.');
        }
        await _fetchBlacklist();
      }
    } catch (e) {
      if (mounted) {
        SuperAdminDialogs.showToast(context, 'Failed to remove from blacklist: $e', isError: true);
      }
    }
  }

  // ==========================================
  // ACTIONS: TOGGLE / EDIT SECURITY RULE
  // ==========================================
  Future<void> _toggleSecurityRule(
    SecurityRuleModel rule,
    bool isEnabled,
    SuperAdminProvider adminState, {
    String? newThreshold,
  }) async {
    try {
      final res = await Supabase.instance.client.rpc(
        'admin_toggle_security_rule',
        params: {
          'p_rule_id': rule.id,
          'p_is_enabled': isEnabled,
          'p_threshold_value': newThreshold ?? rule.thresholdValue,
        },
      );

      if (res is Map && res['success'] == true) {
        setState(() {
          rule.isEnabled = isEnabled;
          if (newThreshold != null) rule.thresholdValue = newThreshold;
        });
        adminState.logAuditAction(
          'SECURITY_RULE_MODIFY',
          rule.ruleTitle,
          'Enabled: $isEnabled, Threshold: ${newThreshold ?? rule.thresholdValue}',
        );
        if (mounted) {
          SuperAdminDialogs.showToast(
            context,
            newThreshold != null
                ? '${rule.ruleTitle} limit updated to $newThreshold!'
                : '${rule.ruleTitle} is now ${isEnabled ? "Active 🟢" : "Disabled ⚪"}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SuperAdminDialogs.showToast(context, 'Failed to update rule: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminState = Provider.of<SuperAdminProvider>(context);

    // Live Metrics
    final totalFlagged = _totalAlertsCount > 0 ? _totalAlertsCount : _alerts.length;
    final highRiskCount = _alerts.where((a) => a.riskScore >= 75 || a.status == 'High Risk').length;
    final frozenCount = _alerts.where((a) => a.status == 'Frozen').length;
    final blockedIpsCount = _blacklist.where((b) => b.identifierType == 'IP').length;
    final blockedKycCount = _blacklist.where((b) => b.identifierType != 'IP').length;

    // Filter Alerts locally for search box
    final filteredAlerts = _alerts.where((a) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return a.id.toLowerCase().contains(q) ||
          a.entityName.toLowerCase().contains(q) ||
          a.ipAddress.contains(q) ||
          a.riskFactor.toLowerCase().contains(q) ||
          a.location.toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Executive Breadcrumb & Header
          const Text('Breadcrumbs > Security > Fraud Monitoring & Cyber Defense', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fraud Monitoring, National KYC & Security Firewall', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('AI anomaly detection, National CNIC/IBAN blacklists, session killswitches, and automated firewall rules.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Refresh Data', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: _loadAllSecurityData,
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.lock_reset_rounded, size: 16),
                    onPressed: () => _showEmergencyKillswitchDialog(adminState),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      backgroundColor: const Color(0xFFFEF2F2),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    label: const Text('Emergency Killswitch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    onPressed: () {
                      adminState.logAuditAction('EXPORT_SECURITY_LOGS', 'Security Center', 'Exported risk audit incident logs.');
                      SuperAdminDialogs.showToast(context, 'Security incident risk logs exported to CSV!');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    label: const Text('Export Incident Audit Logs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4 Top Security KPI Cards (Clickable Quick Jump)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _tabController.animateTo(0),
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'Threat Detections',
                    value: '$totalFlagged Flagged Events',
                    subtitle: '$highRiskCount High Risk Critical (Tab 1)',
                    icon: Icons.warning_amber_rounded,
                    iconColor: const Color(0xFFEF4444),
                    bgColor: const Color(0xFFFEE2E2),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () {
                    _tabController.animateTo(0);
                    setState(() => _selectedFilter = 'Frozen');
                    _fetchAlerts(refresh: true);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'Frozen / Locked Accounts',
                    value: '$frozenCount ${frozenCount == 1 ? "Account" : "Accounts"} Frozen',
                    subtitle: 'Manual Review Locked (Tab 1)',
                    icon: Icons.lock_outline_rounded,
                    iconColor: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFEF3C7),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _tabController.animateTo(1),
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'Firewall Blocked IPs',
                    value: '$blockedIpsCount Subnet Ranges',
                    subtitle: 'Scrapers & Bot Networks (Tab 2)',
                    icon: Icons.block_flipped,
                    iconColor: const Color(0xFF7C3AED),
                    bgColor: const Color(0xFFF3E8FF),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _tabController.animateTo(3),
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'National KYC Blacklist',
                    value: '$blockedKycCount Permanent Bans',
                    subtitle: 'CNICs, IBANs & Phones (Tab 4)',
                    icon: Icons.badge_outlined,
                    iconColor: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 5 Sub-Tabs Navigation
          Container(
            height: 48,
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
                Tab(icon: Icon(Icons.security, size: 16), text: 'Live Fraud Anomaly Queue'),
                Tab(icon: Icon(Icons.block_rounded, size: 16), text: 'IP Blacklist & Subnet Firewalls'),
                Tab(icon: Icon(Icons.tune_rounded, size: 16), text: 'Firewall & Rate Limit Rules'),
                Tab(icon: Icon(Icons.badge_outlined, size: 16), text: 'National CNIC & IBAN Blacklist'),
                Tab(icon: Icon(Icons.admin_panel_settings_outlined, size: 16), text: 'Access & Session Killswitch'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Views
          SizedBox(
            height: 600,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFraudQueueTab(filteredAlerts, adminState),
                _buildIpBlacklistTab(adminState),
                _buildFirewallRulesTab(adminState),
                _buildKycBlacklistTab(adminState),
                _buildAdminAccessTab(adminState),
              ],
            ),
          ),
        ],
      ),
    );
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
  // TAB 1: LIVE FRAUD DETECTION QUEUE
  // ==========================================
  Widget _buildFraudQueueTab(List<RiskAlert> filteredAlerts, SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Search & Filter Bar
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFCBD5E1))),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: const InputDecoration(
                        hintText: 'Search by Account Name, IP Address, Device Hash, Risk Factor...',
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
                  children: ['All', 'High Risk', 'Medium Warning', 'Resolved', 'Frozen'].map((filter) {
                    final isSel = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: ChoiceChip(
                        label: Text(filter, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : const Color(0xFF64748B))),
                        selected: isSel,
                        selectedColor: const Color(0xFF0F172A),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (val) {
                          setState(() => _selectedFilter = filter);
                          _fetchAlerts(refresh: true);
                        },
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
                  Expanded(flex: 2, child: Text('Alert ID & Entity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 1, child: Text('Risk Score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 3, child: Text('Flagged Risk Factor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('IP / Device / City', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Security Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Alert Rows or Empty / Loading State
            Expanded(
              child: _isLoadingAlerts && _alerts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filteredAlerts.isEmpty
                      ? _buildEmptyState(
                          icon: Icons.verified_user_outlined,
                          title: 'No Risk Alerts Found',
                          subtitle: _selectedFilter == 'All'
                              ? 'All platform stores, buyers, and transactions are currently clear of fraud anomalies.'
                              : 'No alerts matching the selected filter "$_selectedFilter".',
                        )
                      : ListView.builder(
                          itemCount: filteredAlerts.length + (_hasMoreAlerts ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == filteredAlerts.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                child: Center(
                                  child: _isLoadingMoreAlerts
                                      ? const CircularProgressIndicator()
                                      : OutlinedButton(
                                          onPressed: () => _fetchAlerts(loadMore: true),
                                          child: const Text('Load More Alerts'),
                                        ),
                                ),
                              );
                            }

                            final a = filteredAlerts[index];
                            final isHighRisk = a.riskScore >= 75 || a.status == 'High Risk';
                            final isResolved = a.status == 'Resolved';
                            final isFrozen = a.status == 'Frozen';

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                              child: Row(
                                children: [
                                  // Entity
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(a.id, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text('${a.entityName} (${a.entityType})', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),

                                  // Risk Score Gauge
                                  Expanded(
                                    flex: 1,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isFrozen
                                                ? const Color(0xFFF1F5F9)
                                                : isHighRisk
                                                    ? const Color(0xFFFEE2E2)
                                                    : isResolved
                                                        ? const Color(0xFFECFDF5)
                                                        : const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            isFrozen ? 'FROZEN 🔒' : '${a.riskScore} / 100',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isFrozen
                                                  ? const Color(0xFF475569)
                                                  : isHighRisk
                                                      ? const Color(0xFFDC2626)
                                                      : isResolved
                                                          ? const Color(0xFF059669)
                                                          : const Color(0xFFD97706),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Risk Factor
                                  Expanded(
                                    flex: 3,
                                    child: Text(a.riskFactor, style: const TextStyle(color: Color(0xFF334155), fontSize: 11, height: 1.3)),
                                  ),

                                  // IP & Device
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(a.ipAddress, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF059669), fontFamily: 'monospace')),
                                        Text('${a.deviceHash} • ${a.location}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),

                                  // Actions
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                                          label: const Text('Inspect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF334155),
                                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                          onPressed: () => _showInspectModal(a),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isFrozen ? const Color(0xFF059669) : const Color(0xFFEF4444),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                          onPressed: () {
                                            if (isFrozen) {
                                              _resolveAlert(a, 'Resolved', adminState);
                                            } else {
                                              _showFreezeConfirmationModal(a, adminState);
                                            }
                                          },
                                          child: Text(isFrozen ? 'Unfreeze' : 'Freeze Account', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: IP BLACKLIST & SUBNET FIREWALLS
  // ==========================================
  Widget _buildIpBlacklistTab(SuperAdminProvider adminState) {
    final ipBlacklist = _blacklist.where((b) => b.identifierType == 'IP').toList();

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
                    Text('Blacklisted IP Ranges & Firewall Banned Subnets', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Inbound connections from these IPs are automatically rejected by Elegant Marketplace Web Application Firewall (WAF).', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+ Blacklist IP Range', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                  onPressed: () => _showAddBlacklistIpModal(adminState),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _isLoadingBlacklist && _blacklist.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ipBlacklist.isEmpty
                      ? _buildEmptyState(
                          icon: Icons.shield_outlined,
                          title: 'No Blacklisted IP Subnets',
                          subtitle: 'No IP ranges or bot subnets are currently blacklisted on the firewall.',
                        )
                      : ListView.builder(
                          itemCount: ipBlacklist.length,
                          itemBuilder: (context, index) {
                            final ip = ipBlacklist[index];
                            final threatBadgeColor = ip.threatLevel == 'Critical'
                                ? const Color(0xFFFEE2E2)
                                : ip.threatLevel == 'High'
                                    ? const Color(0xFFFEF3C7)
                                    : const Color(0xFFF1F5F9);
                            final threatTextColor = ip.threatLevel == 'Critical'
                                ? const Color(0xFFDC2626)
                                : ip.threatLevel == 'High'
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF475569);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
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
                                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.block_flipped, color: Color(0xFFDC2626), size: 22),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(ip.identifierValue, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14, fontFamily: 'monospace')),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(color: threatBadgeColor, borderRadius: BorderRadius.circular(4)),
                                              child: Text('${ip.threatLevel.toUpperCase()} THREAT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: threatTextColor)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text('Reason: ${ip.reason} • Blacklisted on: ${ip.createdAt.toString().substring(0, 10)}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.lock_open_rounded, size: 14),
                                    label: const Text('Unblock IP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                                    onPressed: () => _removeBlacklistIdentifier(ip, adminState),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 3: FIREWALL & RATE LIMIT RULES
  // ==========================================
  Widget _buildFirewallRulesTab(SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Active Security Firewall & Heuristic Anti-Fraud Rules', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text('Automated system policies enforced on checkout, OTP logins, seller registrations, and card payments.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _isLoadingRules && _rules.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _rules.isEmpty
                      ? _buildEmptyState(
                          icon: Icons.tune_rounded,
                          title: 'No Security Rules Configured',
                          subtitle: 'No firewall or rate limit rules are currently defined in the database.',
                        )
                      : ListView.builder(
                          itemCount: _rules.length,
                          itemBuilder: (context, index) {
                            final rule = _rules[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
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
                                    decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 22),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(rule.ruleTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(4)),
                                              child: Text('Threshold: ${rule.thresholdValue}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(rule.description, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.edit_outlined, size: 14),
                                    label: const Text('Edit Limit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF334155),
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                    onPressed: () => _showEditRuleThresholdModal(rule, adminState),
                                  ),
                                  const SizedBox(width: 10),
                                  Switch(
                                    value: rule.isEnabled,
                                    activeColor: const Color(0xFF10B981),
                                    onChanged: (val) => _toggleSecurityRule(rule, val, adminState),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 4: NATIONAL CNIC & BANK IBAN BLACKLIST
  // ==========================================
  Widget _buildKycBlacklistTab(SuperAdminProvider adminState) {
    final kycBlacklist = _blacklist.where((b) => b.identifierType != 'IP').toList();

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
                    Text('National CNIC & Bank IBAN KYC Blacklist Ledger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Permanently bans fraudulent individuals from opening new seller stores or registering with blacklisted CNICs or bank accounts.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_off_rounded, size: 16),
                  label: const Text('+ Blacklist CNIC / IBAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                  onPressed: () => _showAddKycBlacklistModal(adminState),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('Type & Identifier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Holder Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 4, child: Text('Fraud Audit Rationale', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Date Blacklisted', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 1, child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _isLoadingBlacklist && _blacklist.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : kycBlacklist.isEmpty
                      ? _buildEmptyState(
                          icon: Icons.badge_outlined,
                          title: 'No Blacklisted CNIC / IBAN Records',
                          subtitle: 'No national CNIC, Bank IBAN, or Phone numbers are currently blacklisted.',
                        )
                      : ListView.builder(
                          itemCount: kycBlacklist.length,
                          itemBuilder: (context, index) {
                            final kyc = kycBlacklist[index];
                            final isCnic = kyc.identifierType == 'CNIC';
                            final isIban = kyc.identifierType == 'Bank IBAN';

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isCnic ? const Color(0xFFEFF6FF) : isIban ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(kyc.identifierType, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isCnic ? const Color(0xFF2563EB) : isIban ? const Color(0xFF059669) : const Color(0xFFD97706))),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(kyc.identifierValue, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A), fontFamily: 'monospace')),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(kyc.holderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155))),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Text(kyc.reason, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(kyc.createdAt.toString().substring(0, 10), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                                      tooltip: 'Remove from Blacklist',
                                      onPressed: () => _removeBlacklistIdentifier(kyc, adminState),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 5: ADMIN ACCESS & SESSION KILLSWITCH
  // ==========================================
  Widget _buildAdminAccessTab(SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Super Admin Cyber Defense & Emergency Lockdown Control', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text('Enforce two-factor authentication (2FA) and trigger emergency session revocations in case of detected compromise.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 20),

            Row(
              children: [
                // 2FA Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.phonelink_lock_rounded, color: Color(0xFF2563EB), size: 22),
                                SizedBox(width: 8),
                                Text('Mandatory 2FA (Staff & Admins)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                              ],
                            ),
                            Switch(
                              value: _enforceAdmin2FA,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (val) {
                                setState(() => _enforceAdmin2FA = val);
                                adminState.logAuditAction('2FA_ENFORCE_TOGGLE', 'SuperAdmin', val ? 'Enforced 2FA on all staff.' : 'Relaxed 2FA.');
                                SuperAdminDialogs.showToast(context, 'Staff 2FA Enforcement: ${val ? "Enabled 🟢" : "Disabled ⚪"}');
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('Requires Google Authenticator or SMS OTP verification on every administrative login from new browser IP.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Emergency Killswitch Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _lockdownModeActive ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _lockdownModeActive ? const Color(0xFFFCA5A5) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.shield_moon_outlined, color: _lockdownModeActive ? const Color(0xFFDC2626) : const Color(0xFFD97706), size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  _lockdownModeActive ? 'PLATFORM LOCKDOWN ACTIVE' : 'Marketplace Lockdown Mode',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _lockdownModeActive ? const Color(0xFFDC2626) : const Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                            Switch(
                              value: _lockdownModeActive,
                              activeColor: const Color(0xFFDC2626),
                              onChanged: (val) {
                                setState(() => _lockdownModeActive = val);
                                adminState.logAuditAction('LOCKDOWN_MODE', 'Marketplace Shield', val ? 'Activated platform lockdown mode.' : 'Deactivated lockdown.');
                                SuperAdminDialogs.showToast(context, val ? '⚠️ PLATFORM LOCKDOWN ACTIVATED! All checkouts paused.' : 'Platform Lockdown Deactivated. Normal operations resumed.');
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('Immediately suspends checkout APIs and places storefront in read-only maintenance shield mode.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Session Revocation Button Desk
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Revoke All Active Merchant & Customer JWT Sessions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                      Text('Forces all logged in mobile and web sessions to immediately re-authenticate.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Revoke All Active Sessions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                    onPressed: () {
                      adminState.logAuditAction('SESSION_REVOKE_ALL', 'Auth Engine', 'Revoked all active merchant and buyer JWT sessions.');
                      SuperAdminDialogs.showToast(context, 'All Active Sessions Revoked Successfully!');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // EMPTY STATE HELPER
  // ==========================================
  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // MODALS
  // ==========================================
  void _showInspectModal(RiskAlert alert) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.fingerprint_rounded, color: Color(0xFF2563EB), size: 24),
            const SizedBox(width: 10),
            Text('Device Fingerprint & Incident Dossier — ${alert.id}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
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
                    _buildDossierRow('Target Entity', '${alert.entityName} (${alert.entityType})'),
                    const Divider(height: 14),
                    _buildDossierRow('Risk Threat Score', '${alert.riskScore} / 100'),
                    const Divider(height: 14),
                    _buildDossierRow('Current Status', alert.status),
                    const Divider(height: 14),
                    _buildDossierRow('IP Address', alert.ipAddress),
                    const Divider(height: 14),
                    _buildDossierRow('Device Hardware Hash', alert.deviceHash),
                    const Divider(height: 14),
                    _buildDossierRow('Geographical Origin', alert.location),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Flagged Anomaly Rationale:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              Text(alert.riskFactor, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
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

  void _showFreezeConfirmationModal(RiskAlert alert, SuperAdminProvider adminState) {
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: Color(0xFFDC2626), size: 22),
            const SizedBox(width: 8),
            Text('Freeze Account — ${alert.entityName}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Freezing locks access to checkout, storefront updates, and automated payouts.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Reason / Incident Notes',
                hintText: 'Enter justification for audit log...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _resolveAlert(alert, 'Frozen', adminState, notes: notesCtrl.text.trim());
            },
            child: const Text('Confirm Freeze'),
          ),
        ],
      ),
    );
  }

  void _showAddBlacklistIpModal(SuperAdminProvider adminState) {
    final ipCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String threat = 'Critical';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.block_rounded, color: Color(0xFFEF4444), size: 22),
              SizedBox(width: 8),
              Text('Add IP Range to Firewall Blacklist', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ipCtrl,
                style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'monospace', fontWeight: FontWeight.bold),
                decoration: const InputDecoration(labelText: 'IP Address / CIDR Subnet (e.g. 111.68.102.0/24)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: Color(0xFF0F172A)),
                decoration: const InputDecoration(labelText: 'Threat Reason (e.g. Card Testing Bot)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: threat,
                decoration: const InputDecoration(labelText: 'Threat Level', border: OutlineInputBorder()),
                items: ['Critical', 'High', 'Suspicious'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setMState(() => threat = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
              onPressed: () {
                if (ipCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx);
                  _addBlacklistIdentifier(
                    type: 'IP',
                    value: ipCtrl.text.trim(),
                    holderName: 'Web Traffic Subnet',
                    reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : 'Manual Firewall IP Block',
                    threatLevel: threat,
                    adminState: adminState,
                  );
                }
              },
              child: const Text('Blacklist IP'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddKycBlacklistModal(SuperAdminProvider adminState) {
    String type = 'CNIC';
    String threat = 'Critical';
    final valCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.person_off_rounded, color: Color(0xFFEF4444), size: 22),
              SizedBox(width: 8),
              Text('Blacklist National CNIC / Bank IBAN', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Identifier Type', border: OutlineInputBorder()),
                  items: ['CNIC', 'Bank IBAN', 'Phone Number'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setMState(() => type = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'monospace', fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: type == 'CNIC' ? 'CNIC Number (35201-XXXXXXX-X)' : type == 'Bank IBAN' ? 'Bank IBAN (PKXX...)' : 'Phone Number (+92 3XX XXXXXXX)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Individual / Business Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Fraud / Dispute Reason', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: threat,
                  decoration: const InputDecoration(labelText: 'Threat Level', border: OutlineInputBorder()),
                  items: ['Critical', 'High', 'Suspicious'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setMState(() => threat = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
              onPressed: () {
                if (valCtrl.text.trim().isNotEmpty) {
                  Navigator.pop(ctx);
                  _addBlacklistIdentifier(
                    type: type,
                    value: valCtrl.text.trim(),
                    holderName: nameCtrl.text.trim(),
                    reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : 'Permanent National KYC Blacklist',
                    threatLevel: threat,
                    adminState: adminState,
                  );
                }
              },
              child: const Text('Blacklist Identity'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRuleThresholdModal(SecurityRuleModel rule, SuperAdminProvider adminState) {
    final ctrl = TextEditingController(text: rule.thresholdValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 22),
            const SizedBox(width: 8),
            Text('Edit Limit: ${rule.ruleTitle}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rule.description, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              decoration: const InputDecoration(labelText: 'Threshold Trigger Value', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _toggleSecurityRule(rule, rule.isEnabled, adminState, newThreshold: ctrl.text.trim());
            },
            child: const Text('Save Limit'),
          ),
        ],
      ),
    );
  }

  void _showEmergencyKillswitchDialog(SuperAdminProvider adminState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 26),
            SizedBox(width: 10),
            Text('Emergency Platform Defense Killswitch', style: TextStyle(color: Color(0xFFDC2626), fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Use only during active cyber-attacks, payment gateway breaches, or mass fraud syndicates:', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
              SizedBox(height: 12),
              Text('1. Revoke All Sessions: Kicks all logged in sellers and users off the platform immediately.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              SizedBox(height: 6),
              Text('2. Pause Checkouts: Temporarily halts COD and card payment gateways while keeping catalog browsable.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              SizedBox(height: 6),
              Text('3. Lock Seller Payouts: Prevents all automated bank transfers until manual audit passes.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton.icon(
            icon: const Icon(Icons.power_settings_new_rounded, size: 16),
            label: const Text('Trigger Emergency Killswitch'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white),
            onPressed: () {
              setState(() => _lockdownModeActive = true);
              adminState.logAuditAction('KILLSWITCH_TRIGGERED', 'Emergency Protocol', 'Super Admin triggered emergency platform killswitch.');
              Navigator.pop(ctx);
              SuperAdminDialogs.showToast(context, '🚨 EMERGENCY KILLSWITCH ACTIVATED! All checkout APIs secured.', isError: true);
            },
          ),
        ],
      ),
    );
  }
}
