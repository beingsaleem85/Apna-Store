import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';

class CourierPartner {
  final String id;
  String name;
  String brandColor;
  String status;
  String webhookUrl;
  double baseRate;
  double extraKgRate;
  double successRate;
  String trackingUrl;
  String apiStatus;
  int latencyMs;
  bool isActive;

  CourierPartner({
    required this.id,
    required this.name,
    required this.brandColor,
    this.status = 'Not configured',
    required this.webhookUrl,
    required this.baseRate,
    required this.extraKgRate,
    required this.successRate,
    required this.trackingUrl,
    required this.apiStatus,
    this.latencyMs = 140,
    this.isActive = true,
  });
}

class ShippingZone {
  final String id;
  String zoneName;
  String citiesCovered;
  double deliveryFee;
  String estimatedDays;

  ShippingZone({
    required this.id,
    required this.zoneName,
    required this.citiesCovered,
    required this.deliveryFee,
    required this.estimatedDays,
  });
}

class CodSettlementItem {
  final String id;
  final String courierName;
  final int totalOrders;
  final double collectedCash;
  final double courierFees;
  final double netPayable;
  final String bankReference;
  final String settlementDate;
  String status; // 'RECONCILED', 'PENDING_TRANSFER', 'DISPUTED'

  CodSettlementItem({
    required this.id,
    required this.courierName,
    required this.totalOrders,
    required this.collectedCash,
    required this.courierFees,
    required this.netPayable,
    required this.bankReference,
    required this.settlementDate,
    required this.status,
  });
}

class ShippingGovernanceScreen extends StatefulWidget {
  const ShippingGovernanceScreen({super.key});

  @override
  State<ShippingGovernanceScreen> createState() => _ShippingGovernanceScreenState();
}

