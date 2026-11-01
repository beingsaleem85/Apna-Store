import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';

class CourierPartner {
  final String id;
  final String code;
  final String name;
  final String brandColor;
  final double baseRate;
  final double extraKgRate;
  final String trackingUrlTemplate;
  final String webhookUrl;
  bool isActive;
  final bool isLiveApiConnected;

  CourierPartner({
    required this.id,
    required this.code,
    required this.name,
    required this.brandColor,
    required this.baseRate,
    required this.extraKgRate,
    required this.trackingUrlTemplate,
    required this.webhookUrl,
    required this.isActive,
    required this.isLiveApiConnected,
  });

  factory CourierPartner.fromJson(Map<String, dynamic> json) {
    return CourierPartner(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? 'Courier').toString(),
      brandColor: (json['brand_color'] ?? '0xFF2563EB').toString(),
      baseRate: (json['base_rate'] as num?)?.toDouble() ?? 150.0,
      extraKgRate: (json['extra_kg_rate'] as num?)?.toDouble() ?? 50.0,
      trackingUrlTemplate: (json['tracking_url_template'] ?? '').toString(),
      webhookUrl: (json['webhook_url'] ?? '').toString(),
      isActive: (json['is_active'] as bool?) ?? true,
      isLiveApiConnected: (json['is_live_api_connected'] as bool?) ?? false,
    );
  }
}

class ShippingZone {
  final String id;
  final String zoneName;
  final String citiesCovered;
  final double minWeightKg;
  final double maxWeightKg;
  final double deliveryFee;
  final String estimatedDays;
  final bool isActive;

  ShippingZone({
    required this.id,
    required this.zoneName,
    required this.citiesCovered,
    required this.minWeightKg,
    required this.maxWeightKg,
    required this.deliveryFee,
    required this.estimatedDays,
    required this.isActive,
  });

