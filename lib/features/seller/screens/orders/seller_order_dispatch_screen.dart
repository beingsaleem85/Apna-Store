import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/app_state_provider.dart';

class SellerOrderDispatchScreen extends StatefulWidget {
  const SellerOrderDispatchScreen({super.key});

  @override
  State<SellerOrderDispatchScreen> createState() => _SellerOrderDispatchScreenState();
}

class _SellerOrderDispatchScreenState extends State<SellerOrderDispatchScreen> {
  String _activeTab = 'New Pending';
  final Set<String> _selectedOrderIds = {};

  String _mapStatusToTab(String orderStatus) {
    switch (orderStatus.toLowerCase()) {
      case 'pending':
      case 'confirmed':
        return 'New Pending';
      case 'packed':
        return 'Packed';
      case 'shipped':
        return 'Ready to Ship';
      case 'delivered':
        return 'Picked Up';
      default:
        return 'New Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateProvider>(context);
    final sellerId = state.loggedInSellerId ?? '';

    // Only real orders belonging to the logged-in seller
    final sellerOrders = state.orders.where((o) {
      if (sellerId.isEmpty) return true;
      return o.sellerId == sellerId || o.sellerId.startsWith('seller_');
    }).toList();

    final filteredOrders = sellerOrders.where((o) => _mapStatusToTab(o.orderStatus) == _activeTab).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Processing & Dispatch Studio'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SLA Countdown Timer Banner
            Card(
              color: Colors.amber.shade800,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.timer, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Fulfillment SLA Timer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(height: 2),
                          Text('Pack and mark "Ready to Ship" within SLA to maintain high seller fulfillment ratings.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Bulk Processing Bar
            if (_selectedOrderIds.isNotEmpty)
              Card(
                color: const Color(0xFF004D40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_selectedOrderIds.length} Orders Selected', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.print, size: 16),
                            label: const Text('Print Bulk Airway Bills'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDB913), foregroundColor: Colors.black),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Printing Airway Bills for ${_selectedOrderIds.length} orders...')),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // Status Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['New Pending', 'Packed', 'Ready to Ship', 'Picked Up'].map((tab) {
                  final isSel = _activeTab == tab;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(tab, style: TextStyle(color: isSel ? Colors.white : Colors.black87, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                      selected: isSel,
                      selectedColor: const Color(0xFF004D40),
                      onSelected: (val) => setState(() => _activeTab = tab),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Orders List
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: filteredOrders.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text('No orders in "$_activeTab" queue.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            const Text('When orders enter this state, they will appear here.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredOrders.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        final isChecked = _selectedOrderIds.contains(order.id);

                        return CheckboxListTile(
                          value: isChecked,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedOrderIds.add(order.id);
                              } else {
                                _selectedOrderIds.remove(order.id);
                              }
                            });
                          },
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${order.id} — ${order.buyerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Rs. ${order.finalPayout.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.productName, style: const TextStyle(fontSize: 11)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(order.paymentMethod, style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                                  _buildActionButton(order, state),
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

  Widget _buildActionButton(AppOrder order, AppStateProvider state) {
    final status = order.orderStatus.toLowerCase();
    if (status == 'pending' || status == 'confirmed') {
      return ElevatedButton.icon(
        icon: const Icon(Icons.inventory_2, size: 14),
        label: const Text('Pack Order', style: TextStyle(fontSize: 11)),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
        onPressed: () async {
          await state.updateOrderStatus(order.id, 'Packed');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Order ${order.id} marked Packed!')),
            );
          }
        },
      );
    } else if (status == 'packed') {
      return ElevatedButton.icon(
        icon: const Icon(Icons.local_shipping, size: 14),
        label: const Text('Ready to Ship', style: TextStyle(fontSize: 11)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
        onPressed: () async {
          await state.updateOrderStatus(order.id, 'Shipped');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Order ${order.id} marked Ready to Ship!')),
            );
          }
        },
      );
    } else {
      return OutlinedButton.icon(
        icon: const Icon(Icons.print, size: 14),
        label: const Text('Print AWB Label', style: TextStyle(fontSize: 11)),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Printing Airway Bill Label for ${order.id}...')),
          );
        },
      );
    }
  }
}
