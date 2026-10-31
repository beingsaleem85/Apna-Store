import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/controllers/orders_controller.dart';
import '../../../../core/services/app_state_provider.dart';

class OrderTrackingEventItem {
  final String status;
  final String description;
  final String? location;
  final DateTime createdAt;

  OrderTrackingEventItem({
    required this.status,
    required this.description,
    this.location,
    required this.createdAt,
  });

  factory OrderTrackingEventItem.fromJson(Map<String, dynamic> json) {
    return OrderTrackingEventItem(
      status: (json['event_type'] ?? json['status'] ?? 'Update').toString(),
      description: (json['description'] ?? '').toString(),
      location: json['location']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class BuyerOrderTrackingScreen extends StatefulWidget {
  final String? orderId;
  const BuyerOrderTrackingScreen({super.key, this.orderId});

  @override
  State<BuyerOrderTrackingScreen> createState() => _BuyerOrderTrackingScreenState();
}

class _BuyerOrderTrackingScreenState extends State<BuyerOrderTrackingScreen> {
  List<OrderTrackingEventItem> _events = [];
  bool _isLoadingEvents = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrderAndTracking();
    });
  }

  Future<void> _loadOrderAndTracking() async {
    final ordersCtrl = context.read<OrdersController>();
    if (ordersCtrl.orders.isEmpty) {
      await ordersCtrl.fetchOrdersFromSupabase();
    }
    final targetOrder = _resolveTargetOrder();
    if (targetOrder != null) {
      await _fetchTrackingEvents(targetOrder.id);
    }
  }

  AppOrder? _resolveTargetOrder() {
    final ordersCtrl = context.read<OrdersController>();
    if (widget.orderId != null) {
      return ordersCtrl.getOrderById(widget.orderId!);
    }
    if (ordersCtrl.orders.isNotEmpty) {
      return ordersCtrl.orders.first;
    }
    return null;
  }

  Future<void> _fetchTrackingEvents(String orderId) async {
    setState(() => _isLoadingEvents = true);
    try {
      final res = await Supabase.instance.client
          .from('order_tracking_events')
          .select('event_type, description, location, created_at')
          .eq('order_id', orderId)
          .order('created_at', ascending: true);

      if (res is List && res.isNotEmpty && mounted) {
        setState(() {
          _events = res.map((r) => OrderTrackingEventItem.fromJson(r)).toList();
        });
      }
    } catch (_) {
      // Keep empty if network/table not populated yet, will fall back to linear order status
    } finally {
      if (mounted) setState(() => _isLoadingEvents = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersController = context.watch<OrdersController>();
    final targetOrder = widget.orderId != null
        ? ordersController.getOrderById(widget.orderId!)
        : (ordersController.orders.isNotEmpty ? ordersController.orders.first : null);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Order Tracking & Details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        centerTitle: false,
      ),
      body: targetOrder == null
          ? _buildEmptyOrdersState()
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Tracking Progression
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            _buildOrderHeaderCard(targetOrder),
                            const SizedBox(height: 16),
                            _buildTrackingTimelineCard(targetOrder),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Column: Order Summary
                      Expanded(
                        flex: 4,
                        child: _buildOrderSummaryCard(targetOrder),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyOrdersState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Orders to Track',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have not placed any orders yet. Once you place an order, live tracking details will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/buyer/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Start Shopping', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeaderCard(AppOrder order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order ID: #${order.id}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusBgColor(order.orderStatus),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.orderStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getStatusTextColor(order.orderStatus),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Courier: ${order.shippingPartner ?? "Marketplace Express"} ${order.trackingNumber != null ? "(Tracking: ${order.trackingNumber})" : ""}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            'Delivery Address: ${order.shippingAddress}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingTimelineCard(AppOrder order) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Delivery Progression',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 20),
          if (_isLoadingEvents)
            const Center(child: CircularProgressIndicator())
          else if (_events.isNotEmpty)
            ..._events.map((e) => _buildTimelineStep(
                  title: e.status,
                  description: e.description + (e.location != null ? ' - ${e.location}' : ''),
                  timeStr: _formatDateTime(e.createdAt),
                  isActive: true,
                  isCompleted: true,
                ))
          else
            ..._buildLinearStatusSteps(order.orderStatus),
        ],
      ),
    );
  }

  List<Widget> _buildLinearStatusSteps(String currentStatus) {
    final stages = ['Pending', 'Confirmed', 'Processing', 'Shipped', 'Delivered'];
    final currentIdx = stages.indexOf(currentStatus);

    return stages.asMap().entries.map((entry) {
      final idx = entry.key;
      final stage = entry.value;
      final isCompleted = currentIdx >= idx;
      final isCurrent = currentIdx == idx;

      return _buildTimelineStep(
        title: stage,
        description: isCurrent
            ? 'Your order is currently $stage.'
            : (isCompleted ? 'Completed' : 'Pending next dispatch phase'),
        timeStr: isCompleted ? 'Recorded' : 'Estimated',
        isActive: isCurrent,
        isCompleted: isCompleted,
      );
    }).toList();
  }

  Widget _buildTimelineStep({
    required String title,
    required String description,
    required String timeStr,
    required bool isActive,
    required bool isCompleted,
  }) {
    final dotColor = isCompleted
        ? const Color(0xFF059669)
        : (isActive ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1));

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
              Container(
                width: 2,
                height: 36,
                color: isCompleted ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard(AppOrder order) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Items & Payment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF475569)),
            ),
            title: Text(
              order.productName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: Text('Payment: ${order.paymentMethod}'),
            trailing: Text(
              'PKR ${order.productPrice.toInt()}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Discount:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              Text('- PKR ${order.couponDiscount.toInt()}', style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
              Text(
                'PKR ${(order.productPrice - order.couponDiscount).clamp(0, 999999).toInt()}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF059669)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return const Color(0xFFD1FAE5);
      case 'shipped':
        return const Color(0xFFDBEAFE);
      case 'cancelled':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return const Color(0xFF065F46);
      case 'shipped':
        return const Color(0xFF1E40AF);
      case 'cancelled':
        return const Color(0xFF991B1B);
      default:
        return const Color(0xFF92400E);
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
