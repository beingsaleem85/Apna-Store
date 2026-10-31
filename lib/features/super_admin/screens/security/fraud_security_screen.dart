import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';

class RiskAlert {
  final String id;
  final String entityName; // Store or Buyer Name
  final String entityType; // 'Store' or 'Buyer'
  final int riskScore; // 0 to 100
  final String riskFactor;
  final String ipAddress;
  final String deviceHash;
  final String location;
  String status; // 'High Risk', 'Medium Warning', 'Resolved', 'Frozen'

  RiskAlert({
    required this.id,
    required this.entityName,
    required this.entityType,
    required this.riskScore,
    required this.riskFactor,
    required this.ipAddress,
    required this.deviceHash,
    required this.location,
    this.status = 'High Risk',
  });
}

class BlacklistedIp {
  final String ipRange;
  final String reason;
  final String addedOn;
  final String threatLevel;

  BlacklistedIp({
    required this.ipRange,
    required this.reason,
    required this.addedOn,
    required this.threatLevel,
  });
}

class BlacklistedKyc {
  final String id;
  final String identifierType; // 'CNIC' or 'Bank IBAN' or 'Phone Number'
  final String identifierValue;
  final String holderName;
  final String fraudReason;
  final String blacklistedDate;

  BlacklistedKyc({
    required this.id,
    required this.identifierType,
    required this.identifierValue,
    required this.holderName,
    required this.fraudReason,
    required this.blacklistedDate,
  });
}

class SecurityRuleModel {
  final String id;
  final String ruleTitle;
  final String description;
  String thresholdValue;
  bool isEnabled;

  SecurityRuleModel({
    required this.id,
    required this.ruleTitle,
    required this.description,
    required this.thresholdValue,
    this.isEnabled = true,
  });
}

class FraudSecurityScreen extends StatefulWidget {
  const FraudSecurityScreen({super.key});

  @override
  State<FraudSecurityScreen> createState() => _FraudSecurityScreenState();
}

