import 'package:flutter/material.dart';

class StaffMemberItem {
  final String name;
  final String email;
  String role;
  bool isCatalogAllowed;
  bool isOrdersAllowed;
  bool isFinanceAllowed;

  StaffMemberItem({
    required this.name,
    required this.email,
    required this.role,
    this.isCatalogAllowed = true,
    this.isOrdersAllowed = true,
    this.isFinanceAllowed = false,
  });
}

class SellerStaffPermissionsScreen extends StatefulWidget {
  const SellerStaffPermissionsScreen({super.key});

  @override
  State<SellerStaffPermissionsScreen> createState() => _SellerStaffPermissionsScreenState();
}

class _SellerStaffPermissionsScreenState extends State<SellerStaffPermissionsScreen> {
  final List<StaffMemberItem> _staff = [
    StaffMemberItem(name: 'Ali Khan', email: 'ali.dispatch@store.com', role: 'Order Dispatcher', isFinanceAllowed: false),
    StaffMemberItem(name: 'Zahid Mahmood', email: 'zahid.accounts@store.com', role: 'Finance Officer', isFinanceAllowed: true),
  ];

  final List<String> _auditLogs = [
    'Ali Khan marked ORD-9084 as Packed & Ready to Ship (10 mins ago)',
    'Zahid Mahmood generated Local Tax Invoice #8902 (2 hours ago)',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Roles & RBAC Team Permissions'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Invite Staff Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Store Sub-Account Staff Members', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Invite Staff Member'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                  onPressed: () => _showInviteStaffModal(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Staff Members List
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _staff.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final s = _staff[index];

                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF004D40),
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('${s.email} | Role: ${s.role}', style: const TextStyle(fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(s.isFinanceAllowed ? 'Full Access' : 'Limited Access', style: const TextStyle(fontSize: 10, color: Colors.white)),
                          backgroundColor: s.isFinanceAllowed ? const Color(0xFF004D40) : Colors.orange,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            setState(() => _staff.removeAt(index));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Revoked access for ${s.name}')),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Audit Trail Log
            const Text('Staff Activity Audit Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _auditLogs.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.history, color: Colors.blueGrey),
                    title: Text(_auditLogs[index], style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteStaffModal() async {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController emailCtrl = TextEditingController();

    try {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Invite Sub-Account Staff', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Staff Full Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Staff Email Address', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  if (mounted) {
                    setState(() {
                      _staff.add(StaffMemberItem(name: nameCtrl.text, email: emailCtrl.text, role: 'Store Assistant'));
                    });
                  }
                }
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Staff Invitation Sent via Email!')),
                  );
                }
              },
              child: const Text('Send Invitation'),
            ),
          ],
        ),
      );
    } finally {
      nameCtrl.dispose();
      emailCtrl.dispose();
    }
  }
}
