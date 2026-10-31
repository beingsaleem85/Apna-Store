import 'package:flutter/material.dart';

class BuyerReturnsClaimsScreen extends StatefulWidget {
  const BuyerReturnsClaimsScreen({super.key});

  @override
  State<BuyerReturnsClaimsScreen> createState() => _BuyerReturnsClaimsScreenState();
}

class _BuyerReturnsClaimsScreenState extends State<BuyerReturnsClaimsScreen> {
  String _selectedReason = 'Damaged / Broken Item';
  String _selectedRefundDestination = 'Customer Wallet (Instant Deposit)';
  String _selectedReturnMethod = 'Doorstep Courier Pickup';
  bool _isEvidenceUploaded = false;

  final List<String> _returnReasons = [
    'Damaged / Broken Item',
    'Wrong Item Delivered',
    'Size Does Not Fit',
    'Quality Defect / Counterfeit Concern',
  ];

  final List<Map<String, String>> _activeClaims = [
    {
      'claimId': 'CLM-7721',
      'orderId': 'PK-984210',
      'item': 'Embroidered Lawn Suit',
      'status': 'Under Review by Admin Dispute Desk',
      'date': '19 July 2026',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Cancellation & Returns Desk'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Claims Status Section
            if (_activeClaims.isNotEmpty) ...[
              const Text('Active Return Claims:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _activeClaims.length,
                itemBuilder: (context, index) {
                  final claim = _activeClaims[index];
                  return Card(
                    color: Colors.amber.shade50,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.amber)),
                    child: ListTile(
                      leading: const Icon(Icons.gavel, color: Colors.brown),
                      title: Text('Claim #${claim['claimId']} (Order #${claim['orderId']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('${claim['item']} | ${claim['status']}', style: const TextStyle(fontSize: 11, color: Colors.brown)),
                      trailing: const Chip(
                        label: Text('Pending', style: TextStyle(fontSize: 10, color: Colors.white)),
                        backgroundColor: Colors.brown,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            // 1-Click Order Cancellation Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.red),
                        SizedBox(width: 8),
                        Text('1-Click Pre-Dispatch Cancellation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Order #PK-984210 is currently un-shipped. You can cancel now for an instant 100% refund.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('Cancel Order #PK-984210 Now', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Order #PK-984210 Cancelled! Rs. 51,799 refunded to your Wallet.')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Guided Return Request Form Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('File a Return or Exchange Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    const Text('Eligible within 14 days of package delivery.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const Divider(height: 24),

                    // Return Reason Dropdown
                    const Text('Select Reason for Return:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedReason,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: _returnReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (val) => setState(() => _selectedReason = val!),
                    ),
                    const SizedBox(height: 16),

                    // Refund Destination
                    const Text('Preferred Refund Method:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Column(
                      children: ['Customer Wallet (Instant Deposit)', 'Original Bank Account / Debit Card'].map((dest) {
                        return RadioListTile<String>(
                          value: dest,
                          groupValue: _selectedRefundDestination,
                          activeColor: const Color(0xFF004D40),
                          title: Text(dest, style: const TextStyle(fontSize: 12)),
                          onChanged: (val) => setState(() => _selectedRefundDestination = val!),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Return Pickup Method
                    const Text('Return Parcel Shipping Method:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Column(
                      children: ['Doorstep Courier Pickup', 'Drop-off at Nearest TCS Station'].map((method) {
                        return RadioListTile<String>(
                          value: method,
                          groupValue: _selectedReturnMethod,
                          activeColor: const Color(0xFF004D40),
                          title: Text(method, style: const TextStyle(fontSize: 12)),
                          onChanged: (val) => setState(() => _selectedReturnMethod = val!),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Photo/Video Evidence Uploader Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.cloud_upload, color: Color(0xFF004D40)),
                              SizedBox(width: 8),
                              Text('Attach Photo & Unboxing Video Evidence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text('Please upload clear photos of the item defect, outer box, and courier shipping label.', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          const SizedBox(height: 12),

                          OutlinedButton.icon(
                            icon: Icon(_isEvidenceUploaded ? Icons.check_circle : Icons.add_a_photo, color: const Color(0xFF004D40)),
                            label: Text(_isEvidenceUploaded ? '3 Evidence Files Uploaded' : 'Upload Photos & Video'),
                            onPressed: () {
                              setState(() => _isEvidenceUploaded = true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Unboxing video and 2 photos attached!')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Claim Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.send),
                        label: const Text('Submit Return Claim to Dispute Desk'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004D40),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          if (_isEvidenceUploaded) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Return Claim Submitted! Ticket #CLM-9910 generated.')),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please attach photo/video evidence before submitting claim.')),
                            );
                          }
                        },
                      ),
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
}
