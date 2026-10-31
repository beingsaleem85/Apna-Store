import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';
import '../../../../core/services/app_state_provider.dart';

class MasterOrdersScreen extends StatefulWidget {
  const MasterOrdersScreen({super.key});

  @override
  State<MasterOrdersScreen> createState() => _MasterOrdersScreenState();
}

class _MasterOrdersScreenState extends State<MasterOrdersScreen> {
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Confirmed', 'Processing', 'Shipped', 'Delivered', 'Cancelled'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  AppOrder? _selectedOrder;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      appState.fetchOrdersFromSupabase().then((_) {
        if (mounted && appState.orders.isNotEmpty) {
          setState(() => _selectedOrder = appState.orders.first);
        }
      });
      if (appState.orders.isNotEmpty && _selectedOrder == null) {
        setState(() => _selectedOrder = appState.orders.first);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final adminState = Provider.of<SuperAdminProvider>(context);

    if (_selectedOrder == null && appState.orders.isNotEmpty) {
      _selectedOrder = appState.orders.first;
    }

    // Filter Orders based on Selected Chip/Tab & Search Query
    final filteredOrders = appState.orders.where((order) {
      final matchesSearch = order.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order.buyerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order.sellerId.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (_selectedFilter == 'Pending') return order.orderStatus == 'Pending';
      if (_selectedFilter == 'Confirmed') return order.orderStatus == 'Confirmed';
      if (_selectedFilter == 'Processing') return order.orderStatus == 'Processing' || order.orderStatus == 'Packed';
      if (_selectedFilter == 'Shipped') return order.orderStatus == 'Shipped';
      if (_selectedFilter == 'Delivered') return order.orderStatus == 'Delivered';
      if (_selectedFilter == 'Cancelled') return order.orderStatus == 'Cancelled';
      return true;
    }).toList();

    final isWide = MediaQuery.of(context).size.width > 1050;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumbs & Header Title
          const Text('Breadcrumbs > Orders > Order Operations', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Order Operations', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      SuperAdminDialogs.showToast(context, 'Bulk moderation queue opened.');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Bulk moderation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      SuperAdminDialogs.showToast(context, 'Bulk actions desk ready.');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Bulk Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Functional Status Tabs
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: ['All', 'Processing', 'Shipped', 'Delivered', 'Cancelled'].map((tab) {
                final isSel = _selectedFilter == tab;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedFilter = tab),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF0F172A) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tab == 'All' ? 'All Orders' : tab,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                          color: isSel ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Search by Order ID, Product, Buyer, Seller...',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                prefixIcon: Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Side-by-Side 2-Column Split: Table (Flex 7) + Order Detail Inspector (Flex 3)
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: _buildOrdersTable(filteredOrders, appState, adminState)),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: _buildOrderDetailDrawer(appState, adminState)),
              ],
            )
          else
            Column(
              children: [
                _buildOrdersTable(filteredOrders, appState, adminState),
                const SizedBox(height: 16),
                _buildOrderDetailDrawer(appState, adminState),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOrdersTable(List<AppOrder> filteredOrders, AppStateProvider appState, SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('Order ID & Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 3, child: Text('Product & Buyer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Amount & Fee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Order Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            if (filteredOrders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.shopping_bag_outlined, size: 48, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text('No platform orders found matching selected filter criteria.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ],
                ),
              )
            else
              ...filteredOrders.map((order) {
                final isSelected = _selectedOrder?.id == order.id;
                final isCancelled = order.orderStatus == 'Cancelled';
                final isDelivered = order.orderStatus == 'Delivered';
                final isShipped = order.orderStatus == 'Shipped';

                return InkWell(
                  onTap: () => setState(() => _selectedOrder = order),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: isSelected ? 1.5 : 1),
                    ),
                    child: Row(
                      children: [
                        // 1. Order ID & Date
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('#${order.id}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(order.shippingSpeed, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            ],
                          ),
                        ),

                        // 2. Product & Buyer
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.productName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text('Buyer: ${order.buyerName}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            ],
                          ),
                        ),

                        // 3. Amount & Fee
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('PKR ${order.productPrice.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
                              const SizedBox(height: 2),
                              Text('Fee: PKR ${order.commissionDeducted.toInt()}', style: const TextStyle(color: Color(0xFFD97706), fontSize: 10, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),

                        // 4. Payment Method
                        Expanded(
                          flex: 2,
                          child: Text(
                            order.paymentMethod,
                            style: const TextStyle(color: Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),

                        // 5. Status Badge
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDelivered
                                  ? const Color(0xFFECFDF5)
                                  : isCancelled
                                      ? const Color(0xFFFEE2E2)
                                      : isShipped
                                          ? const Color(0xFFEFF6FF)
                                          : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              order.orderStatus.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDelivered
                                    ? const Color(0xFF059669)
                                    : isCancelled
                                        ? const Color(0xFFDC2626)
                                        : isShipped
                                            ? const Color(0xFF2563EB)
                                            : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ),

                        // 6. Order Actions
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'View Timeline',
                                icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF0F172A)),
                                onPressed: () => _showOrderTimelineModal(order),
                              ),
                              IconButton(
                                tooltip: 'Edit Order Status',
                                icon: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF2563EB)),
                                onPressed: () => _showEditOrderModal(order, appState, adminState),
                              ),
                              IconButton(
                                tooltip: isCancelled ? 'Already Cancelled' : 'Cancel Order',
                                icon: Icon(
                                  Icons.cancel_outlined,
                                  size: 18,
                                  color: isCancelled ? const Color(0xFF94A3B8) : const Color(0xFFEF4444),
                                ),
                                onPressed: isCancelled
                                    ? null
                                    : () async {
                                        final reason = await SuperAdminDialogs.showReasonInput(
                                          context: context,
                                          title: 'Cancel Platform Order',
                                          labelText: 'Cancellation Reason',
                                          hintText: 'Enter reason for admin order cancellation...',
                                        );
                                        if (reason != null && reason.isNotEmpty) {
                                          appState.updateOrderStatus(order.id, 'Cancelled');
                                          setState(() => order.orderStatus = 'Cancelled');
                                          adminState.logAuditAction('ORDER_CANCELLATION', '#${order.id}', 'Cancelled order. Reason: $reason');
                                          if (mounted) SuperAdminDialogs.showToast(context, 'Order #${order.id} Cancelled.', isError: true);
                                        }
                                      },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetailDrawer(AppStateProvider appState, SuperAdminProvider adminState) {
    if (_selectedOrder == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text('Select an order from the list to view full details.', style: TextStyle(color: Color(0xFF64748B))),
        ),
      );
    }

    final order = _selectedOrder!;

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
          // Title Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: Color(0xFF0F172A), size: 20),
                  SizedBox(width: 8),
                  Text('Order Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                child: Text(order.orderStatus, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Order Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ORDER #${order.id}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                const SizedBox(height: 4),
                Text(order.productName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Paid:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text('PKR ${order.productPrice.toInt()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Platform Fee:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text('PKR ${order.commissionDeducted.toInt()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Seller Payout:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text('PKR ${order.finalPayout.toInt()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Customer (Buyer) Info
          const Text('Customer (Buyer)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(order.buyerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          Text(order.shippingAddress, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
          const SizedBox(height: 12),

          // Payment Status
          const Text('Payment Status', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text('VERIFIED (${order.paymentMethod})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
          const SizedBox(height: 12),

          // Seller Info
          const Text('Seller Info', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(order.sellerId, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 12),

          // Shipment & Courier
          const Text('Shipment & Courier', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text('${order.shippingPartner ?? 'TCS Express'} (Tracking: ${order.trackingNumber ?? 'TCS-9812-PK'})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
          const SizedBox(height: 20),

          // Order Actions Buttons (Matching Exact Original Names)
          const Text('Order Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.file_download_outlined, size: 14),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  onPressed: () {
                    SuperAdminDialogs.showToast(context, 'Exporting invoice for Order #${order.id}...');
                  },
                  label: const Text('Export Order', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note, size: 14),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  onPressed: () => _showEditOrderModal(order, appState, adminState),
                  label: const Text('Edit Ordering', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditOrderModal(AppOrder order, AppStateProvider appState, SuperAdminProvider adminState) {
    String selectedStatus = order.orderStatus;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Edit Order — #${order.id}', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Product: ${order.productName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              Text('Buyer: ${order.buyerName}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              const Text('Update Order Fulfillment Status:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                dropdownColor: Colors.white,
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: ['Pending', 'Confirmed', 'Processing', 'Shipped', 'Delivered', 'Cancelled'].map((s) {
                  return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedStatus = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              onPressed: () {
                setState(() => order.orderStatus = selectedStatus);
                adminState.logAuditAction('ORDER_STATUS_UPDATE', '#${order.id}', 'Admin updated status to $selectedStatus');
                Navigator.pop(ctx);
                SuperAdminDialogs.showToast(context, 'Order #${order.id} status updated to $selectedStatus!');
              },
              child: const Text('Save Status'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderTimelineModal(AppOrder order) {
    final isPlaced = true;
    final isPacked = order.orderStatus != 'Pending';
    final isShipped = order.orderStatus == 'Shipped' || order.orderStatus == 'Delivered';
    final isDelivered = order.orderStatus == 'Delivered';
    final isCancelled = order.orderStatus == 'Cancelled';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: AppBreakpoints.getResponsiveDialogWidth(context, defaultDesktopWidth: 540),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF2563EB), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order Timeline — #${order.id}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text('Placed on 27 July 2026 • ${order.shippingSpeed}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Color(0xFF64748B)), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              // Product & Courier Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFCBD5E1))),
                          child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF2563EB), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                              const SizedBox(height: 2),
                              Text('Buyer: ${order.buyerName} • Total: PKR ${order.productPrice.toInt()}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            Text(order.shippingAddress, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tracking Number Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_shipping, size: 16, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Text('${order.shippingPartner ?? 'TCS Express'}: ${order.trackingNumber ?? 'TCS-9812-PK'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      ],
                    ),
                    const Icon(Icons.copy, size: 14, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Beautiful Stepper Timeline
              const Text('Live Fulfillment Journey:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),

              _buildModernStep(
                icon: Icons.shopping_cart_checkout,
                title: 'Order Placed by Customer',
                time: '27 July 2026, 11:30 AM',
                isCompleted: isPlaced,
                isLast: false,
              ),
              _buildModernStep(
                icon: Icons.inventory_2_outlined,
                title: 'Merchant Packed & Prepared',
                time: isPacked ? '27 July 2026, 03:45 PM' : 'Pending vendor action',
                isCompleted: isPacked,
                isLast: false,
              ),
              _buildModernStep(
                icon: Icons.local_shipping_outlined,
                title: 'Handed to Courier (In Transit)',
                time: isShipped ? '28 July 2026, 09:15 AM' : 'Awaiting courier pickup',
                isCompleted: isShipped,
                isLast: false,
              ),
              _buildModernStep(
                icon: Icons.verified_outlined,
                title: isCancelled ? 'Order Cancelled' : 'Delivered to Destination',
                time: isDelivered ? '29 July 2026, 02:20 PM' : isCancelled ? 'Order was cancelled' : 'Expected delivery in 24 hours',
                isCompleted: isDelivered || isCancelled,
                isCancelled: isCancelled,
                isLast: true,
              ),
              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close Inspector', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernStep({
    required IconData icon,
    required String title,
    required String time,
    required bool isCompleted,
    bool isCancelled = false,
    required bool isLast,
  }) {
    final color = isCancelled
        ? const Color(0xFFDC2626)
        : isCompleted
            ? const Color(0xFF10B981)
            : const Color(0xFF94A3B8);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isCompleted || isCancelled ? color.withOpacity(0.12) : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
                child: Icon(
                  isCancelled ? Icons.close : (isCompleted ? Icons.check : icon),
                  size: 14,
                  color: color,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isCompleted || isCancelled ? FontWeight.bold : FontWeight.w500,
                      color: isCompleted || isCancelled ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      color: isCompleted ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
