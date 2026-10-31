import 'package:flutter/material.dart';

class SellerNotificationItem {
  final String title;
  final String body;
  final String time;
  final String category; // 'Orders', 'Payouts', 'Logistics', 'Broadcast'
  bool isRead;

  SellerNotificationItem({
    required this.title,
    required this.body,
    required this.time,
    required this.category,
    this.isRead = false,
  });
}

class SellerNotificationsCenterScreen extends StatefulWidget {
  const SellerNotificationsCenterScreen({super.key});

  @override
  State<SellerNotificationsCenterScreen> createState() => _SellerNotificationsCenterScreenState();
}

class _SellerNotificationsCenterScreenState extends State<SellerNotificationsCenterScreen> {
  String _activeTab = 'All';

  bool _pushEnabled = true;
  bool _smsEnabled = true;
  bool _emailEnabled = true;
  bool _soundEnabled = true;

  final List<SellerNotificationItem> _notifications = [
    SellerNotificationItem(
      title: 'New Order Received (ORD-9084)',
      body: 'Customer Usman Tariq placed an order for Rs. 4,500 via COD.',
      time: '10 mins ago',
      category: 'Orders',
    ),
    SellerNotificationItem(
      title: 'Bank Payout Settled Successfully',
      body: 'Rs. 12,500 has been transferred to your Meezan Bank account.',
      time: '1 hour ago',
      category: 'Payouts',
    ),
    SellerNotificationItem(
      title: 'Urgent SLA Warning: 4 Hours Left',
      body: 'Pack and mark ORD-9081 as Ready to Ship to avoid SLA penalty points.',
      time: '2 hours ago',
      category: 'Logistics',
    ),
    SellerNotificationItem(
      title: 'Super Admin Broadcast: 11.11 Festival Live',
      body: 'Campaign registrations are now open for 11.11 Shopping Festival 2026.',
      time: '1 day ago',
      category: 'Broadcast',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _notifications.where((n) {
      if (_activeTab == 'All') return true;
      return n.category == _activeTab;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Center & Alert Preferences'),
        backgroundColor: const Color(0xFF004D40),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (var n in _notifications) {
                  n.isRead = true;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All Notifications Marked as Read!')),
              );
            },
            child: const Text('Mark All Read', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alert Preferences Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Notification Channel Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            dense: true,
                            title: const Text('Mobile Push Alerts'),
                            value: _pushEnabled,
                            activeColor: const Color(0xFF004D40),
                            onChanged: (val) => setState(() => _pushEnabled = val),
                          ),
                        ),
                        Expanded(
                          child: SwitchListTile(
                            dense: true,
                            title: const Text('SMS Order Alerts'),
                            value: _smsEnabled,
                            activeColor: const Color(0xFF004D40),
                            onChanged: (val) => setState(() => _smsEnabled = val),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            dense: true,
                            title: const Text('Email Daily Digest'),
                            value: _emailEnabled,
                            activeColor: const Color(0xFF004D40),
                            onChanged: (val) => setState(() => _emailEnabled = val),
                          ),
                        ),
                        Expanded(
                          child: SwitchListTile(
                            dense: true,
                            title: const Text('Sound Cues on Order'),
                            value: _soundEnabled,
                            activeColor: const Color(0xFF004D40),
                            onChanged: (val) => setState(() => _soundEnabled = val),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Orders', 'Payouts', 'Logistics', 'Broadcast'].map((tab) {
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

            // Notifications Feed
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text('No notifications in this channel.')),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final n = filtered[index];

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: n.category == 'Orders'
                                ? Colors.green
                                : n.category == 'Payouts'
                                    ? const Color(0xFF004D40)
                                    : n.category == 'Logistics'
                                        ? Colors.orange
                                        : Colors.purple,
                            child: Icon(
                              n.category == 'Orders'
                                  ? Icons.shopping_bag
                                  : n.category == 'Payouts'
                                      ? Icons.account_balance_wallet
                                      : n.category == 'Logistics'
                                          ? Icons.local_shipping
                                          : Icons.campaign,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(n.time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          subtitle: Text(n.body, style: const TextStyle(fontSize: 11)),
                          onTap: () {
                            setState(() => n.isRead = true);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
