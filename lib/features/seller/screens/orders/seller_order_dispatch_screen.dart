import 'package:flutter/material.dart';

class OrderDispatchItem {
  final String orderId;
  final String customerName;
  final String itemsSummary;
  final double amount;
  final String paymentMethod;
  String status; // 'New Pending', 'Packed', 'Ready to Ship', 'Picked Up'
  final DateTime orderTime;

  OrderDispatchItem({
    required this.orderId,
    required this.customerName,
    required this.itemsSummary,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.orderTime,
  });
}

class SellerOrderDispatchScreen extends StatefulWidget {
  const SellerOrderDispatchScreen({super.key});

  @override
  State<SellerOrderDispatchScreen> createState() => _SellerOrderDispatchScreenState();
}

class _SellerOrderDispatchScreenState extends State<SellerOrderDispatchScreen> {
  String _activeTab = 'New Pending';
  final Set<String> _selectedOrderIds = {};

  final List<OrderDispatchItem> _orders = [
    OrderDispatchItem(
      orderId: 'ORD-9081',
      customerName: 'Ali Raza',
      itemsSummary: '1x Embroidered Lawn 3-Piece Suit (Black - Medium)',
      amount: 2999.0,
      paymentMethod: 'Cash on Delivery (COD)',
      status: 'New Pending',
      orderTime: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    OrderDispatchItem(
      orderId: 'ORD-9082',
      customerName: 'Saima Khan',
      itemsSummary: '2x Organic Sidr Honey 500g',
      amount: 3200.0,
      paymentMethod: 'Prepaid Wallet',
      status: 'Packed',
      orderTime: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    OrderDispatchItem(
      orderId: 'ORD-9083',
      customerName: 'Usman Tariq',
      itemsSummary: '1x Men Leather Jacket (Brown - XL)',
      amount: 4500.0,
      paymentMethod: 'Cash on Delivery (COD)',
      status: 'Ready to Ship',
      orderTime: DateTime.now().subtract(const Duration(hours: 12)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _orders.where((o) => o.status == _activeTab).toList();

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
                          Text('Fulfillment SLA Timer: 8 Hours Remaining', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(height: 2),
                          Text('Pack and mark "Ready to Ship" to avoid late shipment score penalties.', style: TextStyle(color: Colors.white70, fontSize: 11)),
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
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text('No orders currently in this status.')),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredOrders.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        final isChecked = _selectedOrderIds.contains(order.orderId);

                        return CheckboxListTile(
                          value: isChecked,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedOrderIds.add(order.orderId);
                              } else {
                                _selectedOrderIds.remove(order.orderId);
                              }
                            });
                          },
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${order.orderId} — ${order.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Rs. ${order.amount.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.itemsSummary, style: const TextStyle(fontSize: 11)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(order.paymentMethod, style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                                  _buildActionButton(order),
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

  Widget _buildActionButton(OrderDispatchItem order) {
    if (order.status == 'New Pending') {
      return ElevatedButton.icon(
        icon: const Icon(Icons.inventory_2, size: 14),
        label: const Text('Pack Order', style: TextStyle(fontSize: 11)),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
        onPressed: () {
          setState(() => order.status = 'Packed');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order ${order.orderId} Packed & Invoiced!')),
          );
        },
      );
    } else if (order.status == 'Packed') {
      return ElevatedButton.icon(
        icon: const Icon(Icons.local_shipping, size: 14),
        label: const Text('Ready to Ship', style: TextStyle(fontSize: 11)),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
        onPressed: () {
          setState(() => order.status = 'Ready to Ship');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order ${order.orderId} Marked Ready for Courier Pickup!')),
          );
        },
      );
    } else {
      return OutlinedButton.icon(
        icon: const Icon(Icons.print, size: 14),
        label: const Text('Print AWB Label', style: TextStyle(fontSize: 11)),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Printing Airway Bill Label for ${order.orderId}...')),
          );
        },
      );
    }
  }
}
