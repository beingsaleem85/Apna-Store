import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';

class BroadcastItem {
  final String id;
  final String title;
  final String body;
  final String targetAudience;
  final int recipientCount;
  final DateTime sentAt;
  final String status;

  BroadcastItem({
    required this.id,
    required this.title,
    required this.body,
    required this.targetAudience,
    required this.recipientCount,
    required this.sentAt,
    this.status = 'Delivered',
  });
}

class NotificationsBroadcastScreen extends StatefulWidget {
  const NotificationsBroadcastScreen({super.key});

  @override
  State<NotificationsBroadcastScreen> createState() => _NotificationsBroadcastScreenState();
}

class _NotificationsBroadcastScreenState extends State<NotificationsBroadcastScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  String _selectedAudience = 'All Marketplace Users';

  final List<BroadcastItem> _broadcastHistory = [];

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = Provider.of<SuperAdminProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Executive Breadcrumb & Header
          const Text('Breadcrumbs > Marketing > Push & SMS Broadcasts', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Push & SMS Broadcast Desk', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Audience Segments', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Export Logs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Notification Composer Card
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Compose New Broadcast Notification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 16),

                  // Audience Selector Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedAudience,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Target Audience',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      border: OutlineInputBorder(),
                    ),
                    items: ['All Marketplace Users', 'All Registered Customers', 'Approved Sellers Only', 'Active Delivery Riders']
                        .map((aud) => DropdownMenuItem(value: aud, child: Text(aud)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedAudience = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Notification Title
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Notification Title (e.g. Mega Sale Live Now!)',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Message Body
                  TextField(
                    controller: _bodyController,
                    maxLines: 3,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Message Body',
                      labelStyle: TextStyle(color: Color(0xFF64748B)),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('Send Push Broadcast Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                      onPressed: () async {
                        final title = _titleController.text.trim();
                        final body = _bodyController.text.trim();
                        if (title.isNotEmpty && body.isNotEmpty) {
                          int count = 1;
                          try {
                            final targetRole = _selectedAudience.contains('Sellers')
                                ? 'SELLER'
                                : (_selectedAudience.contains('Customers') ? 'BUYER' : 'ALL');
                            final res = await Supabase.instance.client.rpc('admin_broadcast_notification', params: {
                              'p_title': title,
                              'p_body': body,
                              'p_target_role': targetRole,
                            });
                            if (res is Map && res['recipients_count'] != null) {
                              count = (res['recipients_count'] as num).toInt();
                            }
                          } catch (_) {}

                          if (mounted) {
                            setState(() {
                              _broadcastHistory.insert(
                                0,
                                BroadcastItem(
                                  id: 'BRD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                                  title: title,
                                  body: body,
                                  targetAudience: _selectedAudience,
                                  recipientCount: count,
                                  sentAt: DateTime.now(),
                                ),
                              );
                            });
                            adminState.logAuditAction('NOTIFICATION_BROADCAST', title, 'Broadcasted push notification to $_selectedAudience');
                            _titleController.clear();
                            _bodyController.clear();
                            SuperAdminDialogs.showToast(context, 'Broadcast Notification Sent ($count recipients)!');
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sent Notification Transmission History
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Broadcast Transmission History Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 16),

                  if (_broadcastHistory.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text('No broadcast transmissions dispatched yet.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      ),
                    )
                  else
                    ..._broadcastHistory.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active, color: Color(0xFF2563EB), size: 28),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(item.body, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                const SizedBox(height: 4),
                                Text('Audience: ${item.targetAudience} | Recipients: ${item.recipientCount} Users', style: const TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                            child: Text(item.status, style: const TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
