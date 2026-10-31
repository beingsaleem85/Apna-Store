import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealNotificationItem {
  final String id;
  final String title;
  final String body;
  final String category;
  bool isRead;
  final DateTime createdAt;

  RealNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.isRead,
    required this.createdAt,
  });
}

class SellerNotificationsCenterScreen extends StatefulWidget {
  const SellerNotificationsCenterScreen({super.key});

  @override
  State<SellerNotificationsCenterScreen> createState() => _SellerNotificationsCenterScreenState();
}

class _SellerNotificationsCenterScreenState extends State<SellerNotificationsCenterScreen> {
  String _activeTab = 'All';
  final List<RealNotificationItem> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _notifications.clear();
          _isLoading = false;
        });
        return;
      }

      final data = await Supabase.instance.client
          .from('notifications')
          .select('id, title, body, type, is_read, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _notifications.clear();
          for (final row in (data as List)) {
            _notifications.add(RealNotificationItem(
              id: row['id'].toString(),
              title: (row['title'] ?? 'Notification').toString(),
              body: (row['body'] ?? '').toString(),
              category: (row['type'] ?? 'General').toString(),
              isRead: row['is_read'] == true,
              createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
            ));
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);

      setState(() {
        for (final n in _notifications) {
          n.isRead = true;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All Notifications Marked as Read!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update notifications: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _notifications.where((n) {
      if (_activeTab == 'All') return true;
      return n.category.toLowerCase() == _activeTab.toLowerCase();
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Notification Center'),
        backgroundColor: const Color(0xFF004D40),
        actions: [
          TextButton(
            onPressed: _notifications.isEmpty ? null : _markAllRead,
            child: const Text('Mark All Read', style: TextStyle(color: Colors.white, fontSize: 12)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotifications,
            tooltip: 'Refresh Notifications',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Chips
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

                  // Notifications List
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.notifications_none, size: 48, color: Colors.grey),
                                  SizedBox(height: 12),
                                  Text('No notifications found.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  SizedBox(height: 4),
                                  Text('Alerts regarding orders, payouts, and announcements will appear here.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = filtered[index];

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: item.isRead ? Colors.grey.shade200 : const Color(0xFFE0F2F1),
                                  child: Icon(
                                    Icons.notifications,
                                    color: item.isRead ? Colors.grey : const Color(0xFF004D40),
                                  ),
                                ),
                                title: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: Text(
                                  item.body,
                                  style: const TextStyle(fontSize: 11),
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
}
