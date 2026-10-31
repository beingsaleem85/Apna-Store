import 'package:flutter/material.dart';

class ReturnRequestItem {
  final String returnId;
  final String orderId;
  final String customerName;
  final String itemTitle;
  final String returnReason;
  final double amount;
  String status; // 'Pending Action', 'Approved', 'QC Passed', 'Disputed'

  ReturnRequestItem({
    required this.returnId,
    required this.orderId,
    required this.customerName,
    required this.itemTitle,
    required this.returnReason,
    required this.amount,
    required this.status,
  });
}

class SellerReturnsDisputesScreen extends StatefulWidget {
  const SellerReturnsDisputesScreen({super.key});

  @override
  State<SellerReturnsDisputesScreen> createState() => _SellerReturnsDisputesScreenState();
}

class _SellerReturnsDisputesScreenState extends State<SellerReturnsDisputesScreen> {
  String _activeTab = 'Pending Action';

  final List<ReturnRequestItem> _returns = [
    ReturnRequestItem(
      returnId: 'RET-801',
      orderId: 'ORD-9081',
      customerName: 'Kashif Ali',
      itemTitle: 'Embroidered Lawn 3-Piece Suit (Medium)',
      returnReason: 'Size is smaller than size chart specs.',
      amount: 2999.0,
      status: 'Pending Action',
    ),
    ReturnRequestItem(
      returnId: 'RET-802',
      orderId: 'ORD-9055',
      customerName: 'Zubair Ahmed',
      itemTitle: 'Men Leather Jacket (Large)',
      returnReason: 'Zipper is broken upon unboxing.',
      amount: 4500.0,
      status: 'Approved',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _returns.where((r) => r.status == _activeTab).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Returns, Exchanges & Disputes Desk'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Returns Policy Overview Header Banner
            Card(
              color: const Color(0xFF004D40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.assignment_return, color: Color(0xFFFDB913), size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('7-Day Marketplace Return & Dispute Resolution Policy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(height: 2),
                          Text('Review customer return requests within 48 hours to prevent automatic refund approvals.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Pending Action', 'Approved', 'QC Passed', 'Disputed'].map((tab) {
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

            // Return Items List
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text('No return requests in this category.')),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = filtered[index];

                        return ListTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${item.returnId} (${item.orderId})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Rs. ${item.amount.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item.customerName} — ${item.itemTitle}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text('Reason: ${item.returnReason}', style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => _showDisputeClaimModal(item),
                                    child: const Text('File Dispute Claim', style: TextStyle(fontSize: 11)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
                                    onPressed: () {
                                      setState(() => item.status = 'Approved');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Return Request ${item.returnId} Approved!')),
                                      );
                                    },
                                    child: const Text('Approve Return', style: TextStyle(fontSize: 11)),
                                  ),
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

  void _showDisputeClaimModal(ReturnRequestItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('File Dispute Claim — ${item.returnId}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Upload evidence photos/video proof for Super Admin arbitration.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Upload Unboxing Video Proof'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video Evidence Uploaded!')));
              },
            ),
            const SizedBox(height: 12),
            const TextField(
              maxLines: 3,
              decoration: InputDecoration(labelText: 'Dispute Explanation Notes', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              setState(() => item.status = 'Disputed');
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Dispute Claim for ${item.returnId} Submitted to Super Admin!')),
              );
            },
            child: const Text('Submit Dispute Claim'),
          ),
        ],
      ),
    );
  }
}
