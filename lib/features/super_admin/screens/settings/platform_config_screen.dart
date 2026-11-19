import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';

class GatewayIntegrationItem {
  final String id;
  final String providerKey;
  final String name;
  final String category; // 'Payments', 'Logistics', 'SMS & OTP', 'Cloud & DB', 'Tax & FBR'
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  bool isEnabled;
  String status; // 'Configured' or 'Not configured'
  String latency;

  GatewayIntegrationItem({
    required this.id,
    required this.providerKey,
    required this.name,
    required this.category,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    this.isEnabled = false,
    this.status = 'Not configured',
    this.latency = '14ms',
  });
}

class PlatformConfigScreen extends StatefulWidget {
  final int initialTabIndex;
  const PlatformConfigScreen({super.key, this.initialTabIndex = 0});

  @override
  State<PlatformConfigScreen> createState() => _PlatformConfigScreenState();
}

class _PlatformConfigScreenState extends State<PlatformConfigScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // System Settings Controllers
  final TextEditingController _appNameController = TextEditingController(text: 'Elegant Marketplace Pakistan');
  final TextEditingController _supportEmailController = TextEditingController(text: 'support@apnastore.pk');
  final TextEditingController _supportPhoneController = TextEditingController(text: '+92 42 111 276 276');
  final TextEditingController _baseCurrencyController = TextEditingController(text: 'PKR (Rs.)');
  final TextEditingController _defaultShippingFeeController = TextEditingController(text: '199');
  final TextEditingController _freeShippingThresholdController = TextEditingController(text: '2999');
  final TextEditingController _minWithdrawalController = TextEditingController(text: '1000');
  final TextEditingController _fbrTaxRateController = TextEditingController(text: '18.0');

  // Feature Flags
  bool _allowSellerRegistration = true;
  bool _enableBuyerWallet = true;
  bool _allowCodPayment = true;
  bool _autoApproveVerifiedMerchants = false;
  bool _enforceBuyerOtp = true;
  bool _maintenanceMode = false;

  // Filter for Integrations
  String _selectedCategory = 'All';

  // Pakistani Integrations Ecosystem (Strictly zero secrets stored client-side)
  final List<GatewayIntegrationItem> _integrations = [
    // Payment Gateways
    GatewayIntegrationItem(
      id: 'INT-PAY-01',
      providerKey: 'easypaisa',
      name: 'EasyPaisa Merchant API',
      category: 'Payments',
      description: 'Instant mobile wallet, MPIN debit & QR payments via Telenor Microfinance Bank.',
      icon: Icons.account_balance_wallet_rounded,
      iconColor: const Color(0xFF059669),
      bgColor: const Color(0xFFECFDF5),
      status: 'Configured',
      isEnabled: true,
      latency: '18ms',
    ),
    GatewayIntegrationItem(
      id: 'INT-PAY-02',
      providerKey: 'jazzcash',
      name: 'JazzCash Direct Merchant Gateway',
      category: 'Payments',
      description: 'Mobilink Microfinance Bank wallet checkouts, OTC vouchers & direct account debits.',
      icon: Icons.phone_iphone_rounded,
      iconColor: const Color(0xFFDC2626),
      bgColor: const Color(0xFFFEE2E2),
      status: 'Configured',
      isEnabled: true,
      latency: '22ms',
    ),
    GatewayIntegrationItem(
      id: 'INT-PAY-03',
      providerKey: 'onelink',
      name: '1-Link PayFast & HBL CyberSource',
      category: 'Payments',
      description: 'Direct Pakistani Inter-Bank Settlement (IBFT), PayPak, Visa & Mastercard processing.',
      icon: Icons.credit_card_rounded,
      iconColor: const Color(0xFF2563EB),
      bgColor: const Color(0xFFEFF6FF),
      status: 'Configured',
      isEnabled: true,
      latency: '12ms',
    ),
    GatewayIntegrationItem(
      id: 'INT-PAY-04',
      providerKey: 'stripe_card',
      name: 'Stripe International Gateway',
      category: 'Payments',
      description: 'Overseas Pakistani credit/debit card checkouts, USD conversion & Apple/Google Pay.',
      icon: Icons.language_rounded,
      iconColor: const Color(0xFF7C3AED),
      bgColor: const Color(0xFFF3E8FF),
      status: 'Not configured',
      isEnabled: false,
      latency: '85ms',
    ),

    // Logistics & Couriers
    GatewayIntegrationItem(
      id: 'INT-LOG-01',
      providerKey: 'tcs',
      name: 'TCS Express API (E-COM API)',
      category: 'Logistics',
      description: 'Automated consignment booking, electronic Air Waybill (AWB) slips & live tracking.',
      icon: Icons.local_shipping_rounded,
      iconColor: const Color(0xFFEA580C),
      bgColor: const Color(0xFFFFEDD5),
      status: 'Configured',
      isEnabled: true,
      latency: '24ms',
    ),
    GatewayIntegrationItem(
      id: 'INT-LOG-02',
      providerKey: 'leopard',
      name: 'Leopards Courier Webhook Engine',
      category: 'Logistics',
      description: 'Nationwide Cash on Delivery (COD) dispatch, doorstep pickup & delivery OTP receipts.',
      icon: Icons.directions_boat_filled_rounded,
      iconColor: const Color(0xFFD97706),
      bgColor: const Color(0xFFFEF3C7),
      status: 'Configured',
      isEnabled: true,
      latency: '31ms',
    ),
    GatewayIntegrationItem(
      id: 'INT-LOG-03',
      providerKey: 'trax',
      name: 'Trax Logistics & PostEx COD Portal',
      category: 'Logistics',
      description: 'Instant same-day urban courier delivery with automated return parcel management.',
      icon: Icons.electric_moped_rounded,
      iconColor: const Color(0xFF0284C7),
      bgColor: const Color(0xFFE0F2FE),
      status: 'Configured',
      isEnabled: true,
      latency: '19ms',
    ),

    // SMS & Communications
    GatewayIntegrationItem(
      id: 'INT-SMS-01',
      providerKey: 'sms_gateway',
      name: 'Telenor & Zong Bulk SMS Gateway',
      category: 'SMS & OTP',
      description: 'PTA-compliant masked promotional SMS & instant 6-digit login/order verification OTPs.',
      icon: Icons.sms_rounded,
      iconColor: const Color(0xFF059669),
      bgColor: const Color(0xFFECFDF5),
      status: 'Configured',
      isEnabled: true,
      latency: '15ms',
    ),

    // Cloud Database & Storage
    GatewayIntegrationItem(
      id: 'INT-DB-01',
      providerKey: 'supabase_db',
      name: 'Supabase PostgreSQL & Realtime DB',
      category: 'Cloud & DB',
      description: 'High-speed relational PostgreSQL backend with row-level security (RLS) & WebSockets.',
      icon: Icons.storage_rounded,
      iconColor: const Color(0xFF10B981),
      bgColor: const Color(0xFFECFDF5),
      status: 'Configured',
      isEnabled: true,
      latency: '8ms',
    ),
    GatewayIntegrationItem(
      id: 'INT-DB-02',
      providerKey: 's3_storage',
      name: 'AWS S3 & Cloudflare Image CDN',
      category: 'Cloud & DB',
      description: 'Encrypted object storage for high-resolution seller product photos, videos & KYC CNIC scans.',
      icon: Icons.cloud_done_rounded,
      iconColor: const Color(0xFF2563EB),
      bgColor: const Color(0xFFEFF6FF),
      status: 'Configured',
      isEnabled: true,
      latency: '11ms',
    ),

    // FBR Tax & Compliance
    GatewayIntegrationItem(
      id: 'INT-TAX-01',
      providerKey: 'fbr_pos',
      name: 'FBR Digital Invoicing (POS Integration)',
      category: 'Tax & FBR',
      description: 'Official Federal Board of Revenue real-time sales tax reporting & digital invoice QR stamping.',
      icon: Icons.receipt_long_rounded,
      iconColor: const Color(0xFF0F172A),
      bgColor: const Color(0xFFF1F5F9),
      status: 'Configured',
      isEnabled: true,
      latency: '45ms',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _appNameController.dispose();
    _supportEmailController.dispose();
    _supportPhoneController.dispose();
    _baseCurrencyController.dispose();
    _defaultShippingFeeController.dispose();
    _freeShippingThresholdController.dispose();
    _minWithdrawalController.dispose();
    _fbrTaxRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = Provider.of<SuperAdminProvider>(context);

    final filteredIntegrations = _selectedCategory == 'All'
        ? _integrations
        : _integrations.where((i) => i.category == _selectedCategory).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumbs & Header
          const Text('Breadcrumbs > System > Platform Configuration & Integrations', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tabController.index == 0 ? 'Platform Settings & Feature Flags' : 'Third-Party APIs & Gateway Integrations',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Centralized administration for marketplace parameters, payment APIs, courier webhooks, and core feature flags.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reset Defaults', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () {
                      SuperAdminDialogs.showToast(context, 'System parameters reloaded to factory defaults.');
                    },
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded, size: 16),
                    label: const Text('Save All Settings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () {
                      adminState.logAuditAction('PLATFORM_CONFIG_SAVE', 'System Settings', 'Saved all global marketplace parameters and feature flags.');
                      SuperAdminDialogs.showToast(context, 'All Platform Settings & Integrations Saved Successfully!');
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Clickable Metric KPI Cards
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    _tabController.animateTo(1);
                    setState(() => _selectedCategory = 'All');
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'Active Gateways',
                    value: '${_integrations.where((i) => i.status.contains("Connected")).length} / ${_integrations.length} Connected',
                    subtitle: 'Click to view All APIs (Tab 2)',
                    icon: Icons.hub_rounded,
                    iconColor: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  onTap: () {
                    _tabController.animateTo(1);
                    setState(() => _selectedCategory = 'Payments');
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'Payment Gateways',
                    value: '4 Channels Active',
                    subtitle: 'EasyPaisa, JazzCash, 1Link (Tab 2)',
                    icon: Icons.payments_rounded,
                    iconColor: const Color(0xFF059669),
                    bgColor: const Color(0xFFECFDF5),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  onTap: () {
                    _tabController.animateTo(1);
                    setState(() => _selectedCategory = 'Logistics');
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'Couriers Integrated',
                    value: '3 Major Couriers',
                    subtitle: 'TCS, Leopards & Trax (Tab 2)',
                    icon: Icons.local_shipping_rounded,
                    iconColor: const Color(0xFFEA580C),
                    bgColor: const Color(0xFFFFEDD5),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  onTap: () => _tabController.animateTo(0),
                  borderRadius: BorderRadius.circular(10),
                  child: _buildMetricCard(
                    title: 'System Health',
                    value: _maintenanceMode ? 'MAINTENANCE ⚠️' : '100% OPERATIONAL',
                    subtitle: 'Click to configure (Tab 1)',
                    icon: _maintenanceMode ? Icons.warning_amber_rounded : Icons.verified_rounded,
                    iconColor: _maintenanceMode ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                    bgColor: _maintenanceMode ? const Color(0xFFFEE2E2) : const Color(0xFFECFDF5),
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
                Tab(icon: Icon(Icons.settings_suggest_rounded, size: 16), text: 'System Settings & Core Marketplace Flags'),
                Tab(icon: Icon(Icons.hub_rounded, size: 16), text: 'Third-Party APIs & Payment Gateways'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Dynamic Tab Content
          if (_tabController.index == 0)
            _buildSystemSettingsTab(adminState)
          else
            _buildIntegrationsTab(filteredIntegrations, adminState),
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
  // TAB 1: SYSTEM SETTINGS & FEATURE FLAGS
  // ==========================================
  Widget _buildSystemSettingsTab(SuperAdminProvider adminState) {
    return Column(
      children: [
        // Two Column Grid: Identity & Financial
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Card: Marketplace Identity
            Expanded(
              child: Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.storefront_rounded, color: Color(0xFF2563EB), size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Marketplace Identity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              Text('Public business credentials & contact channels', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      TextField(
                        controller: _appNameController,
                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'Marketplace Application Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge_outlined, size: 18)),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: _baseCurrencyController,
                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'Base Currency', border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_exchange_rounded, size: 18)),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: _supportEmailController,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                        decoration: const InputDecoration(labelText: 'Public Support Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined, size: 18)),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: _supportPhoneController,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                        decoration: const InputDecoration(labelText: 'UAN / WhatsApp Helpline', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_in_talk_outlined, size: 18)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Right Card: Financial, Shipping & Tax
            Expanded(
              child: Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.account_balance_rounded, color: Color(0xFF059669), size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Financial, Shipping & Tax Rules', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              Text('Default delivery fees & FBR GST thresholds', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      TextField(
                        controller: _defaultShippingFeeController,
                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'Default Shipping Fee (Rs.)', prefixText: 'Rs. ', border: OutlineInputBorder(), prefixIcon: Icon(Icons.local_shipping_outlined, size: 18)),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: _freeShippingThresholdController,
                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'Free Delivery on Orders Above (Rs.)', prefixText: 'Rs. ', border: OutlineInputBorder(), prefixIcon: Icon(Icons.card_giftcard_rounded, size: 18)),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: _minWithdrawalController,
                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'Min Merchant Payout Threshold (Rs.)', prefixText: 'Rs. ', border: OutlineInputBorder(), prefixIcon: Icon(Icons.payments_outlined, size: 18)),
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        controller: _fbrTaxRateController,
                        style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'FBR National Sales Tax Rate (%)', suffixText: '%', border: OutlineInputBorder(), prefixIcon: Icon(Icons.receipt_long_outlined, size: 18)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Core Feature Flags
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.toggle_on_rounded, color: Color(0xFFD97706), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Marketplace Feature Flags & Operational Toggles', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('Turn major system subsystems on or off in real time without downtime.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 24),

                _buildFlagRow(
                  title: 'Allow New Seller Self-Registration',
                  subtitle: 'Enables new merchants to submit registration applications and KYC documents online.',
                  value: _allowSellerRegistration,
                  onChanged: (val) {
                    setState(() => _allowSellerRegistration = val);
                    adminState.logAuditAction('FLAG_SELLER_REG', 'Seller Governance', val ? 'Enabled registrations.' : 'Disabled registrations.');
                    SuperAdminDialogs.showToast(context, 'Seller Registration: ${val ? "Enabled 🟢" : "Disabled ⚪"}');
                  },
                ),
                const Divider(height: 16),

                _buildFlagRow(
                  title: 'Enable Buyer Digital Wallet & Instant Refunds',
                  subtitle: 'Allows buyers to maintain a wallet balance and receive instant refund credits.',
                  value: _enableBuyerWallet,
                  onChanged: (val) {
                    setState(() => _enableBuyerWallet = val);
                    adminState.logAuditAction('FLAG_WALLET', 'Customer Wallet', val ? 'Enabled wallet system.' : 'Disabled wallet system.');
                    SuperAdminDialogs.showToast(context, 'Buyer Wallet System: ${val ? "Enabled 🟢" : "Disabled ⚪"}');
                  },
                ),
                const Divider(height: 16),

                _buildFlagRow(
                  title: 'Enable Cash on Delivery (COD) Checkout Nationwide',
                  subtitle: 'Activates Cash on Delivery option across all Pakistani cities on buyer checkout.',
                  value: _allowCodPayment,
                  onChanged: (val) {
                    setState(() => _allowCodPayment = val);
                    adminState.logAuditAction('FLAG_COD', 'Payment Engine', val ? 'Enabled COD.' : 'Disabled COD.');
                    SuperAdminDialogs.showToast(context, 'COD Checkout: ${val ? "Enabled 🟢" : "Disabled ⚪"}');
                  },
                ),
                const Divider(height: 16),

                _buildFlagRow(
                  title: 'Enforce SMS OTP Verification on Buyer Checkout',
                  subtitle: 'Sends a 6-digit SMS verification code before confirming high-value orders to prevent fake orders.',
                  value: _enforceBuyerOtp,
                  onChanged: (val) {
                    setState(() => _enforceBuyerOtp = val);
                    adminState.logAuditAction('FLAG_OTP_CHECKOUT', 'Checkout Shield', val ? 'Enforced checkout OTP.' : 'Disabled OTP.');
                    SuperAdminDialogs.showToast(context, 'Checkout OTP Verification: ${val ? "Enforced 🟢" : "Disabled ⚪"}');
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Emergency Maintenance Mode
        Card(
          color: _maintenanceMode ? const Color(0xFFFEF2F2) : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _maintenanceMode ? const Color(0xFFF87171) : const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _maintenanceMode ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.handyman_rounded, color: _maintenanceMode ? const Color(0xFFDC2626) : const Color(0xFF475569), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _maintenanceMode ? '⚠️ EMERGENCY MAINTENANCE MODE ACTIVE' : 'Storefront Maintenance Mode',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _maintenanceMode ? const Color(0xFFDC2626) : const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'When activated, customer storefront displays a maintenance shield and all checkout APIs are safely paused.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _maintenanceMode,
                  activeColor: const Color(0xFFDC2626),
                  onChanged: (val) async {
                    final confirmed = await SuperAdminDialogs.showConfirmation(
                      context: context,
                      title: val ? 'ACTIVATE MAINTENANCE MODE' : 'Restore Live Storefront',
                      message: val
                          ? 'Are you sure you want to lock the marketplace storefront? Customers will not be able to place new orders!'
                          : 'Restore live marketplace operations for all buyers and sellers?',
                    );
                    if (confirmed) {
                      setState(() => _maintenanceMode = val);
                      adminState.logAuditAction('MAINTENANCE_TOGGLE', 'System Gate', val ? 'ACTIVATED MAINTENANCE' : 'Deactivated maintenance.');
                      SuperAdminDialogs.showToast(context, val ? '⚠️ Storefront Maintenance Mode Activated' : 'Storefront Restored Live!', isError: val);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlagRow({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: value ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value ? 'ACTIVE 🟢' : 'DISABLED ⚪',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: value ? const Color(0xFF059669) : const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              activeColor: const Color(0xFF10B981),
              onChanged: onChanged,
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // TAB 2: THIRD-PARTY APIS & GATEWAYS (MODERN 2-COLUMN CARD GRID)
  // ==========================================
  Widget _buildIntegrationsTab(List<GatewayIntegrationItem> integrationsList, SuperAdminProvider adminState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Filter Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active Third-Party Gateways & Infrastructure', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('Showing all connected Pakistani Payment Gateways, Couriers, SMS, Cloud DB & FBR POS APIs.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              Wrap(
                spacing: 6,
                children: ['All', 'Payments', 'Logistics', 'SMS & OTP', 'Cloud & DB', 'Tax & FBR'].map((cat) {
                  final isSel = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : const Color(0xFF64748B))),
                    selected: isSel,
                    selectedColor: const Color(0xFF0F172A),
                    backgroundColor: const Color(0xFFF1F5F9),
                    onSelected: (val) => setState(() => _selectedCategory = cat),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Modern 2-Column Responsive Card Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 2 : 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 220,
              ),
              itemCount: integrationsList.length,
              itemBuilder: (context, index) {
                final item = integrationsList[index];
                final isConnected = item.status.contains('Connected');

                return Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Card Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: item.bgColor, borderRadius: BorderRadius.circular(10)),
                              child: Icon(item.icon, color: item.iconColor, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                  const SizedBox(height: 2),
                                  Text(item.category.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: item.status == 'Configured' ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: item.status == 'Configured' ? const Color(0xFF059669) : const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Description
                        Text(item.description, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),

                        // Status & Toggle Row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFF1F5F9))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Provider: ${item.providerKey}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155), fontFamily: 'monospace'),
                              ),
                              Row(
                                children: [
                                  Text(
                                    item.isEnabled ? 'Enabled' : 'Disabled',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: item.isEnabled ? const Color(0xFF059669) : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(width: 8),
                                  Switch(
                                    value: item.isEnabled,
                                    activeColor: const Color(0xFF059669),
                                    onChanged: (val) {
                                      setState(() => item.isEnabled = val);
                                      adminState.logAuditAction('INTEGRATION_TOGGLE', item.providerKey, 'Set is_enabled = $val');
                                      SuperAdminDialogs.showToast(context, '${item.name} is now ${val ? "enabled" : "disabled"}.');
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.info_outline_rounded, size: 13),
                                label: const Text('Setup & Secrets Info', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF334155),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onPressed: () => _showIntegrationInfoModal(item),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ==========================================
  // READ-ONLY INTEGRATION INFO MODAL (ZERO SECRETS IN CLIENT)
  // ==========================================
  void _showIntegrationInfoModal(GatewayIntegrationItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: item.bgColor, borderRadius: BorderRadius.circular(8)),
              child: Icon(item.icon, color: item.iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(item.name, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.description, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Provider Key:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        Text(item.providerKey, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Category:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        Text(item.category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Configuration Status:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                        Text(item.status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: item.status == 'Configured' ? const Color(0xFF059669) : const Color(0xFFD97706))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Read-only architectural security notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security_rounded, size: 16, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Text(
                          'Zero-Client-Secrets Architectural Boundary',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E40AF)),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Secrets are set in Supabase Edge Function secrets, not in the app. Use the Supabase CLI to configure production credentials:\n\nsupabase secrets set PROVIDER_KEY=...\n\nSee docs/SECRETS_SETUP.md for complete instructions.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A), height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