class _FraudSecurityScreenState extends State<FraudSecurityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All'; // 'All', 'High Risk', 'Medium Warning', 'Resolved'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<RiskAlert> _alerts = [
    RiskAlert(
      id: 'RISK-801',
      entityName: 'Merchant Store ST-8902',
      entityType: 'Store',
      riskScore: 88,
      riskFactor: 'Self-buying detected: 12 orders placed from same WiFi IP & Device Hash.',
      ipAddress: '111.68.102.45',
      deviceHash: 'DEV-F771A29B',
      location: 'Lahore, Pakistan',
      status: 'High Risk',
    ),
    RiskAlert(
      id: 'RISK-802',
      entityName: 'Usman Tariq',
      entityType: 'Buyer',
      riskScore: 65,
      riskFactor: 'Multi-account card recycling: 4 accounts registered with same credit card.',
      ipAddress: '182.185.12.90',
      deviceHash: 'DEV-E334B11C',
      location: 'Karachi, Pakistan',
      status: 'Medium Warning',
    ),
    RiskAlert(
      id: 'RISK-803',
      entityName: 'Super Mart Lahore',
      entityType: 'Store',
      riskScore: 20,
      riskFactor: 'Unusual spike in order velocity during 11.11 flash sale.',
      ipAddress: '39.40.10.15',
      deviceHash: 'DEV-A990C44D',
      location: 'Faisalabad, Pakistan',
      status: 'Resolved',
    ),
    RiskAlert(
      id: 'RISK-804',
      entityName: 'Quick Dealz PK',
      entityType: 'Store',
      riskScore: 92,
      riskFactor: 'Fake COD deliveries with abnormal 95% return claims submitted.',
      ipAddress: '175.107.199.12',
      deviceHash: 'DEV-B118C99F',
      location: 'Rawalpindi, Pakistan',
      status: 'High Risk',
    ),
  ];

  final List<BlacklistedIp> _blacklistedIps = [
    BlacklistedIp(ipRange: '111.68.102.0/24', reason: 'Automated Bot Cart Hoarding & Scraping', addedOn: '2026-08-28', threatLevel: 'CRITICAL 🔴'),
    BlacklistedIp(ipRange: '182.185.12.90', reason: 'Multiple Stolen Card Testing & Chargebacks', addedOn: '2026-08-25', threatLevel: 'HIGH 🟠'),
    BlacklistedIp(ipRange: '45.143.200.0/22', reason: 'Anonymous VPN / TOR Proxy Gateway', addedOn: '2026-08-20', threatLevel: 'MEDIUM 🟡'),
  ];

  final List<BlacklistedKyc> _blacklistedKycs = [
    BlacklistedKyc(
      id: 'KYC-BL-101',
      identifierType: 'CNIC',
      identifierValue: '35201-8745129-3',
      holderName: 'Muhammad Kamran',
      fraudReason: 'Counterfeit branded goods distribution & repeated customer scam.',
      blacklistedDate: '2026-08-20',
    ),
    BlacklistedKyc(
      id: 'KYC-BL-102',
      identifierType: 'Bank IBAN',
      identifierValue: 'PK36MEZN0001234567890102',
      holderName: 'Apex Electronics Hub',
      fraudReason: 'Payment chargeback syndicate & money laundering flag.',
      blacklistedDate: '2026-08-22',
    ),
    BlacklistedKyc(
      id: 'KYC-BL-103',
      identifierType: 'Phone Number',
      identifierValue: '+92 301 9876543',
      holderName: 'Babar Ali',
      fraudReason: 'Rapid OTP SMS spoofing and automated promotional voucher abuse.',
      blacklistedDate: '2026-08-27',
    ),
  ];

  final List<SecurityRuleModel> _firewallRules = [
    SecurityRuleModel(
      id: 'RULE-01',
      ruleTitle: 'OTP Brute-Force Rate Limiting',
      description: 'Automatically lock phone number for 30 minutes after 3 consecutive failed OTP attempts.',
      thresholdValue: '3 Attempts / 10 Mins',
      isEnabled: true,
    ),
    SecurityRuleModel(
      id: 'RULE-02',
      ruleTitle: 'Self-Buying & Review Manipulation Guard',
      description: 'Block checkout if seller and buyer share identical IP subnet or browser fingerprint.',
      thresholdValue: 'Same IP & Device Match',
      isEnabled: true,
    ),
    SecurityRuleModel(
      id: 'RULE-03',
      ruleTitle: 'High-Velocity COD Order Velocity Throttling',
      description: 'Flag buyer account for manual review if placing more than 5 COD orders within 1 hour.',
      thresholdValue: '5 Orders / Hour Max',
      isEnabled: true,
    ),
    SecurityRuleModel(
      id: 'RULE-04',
      ruleTitle: 'Anonymous Proxy & TOR Exit Node Blocking',
      description: 'Block all transactions originating from recognized international VPN data center IPs.',
      thresholdValue: 'Global VPN Blacklist',
      isEnabled: true,
    ),
  ];

  bool _enforceAdmin2FA = true;
  bool _lockdownModeActive = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = Provider.of<SuperAdminProvider>(context);

    // Metrics
    final highRiskCount = _alerts.where((a) => a.status == 'High Risk').length;
    final frozenCount = _alerts.where((a) => a.status == 'Frozen').length;

    // Filter Alerts
    final filteredAlerts = _alerts.where((a) {
      final matchesSearch = a.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.entityName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.ipAddress.contains(_searchQuery) ||
          a.riskFactor.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (_selectedFilter == 'High Risk') return a.status == 'High Risk';
      if (_selectedFilter == 'Medium Warning') return a.status == 'Medium Warning';
      if (_selectedFilter == 'Resolved') return a.status == 'Resolved';
      return true;
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
                    value: '${_alerts.length} Flagged Events',
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
                    setState(() => _selectedFilter = 'All');
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
                    value: '${_blacklistedIps.length} Subnet Ranges',
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
                    value: '${_blacklistedKycs.length} Permanent Bans',
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
                  children: ['All', 'High Risk', 'Medium Warning', 'Resolved'].map((filter) {
                    final isSel = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6.0),
                      child: ChoiceChip(
                        label: Text(filter, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : const Color(0xFF64748B))),
                        selected: isSel,
                        selectedColor: const Color(0xFF0F172A),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (val) => setState(() => _selectedFilter = filter),
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

            // Alert Rows
            Expanded(
              child: ListView.builder(
                itemCount: filteredAlerts.length,
                itemBuilder: (context, index) {
                  final a = filteredAlerts[index];
                  final isHighRisk = a.riskScore >= 75;
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
                                  setState(() {
                                    if (isFrozen) {
                                      a.status = 'Resolved';
                                      adminState.logAuditAction('SECURITY_UNFREEZE', a.entityName, 'Unlocked user account.');
                                      SuperAdminDialogs.showToast(context, '${a.entityName} account has been Unfrozen & Restored.');
                                    } else {
                                      a.status = 'Frozen';
                                      adminState.logAuditAction('SECURITY_FREEZE', a.entityName, 'Locked account for fraud review.');
                                      SuperAdminDialogs.showToast(context, '${a.entityName} account Frozen & Blacklisted!');
                                    }
                                  });
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
                    Text('Inbound connections from these IPs are automatically rejected by Apna Store Web Application Firewall (WAF).', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
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
              child: ListView.builder(
                itemCount: _blacklistedIps.length,
                itemBuilder: (context, index) {
                  final ip = _blacklistedIps[index];
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
                                  Text(ip.ipRange, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14, fontFamily: 'monospace')),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                    child: Text(ip.threatLevel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('Reason: ${ip.reason} • Blacklisted on: ${ip.addedOn}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.lock_open_rounded, size: 14),
                          label: const Text('Unblock IP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                          onPressed: () {
                            setState(() => _blacklistedIps.removeWhere((i) => i.ipRange == ip.ipRange));
                            adminState.logAuditAction('FIREWALL_UNBLOCK_IP', ip.ipRange, 'Unblocked IP range from firewall.');
                            SuperAdminDialogs.showToast(context, 'IP ${ip.ipRange} has been unblocked.');
                          },
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
              child: ListView.builder(
                itemCount: _firewallRules.length,
                itemBuilder: (context, index) {
                  final rule = _firewallRules[index];
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
                          onChanged: (val) {
                            setState(() => rule.isEnabled = val);
                            adminState.logAuditAction('RULE_TOGGLE', rule.ruleTitle, val ? 'Enabled security rule.' : 'Disabled security rule.');
                            SuperAdminDialogs.showToast(context, '${rule.ruleTitle} is now ${val ? "Active 🟢" : "Disabled ⚪"}');
                          },
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
              child: ListView.builder(
                itemCount: _blacklistedKycs.length,
                itemBuilder: (context, index) {
                  final kyc = _blacklistedKycs[index];
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
                          child: Text(kyc.fraudReason, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(kyc.blacklistedDate, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ),
                        Expanded(
                          flex: 1,
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                            tooltip: 'Remove from Blacklist',
                            onPressed: () {
                              setState(() => _blacklistedKycs.removeWhere((k) => k.id == kyc.id));
                              adminState.logAuditAction('KYC_UNBAN', kyc.identifierValue, 'Removed CNIC/IBAN from KYC blacklist.');
                              SuperAdminDialogs.showToast(context, '${kyc.identifierValue} removed from blacklist.');
                            },
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
                      Text('Forces all 1,200+ logged in mobile and web sessions to immediately re-authenticate.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text('Revoke All Active Sessions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                    onPressed: () {
                      adminState.logAuditAction('SESSION_REVOKE_ALL', 'Auth Engine', 'Revoked all active merchant and buyer JWT sessions.');
                      SuperAdminDialogs.showToast(context, 'All 1,240 Active Sessions Revoked Successfully!');
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
  // MODALS WITH CLEAN LIGHT THEME (NO CONTRAST BUGS)
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
                    _buildDossierRow('Risk Threat Score', '${alert.riskScore} / 100 (Heuristic AI Flag)'),
                    const Divider(height: 14),
                    _buildDossierRow('IP Address & ISP', '${alert.ipAddress} (PTCL Fiber / Nayatel)'),
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

  void _showAddBlacklistIpModal(SuperAdminProvider adminState) {
    final ipCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            onPressed: () {
              if (ipCtrl.text.isNotEmpty) {
                setState(() {
                  _blacklistedIps.add(BlacklistedIp(
                    ipRange: ipCtrl.text.trim(),
                    reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : 'Manual Administrator Block',
                    addedOn: DateTime.now().toString().substring(0, 10),
                    threatLevel: 'CRITICAL 🔴',
                  ));
                });
                adminState.logAuditAction('FIREWALL_ADD_IP', ipCtrl.text, 'Blacklisted IP on firewall.');
                Navigator.pop(ctx);
                SuperAdminDialogs.showToast(context, 'IP ${ipCtrl.text} Added to Firewall Blacklist!');
              }
            },
            child: const Text('Blacklist IP'),
          ),
        ],
      ),
    );
  }

  void _showAddKycBlacklistModal(SuperAdminProvider adminState) {
    String type = 'CNIC';
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
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
              onPressed: () {
                if (valCtrl.text.isNotEmpty) {
                  setState(() {
                    _blacklistedKycs.add(BlacklistedKyc(
                      id: 'KYC-BL-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                      identifierType: type,
                      identifierValue: valCtrl.text.trim(),
                      holderName: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : 'Unknown Identity',
                      fraudReason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : 'Fraud Syndicate Activity',
                      blacklistedDate: DateTime.now().toString().substring(0, 10),
                    ));
                  });
                  adminState.logAuditAction('KYC_BLACKLIST_ADD', valCtrl.text, 'Added $type to permanent blacklist.');
                  Navigator.pop(ctx);
                  SuperAdminDialogs.showToast(context, '$type ${valCtrl.text} Permanently Blacklisted!');
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
              setState(() => rule.thresholdValue = ctrl.text.trim());
              adminState.logAuditAction('RULE_THRESHOLD_EDIT', rule.ruleTitle, 'Updated threshold to ${ctrl.text}');
              Navigator.pop(ctx);
              SuperAdminDialogs.showToast(context, '${rule.ruleTitle} threshold updated!');
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
              Text('1. Revoke All Sessions: Kicks all 1,200+ logged in sellers and users off the platform immediately.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
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

