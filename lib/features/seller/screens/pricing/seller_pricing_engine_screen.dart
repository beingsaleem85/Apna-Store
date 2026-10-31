import 'package:flutter/material.dart';

class SellerPricingEngineScreen extends StatefulWidget {
  const SellerPricingEngineScreen({super.key});

  @override
  State<SellerPricingEngineScreen> createState() => _SellerPricingEngineScreenState();
}

class _SellerPricingEngineScreenState extends State<SellerPricingEngineScreen> {
  final TextEditingController _costPriceController = TextEditingController(text: '1800');
  final TextEditingController _sellingPriceController = TextEditingController(text: '2999');
  final TextEditingController _wholesalePriceController = TextEditingController(text: '2400');
  final TextEditingController _freeShippingMinController = TextEditingController(text: '2999');

  bool _autoPriceMatching = true;

  @override
  void dispose() {
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _wholesalePriceController.dispose();
    _freeShippingMinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculator Math
    final double cost = double.tryParse(_costPriceController.text) ?? 0.0;
    final double selling = double.tryParse(_sellingPriceController.text) ?? 0.0;

    final double commissionFee = selling * 0.10; // 10% platform commission
    final double shippingFee = 150.0;
    final double fbrTax = commissionFee * 0.18; // 18% tax on commission

    final double netProfit = selling - cost - commissionFee - shippingFee - fbrTax;
    final double profitMargin = selling > 0 ? (netProfit / selling) * 100 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pricing & Profitability Calculator Engine'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Interactive Profitability Calculator Card
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
                        Icon(Icons.calculate, color: Color(0xFFFDB913), size: 28),
                        SizedBox(width: 12),
                        Text('Net Profit & Margin Live Estimator', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Estimated Net Profit:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text('Rs. ${netProfit.toStringAsFixed(0)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: netProfit >= 0 ? Colors.greenAccent : Colors.redAccent)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Profit Margin %:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text('${profitMargin.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFDB913))),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          _buildDeductionRow('Selling Price', 'Rs. ${selling.toInt()}'),
                          _buildDeductionRow('Product Cost Price', '- Rs. ${cost.toInt()}'),
                          _buildDeductionRow('Platform Commission (10%)', '- Rs. ${commissionFee.toInt()}'),
                          _buildDeductionRow('Estimated Shipping Fee', '- Rs. ${shippingFee.toInt()}'),
                          _buildDeductionRow('Estimated FBR Tax (18% on Comm.)', '- Rs. ${fbrTax.toInt()}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Pricing Inputs
            const Text('Multi-Tier Product Price Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _costPriceController,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Cost Price (Rs.)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _sellingPriceController,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Selling Price (Rs.)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _wholesalePriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Wholesale Tier Price (For > 10 Units)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),

            // Free Shipping Threshold Setup
            const Text('Free Shipping Promotion Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            TextField(
              controller: _freeShippingMinController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Minimum Order Value for Free Shipping (Rs.)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            // Auto-Pricing Matcher Switch
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              child: SwitchListTile(
                title: const Text('Auto-Pricing Competitor Matcher', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Automatically match the lowest market price for identical SKUs.'),
                value: _autoPriceMatching,
                activeColor: const Color(0xFF004D40),
                onChanged: (val) {
                  setState(() => _autoPriceMatching = val);
                },
              ),
            ),
            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Pricing Rules'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pricing Rules & Margins Saved!')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeductionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
