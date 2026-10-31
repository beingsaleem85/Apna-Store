import 'package:flutter/material.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/services/app_state_provider.dart';

// Backward compatibility alias wrapper
class SellerOrdersShippingDesk extends StatelessWidget {
  final AppStateProvider state;
  final String activeSellerId;

  const SellerOrdersShippingDesk({
    super.key,
    required this.state,
    required this.activeSellerId,
  });

  @override
  Widget build(BuildContext context) {
    return SellerOrdersManagementSection(state: state, activeSellerId: activeSellerId);
  }
}

// 1. Executive Manage Orders Section
class SellerOrdersManagementSection extends StatefulWidget {
  final AppStateProvider state;
  final String activeSellerId;

  const SellerOrdersManagementSection({
    super.key,
    required this.state,
    required this.activeSellerId,
  });

  @override
  State<SellerOrdersManagementSection> createState() => _SellerOrdersManagementSectionState();
}

class _SellerOrdersManagementSectionState extends State<SellerOrdersManagementSection> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedStatusFilter = 'All';
  int _activeSubTab = 0; // 0: Orders List, 1: Logistics Partners

  // Demo Fallback Orders if state.orders is empty
  late List<AppOrder> _sampleOrders;

  @override
  void initState() {
    super.initState();
    _sampleOrders = [
      AppOrder(
        id: 'ORD-984210',
        productId: 'prod_1',
        productName: 'Embroidered Cotton Kurta - Royal Blue (Size L)',
        productPrice: 3500.0,
        sellerId: widget.activeSellerId,
        buyerName: 'Muhammad Usman',
        shippingAddress: 'House 42, Block B, Gulberg III, Lahore',
        shippingSpeed: 'Standard Express',
        paymentMethod: 'Cash on Delivery',
        couponDiscount: 200,
        commissionDeducted: 150,
        finalPayout: 3150,
        orderStatus: 'Pending',
      ),
      AppOrder(
        id: 'ORD-984211',
        productId: 'prod_2',
        productName: 'Wireless Bluetooth Earbuds Pro',
        productPrice: 4200.0,
        sellerId: widget.activeSellerId,
        buyerName: 'Ayesha Khan',
        shippingAddress: 'Flat 302, Sunrise Towers, PECHS, Karachi',
        shippingSpeed: 'Fast Delivery',
        paymentMethod: 'Digital Payment (Card)',
        couponDiscount: 0,
        commissionDeducted: 210,
        finalPayout: 3990,
        orderStatus: 'Confirmed',
      ),
      AppOrder(
        id: 'ORD-984212',
        productId: 'prod_3',
        productName: 'Men Leather Formal Shoes - Tan (Size 42)',
        productPrice: 6800.0,
        sellerId: widget.activeSellerId,
        buyerName: 'Bilal Farooq',
        shippingAddress: 'Sector F-8/2, Street 14, Islamabad',
        shippingSpeed: 'Standard Express',
        paymentMethod: 'Cash on Delivery',
        couponDiscount: 500,
        commissionDeducted: 340,
        finalPayout: 5960,
        orderStatus: 'Packed',
      ),
      AppOrder(
        id: 'ORD-984213',
        productId: 'prod_4',
        productName: 'Designer Silk Lawn Unstitched Suit',
        productPrice: 5500.0,
        sellerId: widget.activeSellerId,
        buyerName: 'Saima Malik',
        shippingAddress: 'Model Town, Link Road, Multan',
        shippingSpeed: 'Standard Express',
        paymentMethod: 'Cash on Delivery',
        couponDiscount: 300,
        commissionDeducted: 260,
        finalPayout: 4940,
        orderStatus: 'Shipped',
        trackingNumber: 'APNA-EX-778901',
      ),
      AppOrder(
        id: 'ORD-984214',
        productId: 'prod_5',
        productName: 'Smart Fitness Tracker Watch',
        productPrice: 2900.0,
        sellerId: widget.activeSellerId,
        buyerName: 'Zubair Ahmed',
        shippingAddress: 'Satellite Town, Block A, Rawalpindi',
        shippingSpeed: 'Standard Express',
        paymentMethod: 'Digital Payment (Easypaisa)',
        couponDiscount: 100,
        commissionDeducted: 145,
        finalPayout: 2655,
        orderStatus: 'Delivered',
      ),
    ];
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFFEF3C7);
    Color text = const Color(0xFFD97706);

    if (status == 'Confirmed' || status == 'Packed') {
      bg = const Color(0xFFE0F2FE);
      text = const Color(0xFF0284C7);
    } else if (status == 'ReadyToShip' || status == 'Shipped') {
      bg = const Color(0xFFE0E7FF);
      text = const Color(0xFF4338CA);
    } else if (status == 'Delivered') {
      bg = const Color(0xFFECFDF5);
      text = const Color(0xFF059669);
    } else if (status == 'Cancelled' || status == 'Returned') {
      bg = const Color(0xFFFEF2F2);
      text = const Color(0xFFDC2626);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
    );
  }

  Widget _buildLogisticsTile(String title, String subtitle, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.local_shipping_outlined, color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
          Switch(
            value: isActive,
            activeColor: const Color(0xFF059669),
            onChanged: (_) {},
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveOrders = widget.state.orders.where((o) => o.sellerId == widget.activeSellerId || o.sellerId.startsWith('seller_')).toList();
    final allOrders = liveOrders.isNotEmpty ? liveOrders : _sampleOrders;

    final searchQuery = _searchCtrl.text.toLowerCase();
    final filtered = allOrders.where((o) {
      final matchesSearch = searchQuery.isEmpty ||
          o.id.toLowerCase().contains(searchQuery) ||
          o.buyerName.toLowerCase().contains(searchQuery) ||
          o.productName.toLowerCase().contains(searchQuery);
      final matchesStatus = _selectedStatusFilter == 'All' || o.orderStatus.toLowerCase() == _selectedStatusFilter.toLowerCase();
      return matchesSearch && matchesStatus;
    }).toList();

    final totalCount = allOrders.length;
    final pendingCount = allOrders.where((o) => o.orderStatus == 'Pending' || o.orderStatus == 'Confirmed' || o.orderStatus == 'Packed').length;
    final inTransitCount = allOrders.where((o) => o.orderStatus == 'Shipped' || o.orderStatus == 'ReadyToShip').length;
    final totalRev = allOrders.fold<double>(0, (sum, o) => sum + o.finalPayout);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Orders Management & Shipping Desk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Process customer orders, print airway bills, track dispatch status and manage logistics.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Orders report exported to CSV!'), backgroundColor: Color(0xFF059669)),
                      );
                    },
                    icon: const Icon(Icons.download_outlined, size: 14),
                    label: const Text('Export Orders CSV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: count,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                children: [
                  _buildKpiCard('Total Orders', '$totalCount Orders', Icons.shopping_bag_outlined, const Color(0xFF0284C7)),
                  _buildKpiCard('Pending Dispatch', '$pendingCount Orders', Icons.pending_actions_outlined, const Color(0xFFEA580C)),
                  _buildKpiCard('Shipped & In Transit', '$inTransitCount Orders', Icons.local_shipping_outlined, const Color(0xFF7C3AED)),
                  _buildKpiCard('Net Order Revenue', 'PKR ${(totalRev / 1000).toStringAsFixed(1)}k', Icons.payments_outlined, const Color(0xFF059669)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Sub-Tab Switcher (Orders List vs. Shipping Logistics)
          Row(
            children: [
              ChoiceChip(
                label: const Text('All Orders Desk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                selected: _activeSubTab == 0,
                selectedColor: const Color(0xFF2563EB),
                labelStyle: TextStyle(color: _activeSubTab == 0 ? Colors.white : const Color(0xFF475569)),
                onSelected: (_) => setState(() => _activeSubTab = 0),
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: const Text('Logistics & Shipping Partners', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                selected: _activeSubTab == 1,
                selectedColor: const Color(0xFF2563EB),
                labelStyle: TextStyle(color: _activeSubTab == 1 ? Colors.white : const Color(0xFF475569)),
                onSelected: (_) => setState(() => _activeSubTab = 1),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_activeSubTab == 1) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Logistics Partners (Shipping Logistics)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  const Text('Configure automated courier integrations and self-shipping options.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 16),
                  _buildLogisticsTile('Apna Express (Default Partner)', 'Fast doorstep pickup, commission linked, automated tracking', true),
                  const SizedBox(height: 12),
                  _buildLogisticsTile('TCS Courier Express', 'Nationwide coverage with self-dispatch booking numbers', true),
                  const SizedBox(height: 12),
                  _buildLogisticsTile('Leopard Courier Services', 'Ideal for COD bulk shipments across tier-2 cities', false),
                ],
              ),
            ),
          ] else ...[
            // Controls & Filters Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Search Input
                      Expanded(
                        flex: 3,
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Search order ID, buyer name, or product title...',
                              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Status Dropdown
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 38,
                          child: DropdownButtonFormField<String>(
                            value: _selectedStatusFilter,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All Order Statuses')),
                              DropdownMenuItem(value: 'Pending', child: Text('Pending Approval')),
                              DropdownMenuItem(value: 'Confirmed', child: Text('Confirmed')),
                              DropdownMenuItem(value: 'Packed', child: Text('Packed')),
                              DropdownMenuItem(value: 'Shipped', child: Text('In Transit (Shipped)')),
                              DropdownMenuItem(value: 'Delivered', child: Text('Delivered')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedStatusFilter = v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Table Header Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: const [
                        Expanded(flex: 3, child: Text('ORDER ID & BUYER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                        Expanded(flex: 4, child: Text('PRODUCT & SHIPPING ADDRESS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                        Expanded(flex: 2, child: Text('NET PAYOUT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                        Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                        Expanded(flex: 3, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Orders List
                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      child: const Center(
                        child: Text('No orders match your active search or filter criteria.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final order = filtered[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order ID & Buyer
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(order.id, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                    const SizedBox(height: 2),
                                    Text(order.buyerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                                    Text(order.paymentMethod, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),

                              // Product & Shipping Address
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(order.productName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 2),
                                    Text(order.shippingAddress, style: const TextStyle(fontSize: 11, color: Color(0xFF475569)), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),

                              // Payout
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('PKR ${order.finalPayout.toInt()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    Text('Disc: PKR ${order.couponDiscount.toInt()}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ),

                              // Status
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildStatusBadge(order.orderStatus),
                                ),
                              ),

                              // Actions
                              Expanded(
                                flex: 3,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (order.orderStatus == 'Pending')
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() => order.orderStatus = 'Confirmed');
                                          widget.state.updateOrderStatus(order.id, 'Confirmed');
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                                        child: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    if (order.orderStatus == 'Confirmed')
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() => order.orderStatus = 'Packed');
                                          widget.state.updateOrderStatus(order.id, 'Packed');
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                                        child: const Text('Pack Order', style: TextStyle(fontSize: 11)),
                                      ),
                                    if (order.orderStatus == 'Packed')
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() => order.orderStatus = 'Shipped');
                                          widget.state.updateOrderStatus(order.id, 'Shipped');
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                                        child: const Text('Ship Order', style: TextStyle(fontSize: 11)),
                                      ),
                                    if (order.orderStatus == 'Shipped' || order.orderStatus == 'Delivered') ...[
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Airway Bill Shipping Label sent to printer!'), backgroundColor: Color(0xFF059669)),
                                          );
                                        },
                                        icon: const Icon(Icons.print_outlined, size: 14),
                                        label: const Text('Label', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF2563EB),
                                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        ),
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
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// 2. Executive Returns & Disputes Desk Section
class SellerReturnsDisputesSection extends StatefulWidget {
  final AppStateProvider state;
  final String activeSellerId;

  const SellerReturnsDisputesSection({
    super.key,
    required this.state,
    required this.activeSellerId,
  });

  @override
  State<SellerReturnsDisputesSection> createState() => _SellerReturnsDisputesSectionState();
}

class _SellerReturnsDisputesSectionState extends State<SellerReturnsDisputesSection> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedFilter = 'All';

  final List<Map<String, String>> _returnDisputes = [
    {
      'returnId': 'RET-884210',
      'orderId': 'ORD-984102',
      'buyerName': 'Hamza Ahmed',
      'phone': '0300-1234567',
      'productName': 'Embroidered Cotton Kurta - Royal Blue',
      'reason': 'Fabric defective / Tear on left sleeve',
      'refundAmount': '3,500',
      'photos': '2 Evidence Photos',
      'status': 'Pending Seller Review',
    },
    {
      'returnId': 'RET-884211',
      'orderId': 'ORD-984090',
      'buyerName': 'Fatima Shah',
      'phone': '0321-9876543',
      'productName': 'Wireless Bluetooth Earbuds Pro',
      'reason': 'Right earbud not charging in case',
      'refundAmount': '4,200',
      'photos': '1 Video Clip',
      'status': 'Approved & Refunded',
    },
    {
      'returnId': 'RET-884212',
      'orderId': 'ORD-983995',
      'buyerName': 'Tariq Mehmood',
      'phone': '0333-5551234',
      'productName': 'Men Leather Formal Shoes - Size 42',
      'reason': 'Changed mind / Size doesn\'t fit',
      'refundAmount': '6,800',
      'photos': 'None',
      'status': 'Rejected Request',
    },
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _buildKpiBox(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg = const Color(0xFFFEF3C7);
    Color text = const Color(0xFFB45309);

    if (status == 'Approved & Refunded') {
      bg = const Color(0xFFECFDF5);
      text = const Color(0xFF059669);
    } else if (status == 'Rejected Request') {
      bg = const Color(0xFFFEF2F2);
      text = const Color(0xFFDC2626);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = _searchCtrl.text.toLowerCase();
    final filtered = _returnDisputes.where((r) {
      final matchesSearch = searchQuery.isEmpty ||
          r['returnId']!.toLowerCase().contains(searchQuery) ||
          r['orderId']!.toLowerCase().contains(searchQuery) ||
          r['buyerName']!.toLowerCase().contains(searchQuery);
      final matchesFilter = _selectedFilter == 'All' || r['status'] == _selectedFilter;
      return matchesSearch && matchesFilter;
    }).toList();

    final pendingCount = _returnDisputes.where((r) => r['status'] == 'Pending Seller Review').length;
    final approvedCount = _returnDisputes.where((r) => r['status'] == 'Approved & Refunded').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Returns, Refunds & Buyer Disputes Desk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Review customer return requests, inspect photo evidence, and manage dispute resolutions.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Marketplace Return SLA & Buyer Protection Policy: 7-Day Free Returns'), backgroundColor: Color(0xFF0284C7)),
                  );
                },
                icon: const Icon(Icons.info_outline, size: 14),
                label: const Text('Return Policy & SLAs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: count,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                children: [
                  _buildKpiBox('Pending Requests', '$pendingCount Review Pending', Icons.pending_actions_outlined, const Color(0xFFEA580C)),
                  _buildKpiBox('Approved & Refunded', '$approvedCount Processed', Icons.check_circle_outline, const Color(0xFF059669)),
                  _buildKpiBox('Dispute Value', 'PKR 14,500', Icons.published_with_changes_outlined, const Color(0xFF7C3AED)),
                  _buildKpiBox('Resolution SLA Rate', '98.5% On Time', Icons.speed_outlined, const Color(0xFF0284C7)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Controls & Data Table
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Search return ID, order ID, or buyer name...',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Filter Status Dropdown
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 38,
                        child: DropdownButtonFormField<String>(
                          value: _selectedFilter,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All Return Statuses')),
                            DropdownMenuItem(value: 'Pending Seller Review', child: Text('Pending Review')),
                            DropdownMenuItem(value: 'Approved & Refunded', child: Text('Approved & Refunded')),
                            DropdownMenuItem(value: 'Rejected Request', child: Text('Rejected Claims')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedFilter = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Table Header Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Expanded(flex: 3, child: Text('RETURN & ORDER ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)))),
                      Expanded(flex: 3, child: Text('BUYER DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)))),
                      Expanded(flex: 4, child: Text('PRODUCT & RETURN REASON', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)))),
                      Expanded(flex: 2, child: Text('REFUND (PKR)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)))),
                      Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)))),
                      Expanded(flex: 3, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)))),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Disputes List
                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: const Center(
                      child: Text('No return claims match your active search or filter criteria.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final bool isPending = item['status'] == 'Pending Seller Review';

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Return & Order ID
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['returnId']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                                  const SizedBox(height: 2),
                                  Text('Order: ${item['orderId']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),

                            // Buyer Details
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['buyerName']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  const SizedBox(height: 2),
                                  Text(item['phone']!, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                                ],
                              ),
                            ),

                            // Product & Reason
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['productName']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text('Reason: ${item['reason']}', style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626)), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text('📷 ${item['photos']}', style: const TextStyle(fontSize: 10, color: Color(0xFF0284C7))),
                                ],
                              ),
                            ),

                            // Refund Value
                            Expanded(
                              flex: 2,
                              child: Text('PKR ${item['refundAmount']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            ),

                            // Status
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _buildStatusPill(item['status']!),
                              ),
                            ),

                            // Actions
                            Expanded(
                              flex: 3,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (isPending) ...[
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() => item['status'] = 'Approved & Refunded');
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Return approved & buyer refund initiated!'), backgroundColor: Color(0xFF059669)),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                                      child: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 6),
                                    OutlinedButton(
                                      onPressed: () {
                                        setState(() => item['status'] = 'Rejected Request');
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Return dispute request rejected.'), backgroundColor: Color(0xFFDC2626)),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDC2626), side: const BorderSide(color: Color(0xFFFECACA)), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                                      child: const Text('Reject', style: TextStyle(fontSize: 11)),
                                    ),
                                  ] else
                                    const Text('Resolved', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
