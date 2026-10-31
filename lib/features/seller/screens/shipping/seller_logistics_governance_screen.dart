import 'package:flutter/material.dart';

class SellerLogisticsGovernanceScreen extends StatefulWidget {
  const SellerLogisticsGovernanceScreen({super.key});

  @override
  State<SellerLogisticsGovernanceScreen> createState() => _SellerLogisticsGovernanceScreenState();
}

class _SellerLogisticsGovernanceScreenState extends State<SellerLogisticsGovernanceScreen> {
  String _fulfillmentModel = 'Fulfillment by Marketplace (FBP)';
  String _preferredCourier = 'TCS Logistics Express';
  String _pickupSlot = 'Morning (10:00 AM - 01:00 PM)';

  final TextEditingController _lengthController = TextEditingController(text: '30');
  final TextEditingController _widthController = TextEditingController(text: '20');
  final TextEditingController _heightController = TextEditingController(text: '10');
  final TextEditingController _weightController = TextEditingController(text: '1.2');

  @override
  void dispose() {
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Volumetric Weight Math: (L * W * H) / 5000
    final double l = double.tryParse(_lengthController.text) ?? 0.0;
    final double w = double.tryParse(_widthController.text) ?? 0.0;
    final double h = double.tryParse(_heightController.text) ?? 0.0;
    final double actualWeight = double.tryParse(_weightController.text) ?? 0.0;

    final double volumetricWeight = (l * w * h) / 5000.0;
    final double billableWeight = volumetricWeight > actualWeight ? volumetricWeight : actualWeight;
    final double estimatedShippingCost = 150.0 + (billableWeight * 50.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logistics & Courier Governance'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fulfillment Model Selector
            const Text('Fulfillment & Logistics Operating Model', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Fulfillment by Marketplace (FBP)', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Platform handles warehousing, packing, and courier delivery across Pakistan.'),
                      value: 'Fulfillment by Marketplace (FBP)',
                      groupValue: _fulfillmentModel,
                      activeColor: const Color(0xFF004D40),
                      onChanged: (val) {
                        if (val != null) setState(() => _fulfillmentModel = val);
                      },
                    ),
                    const Divider(),
                    RadioListTile<String>(
                      title: const Text('Fulfillment by Seller (FBM)', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Seller packs orders at shop and dispatches via preferred courier partner.'),
                      value: 'Fulfillment by Seller (FBM)',
                      groupValue: _fulfillmentModel,
                      activeColor: const Color(0xFF004D40),
                      onChanged: (val) {
                        if (val != null) setState(() => _fulfillmentModel = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Pakistani Courier Partners & Pickup Slot
            const Text('Courier Partner Assignment & Doorstep Pickup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _preferredCourier,
                    decoration: const InputDecoration(labelText: 'Assigned Courier Partner', border: OutlineInputBorder()),
                    items: [
                      'TCS Logistics Express',
                      'Leopard Courier Services',
                      'Trax Express Logistics',
                      'CallCourier Nationwide'
                    ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _preferredCourier = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _pickupSlot,
                    decoration: const InputDecoration(labelText: 'Pickup Time Window', border: OutlineInputBorder()),
                    items: [
                      'Morning (10:00 AM - 01:00 PM)',
                      'Afternoon (02:00 PM - 05:00 PM)',
                      'Evening (06:00 PM - 08:00 PM)'
                    ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _pickupSlot = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Volumetric Weight & Shipping Fee Calculator Card
            Card(
              color: const Color(0xFF004D40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.scale, color: Color(0xFFFDB913), size: 28),
                        SizedBox(width: 12),
                        Text('Package Volumetric Weight & Rate Calculator', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _lengthController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            onChanged: (v) => setState(() {}),
                            decoration: const InputDecoration(labelText: 'Length (cm)', labelStyle: TextStyle(color: Colors.white70), border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _widthController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            onChanged: (v) => setState(() {}),
                            decoration: const InputDecoration(labelText: 'Width (cm)', labelStyle: TextStyle(color: Colors.white70), border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            onChanged: (v) => setState(() {}),
                            decoration: const InputDecoration(labelText: 'Height (cm)', labelStyle: TextStyle(color: Colors.white70), border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _weightController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            onChanged: (v) => setState(() {}),
                            decoration: const InputDecoration(labelText: 'Actual Wt (kg)', labelStyle: TextStyle(color: Colors.white70), border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Volumetric Wt: ${volumetricWeight.toStringAsFixed(2)} kg', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        Text('Billable Wt: ${billableWeight.toStringAsFixed(2)} kg', style: const TextStyle(color: Color(0xFFFDB913), fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Shipping Fee: Rs. ${estimatedShippingCost.toInt()}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Shipping Logistics Setup'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logistics Preferences Saved Successfully!')),
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