  factory ShippingZone.fromJson(Map<String, dynamic> json) {
    return ShippingZone(
      id: (json['id'] ?? '').toString(),
      zoneName: (json['zone_name'] ?? 'Zone').toString(),
      citiesCovered: (json['cities_covered'] ?? 'All Cities').toString(),
      minWeightKg: (json['min_weight_kg'] as num?)?.toDouble() ?? 0.0,
      maxWeightKg: (json['max_weight_kg'] as num?)?.toDouble() ?? 5.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 150.0,
      estimatedDays: (json['estimated_days'] ?? '2-3 Business Days').toString(),
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}

class OrderShipmentAssignment {
  final String id;
  final String orderId;
  final String sellerStoreId;
  final String storeName;
  final String courierName;
  final String trackingNumber;
  final String status;
  final DateTime assignedAt;

  OrderShipmentAssignment({
    required this.id,
    required this.orderId,
    required this.sellerStoreId,
    required this.storeName,
    required this.courierName,
    required this.trackingNumber,
    required this.status,
    required this.assignedAt,
  });

  factory OrderShipmentAssignment.fromJson(Map<String, dynamic> json) {
    return OrderShipmentAssignment(
      id: (json['id'] ?? '').toString(),
      orderId: (json['order_id'] ?? '').toString(),
      sellerStoreId: (json['seller_store_id'] ?? '').toString(),
      storeName: (json['store_name'] ?? 'Store').toString(),
      courierName: (json['courier_name'] ?? 'Courier').toString(),
      trackingNumber: (json['tracking_number'] ?? '').toString(),
      status: (json['status'] ?? 'Assigned').toString(),
      assignedAt: DateTime.tryParse(json['assigned_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ShippingGovernanceScreen extends StatefulWidget {
  const ShippingGovernanceScreen({super.key});

  @override
  State<ShippingGovernanceScreen> createState() => _ShippingGovernanceScreenState();
}

class _ShippingGovernanceScreenState extends State<ShippingGovernanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final double _freeShippingThreshold = 3000.0;

  final List<CourierPartner> _couriers = [];
  final List<ShippingZone> _zones = [];
  final List<OrderShipmentAssignment> _recentAssignments = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadShippingData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadShippingData() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.rpc('admin_fetch_shipping_overview');
      if (mounted && res is Map) {
        final rawCouriers = res['couriers'] as List? ?? [];
        final rawZones = res['zones'] as List? ?? [];
        final rawAssignments = res['recent_assignments'] as List? ?? [];

        setState(() {
          _couriers.clear();
          _couriers.addAll(rawCouriers.map((c) => CourierPartner.fromJson(Map<String, dynamic>.from(c as Map))));

          _zones.clear();
          _zones.addAll(rawZones.map((z) => ShippingZone.fromJson(Map<String, dynamic>.from(z as Map))));

          _recentAssignments.clear();
          _recentAssignments.addAll(rawAssignments.map((a) => OrderShipmentAssignment.fromJson(Map<String, dynamic>.from(a as Map))));
        });
      }
    } catch (_) {
      // Fallback: Direct table selects if RPC is temporarily blocked
      try {
        final cRes = await Supabase.instance.client.from('shipping_courier_partners').select('*').order('name');
        final zRes = await Supabase.instance.client.from('shipping_zones').select('*').order('delivery_fee');

        if (mounted) {
          setState(() {
            _couriers.clear();
            _couriers.addAll(cRes.map((c) => CourierPartner.fromJson(Map<String, dynamic>.from(c))));

            _zones.clear();
            _zones.addAll(zRes.map((z) => ShippingZone.fromJson(Map<String, dynamic>.from(z))));
          });
        }
      } catch (err) {
        if (mounted) {
          SuperAdminDialogs.showToast(context, 'Failed to load shipping data: $err', isError: true);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleCourierActive(CourierPartner courier, bool val, SuperAdminProvider adminState) async {
    try {
      final res = await Supabase.instance.client.rpc('admin_toggle_courier_active', params: {
        'p_courier_id': courier.id,
        'p_is_active': val,
      });

      if (res is Map && res['success'] == true) {
        setState(() => courier.isActive = val);
        adminState.logAuditAction('COURIER_TOGGLE', courier.name, val ? 'Activated courier partner.' : 'Deactivated courier partner.');
        if (mounted) {
          SuperAdminDialogs.showToast(context, '${courier.name} is now ${val ? "Active 🟢" : "Disabled ⚪"}');
        }
      }
    } catch (e) {
      if (mounted) {
        SuperAdminDialogs.showToast(context, 'Failed to update courier: $e', isError: true);
      }
    }
  }

  Future<void> _saveShippingZone({
    String? id,
    required String zoneName,
    required String cities,
    required double minWeight,
    required double maxWeight,
    required double fee,
    required String estimatedDays,
    required SuperAdminProvider adminState,
  }) async {
    try {
      final res = await Supabase.instance.client.rpc('admin_save_shipping_zone', params: {
        'p_id': id,
        'p_zone_name': zoneName.trim(),
        'p_cities_covered': cities.trim(),
        'p_min_weight_kg': minWeight,
        'p_max_weight_kg': maxWeight,
        'p_delivery_fee': fee,
        'p_estimated_days': estimatedDays.trim(),
      });

      if (res is Map && res['success'] == true) {
        adminState.logAuditAction('ZONE_SAVED', zoneName, 'Fee: PKR $fee, Weight: $minWeight - $maxWeight kg');
        if (mounted) {
          SuperAdminDialogs.showToast(context, 'Shipping Zone "$zoneName" saved successfully!');
        }
        await _loadShippingData();
      }
    } catch (e) {
      if (mounted) {
        SuperAdminDialogs.showToast(context, 'Failed to save zone: $e', isError: true);
      }
    }
  }

  Future<void> _deleteShippingZone(ShippingZone zone, SuperAdminProvider adminState) async {
    try {
      final res = await Supabase.instance.client.rpc('admin_delete_shipping_zone', params: {
        'p_zone_id': zone.id,
      });

      if (res is Map && res['success'] == true) {
        adminState.logAuditAction('ZONE_DELETED', zone.zoneName, 'Deleted shipping zone.');
        if (mounted) {
          SuperAdminDialogs.showToast(context, 'Shipping Zone "${zone.zoneName}" deleted.');
        }
        await _loadShippingData();
      }
    } catch (e) {
      if (mounted) {
        SuperAdminDialogs.showToast(context, 'Failed to delete zone: $e', isError: true);
      }
    }
  }

  Future<void> _assignShipment({
    required String orderId,
    required String storeId,
    required String courierId,
    required String trackingNumber,
    required SuperAdminProvider adminState,
  }) async {
    try {
      final res = await Supabase.instance.client.rpc('admin_assign_order_shipment', params: {
        'p_order_id': orderId.trim(),
        'p_seller_store_id': storeId.trim(),
        'p_courier_id': courierId.trim(),
        'p_tracking_number': trackingNumber.trim(),
      });

      if (res is Map && res['success'] == true) {
        adminState.logAuditAction('SHIPMENT_ASSIGN', orderId, 'Assigned tracking $trackingNumber via ${res['courier_name']}');
        if (mounted) {
          SuperAdminDialogs.showToast(context, 'Shipment assigned for order $orderId!');
        }
        await _loadShippingData();
      }
    } catch (e) {
      if (mounted) {
        SuperAdminDialogs.showToast(context, 'Assignment failed: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminState = Provider.of<SuperAdminProvider>(context);

    final activeCouriers = _couriers.where((c) => c.isActive).length;
    final totalZones = _zones.length;
    final totalAssignments = _recentAssignments.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Executive Breadcrumb & Header
          const Text('Breadcrumbs > Logistics > Courier & Shipping Governance', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Courier & Logistics Governance', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text('Configure Pakistani 3PL courier fleets, delivery zones, flat tariffs, and per-order shipment dispatch.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    onPressed: _loadShippingData,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    label: const Text('Refresh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.assignment_turned_in_outlined, size: 16),
                    onPressed: () => _showAssignShipmentModal(adminState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    label: const Text('+ Assign Shipment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                  subtitle: '${_couriers.length} Registered Partners',
                  icon: Icons.local_shipping_outlined,
                  iconColor: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Configured Zones',
                  value: '$totalZones Regional Tiers',
                  subtitle: 'Flat Rate Delivery Matrix',
                  icon: Icons.map_outlined,
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Dispatched Shipments',
                  value: '$totalAssignments Active',
                  subtitle: 'Recent Tracking Assignments',
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: const Color(0xFF059669),
                  bgColor: const Color(0xFFD1FAE5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Free Delivery Threshold',
                  value: 'PKR ${_freeShippingThreshold.toInt()}',
                  subtitle: 'Cart Minimum for Free Shipping',
                  icon: Icons.local_offer_outlined,
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
                Tab(icon: Icon(Icons.local_shipping, size: 18), text: 'Courier Fleets & API Status'),
                Tab(icon: Icon(Icons.map_outlined, size: 18), text: 'Shipping Zones & Weight Tiers'),
                Tab(icon: Icon(Icons.assignment_outlined, size: 18), text: 'Order Shipment Assignments'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Views
          SizedBox(
            height: 600,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCouriersTab(adminState),
                      _buildZonesTab(adminState),
                      _buildAssignmentsTab(adminState),
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
  // TAB 1: COURIER PARTNERS
  // ==========================================
  Widget _buildCouriersTab(SuperAdminProvider adminState) {
    if (_couriers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'No Courier Partners Found',
        subtitle: 'No 3PL courier fleets are currently registered in the database.',
      );
    }

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Integrated Pakistani Courier Fleets (3PL)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const Text('Live API connection status, webhook tracking templates, and base rate tariffs.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            const SizedBox(height: 16),

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
                  final brandColor = Color(int.tryParse(courier.brandColor) ?? 0xFF2563EB);

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
                                  // Honest API Connection Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: courier.isLiveApiConnected ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      courier.isLiveApiConnected ? 'LIVE API CONNECTED 🟢' : 'NOT CONNECTED (WEBHOOK ONLY) ⚪',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: courier.isLiveApiConnected ? const Color(0xFF059669) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: courier.isActive,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (val) => _toggleCourierActive(courier, val, adminState),
                            ),
                          ],
                        ),
                        const Divider(color: Color(0xFFF1F5F9), height: 16),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Code: ${courier.code}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                              const SizedBox(height: 2),
                              Text('Template: ${courier.trackingUrlTemplate}', style: const TextStyle(fontSize: 9, color: Color(0xFF2563EB)), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const Spacer(),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Base 1st KG: PKR ${courier.baseRate.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                                Text('Addl KG: PKR ${courier.extraKgRate.toInt()}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(4)),
                              child: Text(courier.isActive ? 'Active' : 'Disabled', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
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
  // TAB 2: SHIPPING ZONES & WEIGHT TIERS
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Regional Delivery Zones & Weight Tier Tariffs', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Define flat rate delivery charges and weight brackets across Pakistan destination hubs.', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('Add Zone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                  onPressed: () => _showAddZoneModal(adminState),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Expanded(
              child: _zones.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.map_outlined,
                      title: 'No Shipping Zones Defined',
                      subtitle: 'Click "+ Add Zone" to create your first regional delivery zone.',
                    )
                  : ListView.builder(
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
                                    Text('${zone.citiesCovered} • Weight: ${zone.minWeightKg} - ${zone.maxWeightKg} KG', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                  child: Text(zone.estimatedDays, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                ),
                              ),
                              Text('Flat Fee: PKR ${zone.deliveryFee.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD97706), fontSize: 13)),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                                tooltip: 'Delete Zone',
                                onPressed: () => _deleteShippingZone(zone, adminState),
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
  // TAB 3: ORDER SHIPMENT ASSIGNMENTS
  // ==========================================
  Widget _buildAssignmentsTab(SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent Order Shipment Assignments', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const Text('Authorized 3PL dispatch bookings linking orders to couriers and tracking numbers.', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            const SizedBox(height: 14),

            Expanded(
              child: _recentAssignments.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'No Shipment Assignments',
                      subtitle: 'No shipments have been dispatched yet. Use "+ Assign Shipment" to book an order.',
                    )
                  : ListView.builder(
                      itemCount: _recentAssignments.length,
                      itemBuilder: (context, index) {
                        final a = _recentAssignments[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.orderId, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 13)),
                                    Text(a.storeName, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(a.courierName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 12)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(a.trackingNumber, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF059669))),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(a.status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                              ),
                              Text(a.assignedAt.toString().substring(0, 10), style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
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

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddZoneModal(SuperAdminProvider adminState) {
    final nameCtrl = TextEditingController();
    final citiesCtrl = TextEditingController();
    final minWeightCtrl = TextEditingController(text: '0.0');
    final maxWeightCtrl = TextEditingController(text: '5.0');
    final feeCtrl = TextEditingController(text: '200');
    final daysCtrl = TextEditingController(text: '2-3 Business Days');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.add_location_alt_outlined, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 8),
            Text('Add Shipping Zone & Tariff', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Color(0xFF0F172A)),
                decoration: const InputDecoration(labelText: 'Zone Name (e.g. Sindh Hubs)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: citiesCtrl,
                style: const TextStyle(color: Color(0xFF0F172A)),
                decoration: const InputDecoration(labelText: 'Cities Covered (comma separated)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minWeightCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: const InputDecoration(labelText: 'Min KG', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: maxWeightCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: const InputDecoration(labelText: 'Max KG', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: feeCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: const InputDecoration(labelText: 'Delivery Fee (PKR)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: daysCtrl,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: const InputDecoration(labelText: 'Estimated Days', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () {
              final fee = double.tryParse(feeCtrl.text);
              final minW = double.tryParse(minWeightCtrl.text);
              final maxW = double.tryParse(maxWeightCtrl.text);

              if (nameCtrl.text.isNotEmpty && fee != null && minW != null && maxW != null) {
                if (fee < 0 || minW < 0 || maxW <= minW) {
                  SuperAdminDialogs.showToast(context, 'Invalid weight range or fee.', isError: true);
                  return;
                }
                Navigator.pop(ctx);
                _saveShippingZone(
                  zoneName: nameCtrl.text.trim(),
                  cities: citiesCtrl.text.trim(),
                  minWeight: minW,
                  maxWeight: maxW,
                  fee: fee,
                  estimatedDays: daysCtrl.text.trim(),
                  adminState: adminState,
                );
              }
            },
            child: const Text('Save Zone'),
          ),
        ],
      ),
    );
  }

  void _showAssignShipmentModal(SuperAdminProvider adminState) {
    final orderIdCtrl = TextEditingController();
    final storeIdCtrl = TextEditingController();
    final trackingCtrl = TextEditingController();
    String? selectedCourierId = _couriers.isNotEmpty ? _couriers.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF2563EB), size: 22),
              SizedBox(width: 8),
              Text('Assign Shipment to Courier', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: orderIdCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Order ID (e.g. ORD-1001)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: storeIdCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: const InputDecoration(labelText: 'Seller Store ID (UUID)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedCourierId,
                  decoration: const InputDecoration(labelText: 'Select Courier Partner', border: OutlineInputBorder()),
                  items: _couriers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (v) => setMState(() => selectedCourierId = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: trackingCtrl,
                  style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'monospace'),
                  decoration: const InputDecoration(labelText: 'Courier Tracking / AWB Number', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () {
                if (orderIdCtrl.text.isNotEmpty && storeIdCtrl.text.isNotEmpty && selectedCourierId != null && trackingCtrl.text.isNotEmpty) {
                  Navigator.pop(ctx);
                  _assignShipment(
                    orderId: orderIdCtrl.text.trim(),
                    storeId: storeIdCtrl.text.trim(),
                    courierId: selectedCourierId!,
                    trackingNumber: trackingCtrl.text.trim(),
                    adminState: adminState,
                  );
                }
              },
              child: const Text('Assign Shipment'),
            ),
          ],
        ),
      ),
    );
  }
}
