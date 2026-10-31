import 'package:flutter/material.dart';

class SellerAccountHealthScreen extends StatefulWidget {
  const SellerAccountHealthScreen({super.key});

  @override
  State<SellerAccountHealthScreen> createState() => _SellerAccountHealthScreenState();
}

class _SellerAccountHealthScreenState extends State<SellerAccountHealthScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Health & Policy Appeals Desk'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Health Score Banner
            Card(
              color: const Color(0xFF004D40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Padding(
                padding: EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Store Account Health Score', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Text('95 / 100', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                            SizedBox(width: 8),
                            Text('(EXCELLENT)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Penalty Points', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('0 / 48 Points', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFDB913))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Target SLA Meters
            const Text('Seller Performance & Target Metrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.cancel_outlined, color: Colors.green),
                      title: Text('Seller Cancellation Rate', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Target: < 1.0%'),
                      trailing: Text('0.4% (PASSED)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ),
                    Divider(height: 1),
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.timer_off_outlined, color: Colors.green),
                      title: Text('Late Dispatch Rate', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Target: < 2.0%'),
                      trailing: Text('0.8% (PASSED)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ),
                    Divider(height: 1),
                    ListTile(
                      dense: true,
                      leading: Icon(Icons.assignment_return_outlined, color: Colors.green),
                      title: Text('Defective Return Rate', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Target: < 1.5%'),
                      trailing: Text('0.2% (PASSED)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Policy Appeals Card
            Card(
              color: Colors.blue.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.gavel, color: Color(0xFF004D40)),
                        SizedBox(width: 8),
                        Text('Policy Violation Appeals & Reinstatement Studio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('If you receive a penalty notice or policy warning from Super Admin, you may file an official appeal with supporting documents.', style: TextStyle(fontSize: 11, color: Colors.black54)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text('Submit Appeal to Super Admin Committee'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                      onPressed: () => _showAppealModal(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppealModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit Official Policy Appeal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              maxLines: 4,
              decoration: InputDecoration(labelText: 'Appeal Rationale & Explanation', border: OutlineInputBorder()),
            ),
            SizedBox(height: 12),
            OutlinedButton(
              onPressed: null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload_file, size: 16),
                  SizedBox(width: 4),
                  Text('Attach Legal / Proof Document PDF'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Appeal Submitted to Super Admin Arbitration Committee!')),
              );
            },
            child: const Text('Submit Appeal'),
          ),
        ],
      ),
    );
  }
}