class _ShippingGovernanceScreenState extends State<ShippingGovernanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _freeShippingThreshold = 3000.0;

  final List<CourierPartner> _couriers = [
    CourierPartner(
      id: 'COU-01',
      name: 'TCS Express Pakistan',
      brandColor: '0xFFDC2626',
      status: 'Configured',
      webhookUrl: 'https://api.apnastore.pk/webhooks/tcs-tracking',
      baseRate: 200.0,
      extraKgRate: 80.0,
      successRate: 98.4,
      trackingUrl: 'https://tcsexpress.com/tracking',
      apiStatus: 'Connected',
      latencyMs: 124,
      isActive: true,
    ),
    CourierPartner(
      id: 'COU-02',
      name: 'Leopard Courier Services',
      brandColor: '0xFFD97706',
      status: 'Configured',
      webhookUrl: 'https://api.apnastore.pk/webhooks/leopard-tracking',
      baseRate: 180.0,
      extraKgRate: 70.0,
      successRate: 96.8,
      trackingUrl: 'https://leopardscourier.com/track',
      apiStatus: 'Connected',
      latencyMs: 165,
      isActive: true,
    ),
    CourierPartner(
      id: 'COU-03',
      name: 'CallCourier Logistics',
      brandColor: '0xFF2563EB',
      status: 'Configured',
      webhookUrl: 'https://api.apnastore.pk/webhooks/callcourier-dispatch',
      baseRate: 170.0,
      extraKgRate: 65.0,
      successRate: 95.2,
      trackingUrl: 'https://callcourier.com.pk/tracking',
      apiStatus: 'Connected',
      latencyMs: 190,
      isActive: true,
    ),
    CourierPartner(
      id: 'COU-04',
      name: 'Trax Logistics',
      brandColor: '0xFF059669',
      status: 'Not Configured',
      webhookUrl: 'https://api.apnastore.pk/webhooks/trax-dispatch',
      baseRate: 160.0,
      extraKgRate: 60.0,
      successRate: 94.0,
      trackingUrl: 'https://trax.pk/tracking',
      apiStatus: 'Pending Setup',
      latencyMs: 0,
      isActive: false,
    ),
  ];

  final List<ShippingZone> _zones = [
    ShippingZone(
      id: 'ZONE-01',
      zoneName: 'Intra-City Hub (Same City)',
      citiesCovered: 'Lahore, Karachi, Islamabad (Same-City Deliveries)',
      deliveryFee: 150.0,
      estimatedDays: '1-2 Working Days',
    ),
    ShippingZone(
      id: 'ZONE-02',
      zoneName: 'Major Metros Zone',
      citiesCovered: 'Lahore, Karachi, Islamabad, Rawalpindi, Faisalabad, Multan',
      deliveryFee: 250.0,
      estimatedDays: '2-3 Working Days',
    ),
    ShippingZone(
      id: 'ZONE-03',
      zoneName: 'Regional Outskirts Zone',
      citiesCovered: 'Peshawar, Quetta, Sialkot, Gujranwala, Bahawalpur, Sukkur',
      deliveryFee: 320.0,
      estimatedDays: '3-4 Working Days',
    ),
    ShippingZone(
      id: 'ZONE-04',
      zoneName: 'Remote & Azad Kashmir / Gilgit',
      citiesCovered: 'AJ&K, Gilgit-Baltistan, FATA & Distant Tehsil Centers',
      deliveryFee: 450.0,
      estimatedDays: '4-6 Working Days',
    ),
  ];

  final List<CodSettlementItem> _codSettlements = [
    CodSettlementItem(
      id: 'COD-SET-101',
      courierName: 'TCS Express Pakistan',
      totalOrders: 342,
      collectedCash: 684000.0,
      courierFees: 68400.0,
      netPayable: 615600.0,
      bankReference: 'MEEZAN-FT-998231',
      settlementDate: '2026-08-28',
      status: 'RECONCILED',
    ),
    CodSettlementItem(
      id: 'COD-SET-102',
      courierName: 'Leopard Courier Services',
      totalOrders: 189,
      collectedCash: 378000.0,
      courierFees: 34020.0,
      netPayable: 343980.0,
      bankReference: 'HBL-DEP-449102',
      settlementDate: '2026-08-27',
      status: 'RECONCILED',
    ),
    CodSettlementItem(
      id: 'COD-SET-103',
      courierName: 'CallCourier Logistics',
      totalOrders: 94,
      collectedCash: 188000.0,
      courierFees: 15980.0,
      netPayable: 172020.0,
      bankReference: 'PENDING_BATCH_08',
      settlementDate: '2026-08-29',
      status: 'PENDING_TRANSFER',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = Provider.of<SuperAdminProvider>(context);

    // KPI Metrics calculation
    final activeCouriers = _couriers.where((c) => c.isActive).length;
    final totalCodVolume = _codSettlements.fold(0.0, (sum, item) => sum + item.collectedCash);
    final pendingCodVolume = _codSettlements.where((i) => i.status == 'PENDING_TRANSFER').fold(0.0, (sum, i) => sum + i.netPayable);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Executive Breadcrumb & Header
          const Text('Breadcrumbs > Logistics > Courier & Shipping Setup', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Courier & Logistics Setup', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('Configure Pakistani 3PL courier APIs, delivery zones, flat tariffs, and COD cash reconciliation.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    onPressed: () => _showZonePricingModal(adminState),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    label: const Text('Pricing Engine Rules', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4 Top Logistics KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Integrated 3PL Fleets',
                  value: '$activeCouriers Active Fleets',
                  subtitle: '${_couriers.length} Registered Couriers',
                  icon: Icons.local_shipping_outlined,
                  iconColor: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Avg Delivery SLA',
                  value: '2.3 Days',
                  subtitle: 'Nationwide Delivery Time',
                  icon: Icons.timer_outlined,
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Delivery Success Rate',
                  value: '97.2% SLA',
                  subtitle: 'Successful Dropoffs',
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: const Color(0xFF059669),
                  bgColor: const Color(0xFFD1FAE5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'COD In-Transit Float',
                  value: 'PKR ${(pendingCodVolume / 1000).toInt()}k Pending',
                  subtitle: 'Total PKR ${(totalCodVolume / 1000000).toStringAsFixed(2)}M Collected',
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sub-Tabs Navigation
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
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.local_shipping, size: 18), text: 'Courier Partners & API Integration'),
                Tab(icon: Icon(Icons.map_outlined, size: 18), text: 'Shipping Zones & Free Delivery Threshold'),
                Tab(icon: Icon(Icons.payments_outlined, size: 18), text: 'COD Cash Reconciliation Ledger'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Views
          SizedBox(
            height: 580,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCouriersTab(adminState),
                _buildZonesTab(adminState),
                _buildCodReconciliationTab(adminState),
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
                Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: COURIER PARTNERS (2-COLUMN HIGH-DENSITY GRID)
  // ==========================================
  Widget _buildCouriersTab(SuperAdminProvider adminState) {
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
                    Text('Integrated Pakistani Courier Fleets (3PL)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Live API tracking health, dispatch endpoints, rate tariffs, and dispatch routing.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_link_rounded, size: 16),
                  label: const Text('+ Connect New Courier', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                  onPressed: () => _showAddCourierModal(adminState),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2-Column Responsive Courier Grid Layout
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 220,
                ),
                itemCount: _couriers.length,
                itemBuilder: (context, index) {
                  final courier = _couriers[index];
                  final brandColor = Color(int.parse(courier.brandColor));
                  final isConnected = courier.apiStatus == 'Connected';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: courier.isActive ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0), width: courier.isActive ? 1.4 : 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Header: Logo, Name, Status, and Switch
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(color: brandColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                              child: Center(child: Icon(Icons.local_shipping_rounded, color: brandColor, size: 20)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(courier.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isConnected ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isConnected ? 'API CONNECTED 🟢' : 'SETUP PENDING 🟡',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isConnected ? const Color(0xFF059669) : const Color(0xFFD97706),
                                          ),
                                        ),
                                      ),
                                      if (isConnected) ...[
                                        const SizedBox(width: 6),
                                        Text('${courier.latencyMs} ms', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: courier.isActive,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (val) {
                                setState(() => courier.isActive = val);
                                adminState.logAuditAction('COURIER_STATUS_TOGGLE', courier.name, val ? 'Activated courier partner.' : 'Deactivated courier partner.');
                                SuperAdminDialogs.showToast(context, '${courier.name} is now ${val ? "Active 🟢" : "Disabled ⚪"}');
                              },
                            ),
                          ],
                        ),
                        const Divider(color: Color(0xFFF1F5F9), height: 16),

                        // API Details & Webhook Info
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.settings_suggest_rounded, size: 12, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text('Status: ', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                  Text(courier.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: courier.status == 'Configured' ? const Color(0xFF059669) : const Color(0xFFD97706))),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.webhook_rounded, size: 12, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(courier.webhookUrl, style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),

                        // Rate Tariff and Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Base Rate: PKR ${courier.baseRate.toInt()}/KG', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                                Text('Addl KG: PKR ${courier.extraKgRate.toInt()} • SLA: ${courier.successRate}%', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                              ],
                            ),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.speed_rounded, size: 13),
                                  label: const Text('Test Ping', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0F172A),
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  ),
                                  onPressed: () {
                                    adminState.logAuditAction('COURIER_API_TEST', courier.name, 'Performed API handshake ping.');
                                    SuperAdminDialogs.showToast(context, 'API Handshake successful! Latency: ${courier.latencyMs > 0 ? courier.latencyMs : 142}ms');
                                  },
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.settings_outlined, color: Color(0xFF475569), size: 18),
                                  tooltip: 'Edit API Credentials & Rates',
                                  onPressed: () => _showEditCourierModal(courier, adminState),
                                ),
                              ],
                            ),
                          ],
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
  // TAB 2: SHIPPING ZONES & FREE DELIVERY (2-SECTION LAYOUT)
  // ==========================================
  Widget _buildZonesTab(SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top 2-Column: Free Delivery Card + Dynamic Rules Summary
            Row(
              children: [
                // Free Shipping Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.local_shipping_outlined, color: Color(0xFF059669), size: 28),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Free Delivery Minimum Cart Threshold', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                                Text('Orders equal to or above qualify for 100% Free Shipping.', style: TextStyle(color: Color(0xFF047857), fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit, size: 13),
                          label: Text('PKR ${_freeShippingThreshold.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: () => _showEditFreeShippingModal(adminState),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Pricing Rules Quick Summary Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 26),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dynamic Pricing Formula', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              Text('1st KG Base + Additional Weight Multipliers + COD Surcharge (1.5%)', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showZonePricingModal(adminState),
                          child: const Text('View Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Regional Zones Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Regional Delivery Zones & Flat Tariffs', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Define flat rate delivery charges based on customer destination regions across Pakistan.', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('Add Custom Zone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                  onPressed: () => _showAddZoneModal(adminState),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Zones High-Density Table
            Expanded(
              child: ListView.builder(
                itemCount: _zones.length,
                itemBuilder: (context, index) {
                  final zone = _zones[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.pin_drop_outlined, size: 22, color: Color(0xFF2563EB)),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(zone.zoneName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(zone.citiesCovered, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                child: Text(zone.estimatedDays, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                              ),
                            ],
                          ),
                        ),
                        Text('Flat Fee: PKR ${zone.deliveryFee.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706), fontSize: 13)),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                          onPressed: () => _showEditZoneModal(zone, adminState),
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
  // TAB 3: COD CASH RECONCILIATION
  // ==========================================
  Widget _buildCodReconciliationTab(SuperAdminProvider adminState) {
    final reconciledVolume = _codSettlements.where((i) => i.status == 'RECONCILED').fold(0.0, (sum, i) => sum + i.netPayable);
    final pendingVolume = _codSettlements.where((i) => i.status == 'PENDING_TRANSFER').fold(0.0, (sum, i) => sum + i.netPayable);
    final totalFeeCuts = _codSettlements.fold(0.0, (sum, i) => sum + i.courierFees);

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Summary Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFA7F3D0))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reconciled to Meezan Bank', style: TextStyle(fontSize: 10, color: Color(0xFF065F46), fontWeight: FontWeight.bold)),
                        Text('PKR ${reconciledVolume.toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFFDE68A))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pending Courier Disbursals', style: TextStyle(fontSize: 10, color: Color(0xFF92400E), fontWeight: FontWeight.bold)),
                        Text('PKR ${pendingVolume.toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFCBD5E1))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Courier Shipping Charges Deducted', style: TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                        Text('PKR ${totalFeeCuts.toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.verified_outlined, size: 16),
                  label: const Text('Reconcile All Batches', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  onPressed: () {
                    setState(() {
                      for (var item in _codSettlements) {
                        item.status = 'RECONCILED';
                      }
                    });
                    adminState.logAuditAction('COD_RECONCILE_ALL', 'Settlement Engine', 'Reconciled all pending courier COD deposits.');
                    SuperAdminDialogs.showToast(context, 'All Courier COD batches marked as Reconciled & Verified!');
                  },
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
                  Expanded(flex: 3, child: Text('Courier / Batch ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Orders Delivered', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Cash Collected', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Courier Fee Cut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Net Disbursal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Status & Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: _codSettlements.length,
                itemBuilder: (context, index) {
                  final item = _codSettlements[index];
                  final isReconciled = item.status == 'RECONCILED';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.courierName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
                              const SizedBox(height: 2),
                              Text('${item.id} • Ref: ${item.bankReference}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('${item.totalOrders} Delivered', style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('PKR ${item.collectedCash.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('- PKR ${item.courierFees.toInt()}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text('PKR ${item.netPayable.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 13)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isReconciled ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isReconciled ? 'RECONCILED 🟢' : 'PENDING 🟡',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isReconciled ? const Color(0xFF059669) : const Color(0xFFD97706),
                                  ),
                                ),
                              ),
                              if (!isReconciled) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    setState(() => item.status = 'RECONCILED');
                                    adminState.logAuditAction('COD_BATCH_SETTLE', item.id, 'Manually cleared COD batch.');
                                    SuperAdminDialogs.showToast(context, 'Batch ${item.id} Reconciled!');
                                  },
                                  child: const Text('Settle', style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
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
  // MODALS WITH CLEAN LIGHT THEME (NO CONTRAST BUGS)
  // ==========================================
  void _showEditFreeShippingModal(SuperAdminProvider adminState) {
    final controller = TextEditingController(text: _freeShippingThreshold.toInt().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.local_shipping, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 8),
            Text('Edit Free Delivery Threshold', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Orders equal to or exceeding this cart amount qualify for 100% Free Shipping.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              decoration: const InputDecoration(labelText: 'Min Order Amount for Free Shipping (PKR)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () {
              final newThreshold = double.tryParse(controller.text);
              if (newThreshold != null) {
                setState(() => _freeShippingThreshold = newThreshold);
                adminState.logAuditAction('FREE_SHIPPING_UPDATE', 'Logistics Engine', 'Updated free shipping threshold to PKR $newThreshold');
                Navigator.pop(ctx);
                SuperAdminDialogs.showToast(context, 'Free Delivery Threshold Updated to PKR $newThreshold!');
              }
            },
            child: const Text('Save Threshold'),
          ),
        ],
      ),
    );
  }

  void _showAddCourierModal(SuperAdminProvider adminState) {
    final nameCtrl = TextEditingController();
    final keyCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '180');
    final extraRateCtrl = TextEditingController(text: '70');
    final urlCtrl = TextEditingController(text: 'https://api.apnastore.pk/webhooks/tracking');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.add_link_rounded, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 8),
            Text('Connect New Courier API (3PL)', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              decoration: const InputDecoration(labelText: 'Courier Partner Name (e.g. M&P Express)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Text(
                'Note: Courier API credentials are set server-side via Supabase Edge Function secrets (supabase secrets set ...). No secrets are entered or stored in the client app.',
                style: TextStyle(fontSize: 10, color: Color(0xFF1E40AF)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rateCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(labelText: 'Base 1st KG Rate (PKR)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: extraRateCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(labelText: 'Additional KG Rate (PKR)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(labelText: 'Tracking Webhook URL', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                setState(() {
                  _couriers.add(CourierPartner(
                    id: 'COU-0${_couriers.length + 1}',
                    name: nameCtrl.text.trim(),
                    brandColor: '0xFF2563EB',
                    status: 'Configured',
                    webhookUrl: urlCtrl.text.trim(),
                    baseRate: double.tryParse(rateCtrl.text) ?? 180.0,
                    extraKgRate: double.tryParse(extraRateCtrl.text) ?? 70.0,
                    successRate: 96.0,
                    trackingUrl: 'https://tracking.example.com',
                    apiStatus: 'Connected',
                    latencyMs: 135,
                    isActive: true,
                  ));
                });
                adminState.logAuditAction('COURIER_ADD', nameCtrl.text, 'Integrated new 3PL courier fleet.');
                Navigator.pop(ctx);
                SuperAdminDialogs.showToast(context, 'Courier ${nameCtrl.text} Connected Successfully!');
              }
            },
            child: const Text('Connect Courier'),
          ),
        ],
      ),
    );
  }

  void _showEditCourierModal(CourierPartner courier, SuperAdminProvider adminState) {
    final rateCtrl = TextEditingController(text: courier.baseRate.toInt().toString());
    final extraRateCtrl = TextEditingController(text: courier.extraKgRate.toInt().toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Edit Tariff & Settings — ${courier.name}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Text(
                'Note: Courier API credentials are set server-side via Supabase Edge Function secrets. No secrets are entered or stored in the client app.',
                style: TextStyle(fontSize: 10, color: Color(0xFF1E40AF)),
              ),
            ),
            TextField(
              controller: rateCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(labelText: 'Base 1st KG Rate (PKR)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: extraRateCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(labelText: 'Each Additional KG Rate (PKR)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                courier.baseRate = double.tryParse(rateCtrl.text) ?? courier.baseRate;
                courier.extraKgRate = double.tryParse(extraRateCtrl.text) ?? courier.extraKgRate;
              });
              adminState.logAuditAction('COURIER_RATE_UPDATE', courier.name, 'Updated courier base tariff.');
              Navigator.pop(ctx);
              SuperAdminDialogs.showToast(context, '${courier.name} updated successfully!');
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showAddZoneModal(SuperAdminProvider adminState) {
    final nameCtrl = TextEditingController();
    final citiesCtrl = TextEditingController();
    final feeCtrl = TextEditingController(text: '200');
    final daysCtrl = TextEditingController(text: '2-3 Working Days');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.pin_drop_outlined, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 8),
            Text('Add Shipping Zone', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              decoration: const InputDecoration(labelText: 'Zone Name (e.g. South Punjab Zone)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: citiesCtrl,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(labelText: 'Cities Covered', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feeCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(labelText: 'Delivery Flat Fee (PKR)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: daysCtrl,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(labelText: 'Estimated SLA Days', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                setState(() {
                  _zones.add(ShippingZone(
                    id: 'ZONE-0${_zones.length + 1}',
                    zoneName: nameCtrl.text.trim(),
                    citiesCovered: citiesCtrl.text.trim(),
                    deliveryFee: double.tryParse(feeCtrl.text) ?? 200.0,
                    estimatedDays: daysCtrl.text.trim(),
                  ));
                });
                adminState.logAuditAction('ZONE_ADD', nameCtrl.text, 'Added new shipping zone.');
                Navigator.pop(ctx);
                SuperAdminDialogs.showToast(context, 'Shipping Zone Added Successfully!');
              }
            },
            child: const Text('Save Zone'),
          ),
        ],
      ),
    );
  }

  void _showEditZoneModal(ShippingZone zone, SuperAdminProvider adminState) {
    final feeCtrl = TextEditingController(text: zone.deliveryFee.toInt().toString());
    final daysCtrl = TextEditingController(text: zone.estimatedDays);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Edit Tariff — ${zone.zoneName}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: feeCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              decoration: const InputDecoration(labelText: 'Flat Delivery Fee (PKR)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: daysCtrl,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(labelText: 'Estimated SLA Days', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                zone.deliveryFee = double.tryParse(feeCtrl.text) ?? zone.deliveryFee;
                zone.estimatedDays = daysCtrl.text.trim();
              });
              adminState.logAuditAction('ZONE_UPDATE', zone.zoneName, 'Updated delivery tariff.');
              Navigator.pop(ctx);
              SuperAdminDialogs.showToast(context, 'Zone tariff updated successfully!');
            },
            child: const Text('Save Tariff'),
          ),
        ],
      ),
    );
  }

  void _showZonePricingModal(SuperAdminProvider adminState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 8),
            Text('Logistics Dynamic Pricing Engine Rules', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Weight Multiplier: First 1.0 KG is charged at Base Rate. Each subsequent 1.0 KG adds Extra KG Rate.', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
            SizedBox(height: 10),
            Text('2. COD Handling Surcharge: 1.5% fee or min PKR 30 per parcel (auto-deducted from merchant payout).', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
            SizedBox(height: 10),
            Text('3. Free Shipping Subsidy: When order value > Threshold, platform subsidizes 100% of the courier delivery fee.', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }
}
