import 'package:flutter/material.dart';

class SellerStoreDecorationScreen extends StatefulWidget {
  const SellerStoreDecorationScreen({super.key});

  @override
  State<SellerStoreDecorationScreen> createState() => _SellerStoreDecorationScreenState();
}

class _SellerStoreDecorationScreenState extends State<SellerStoreDecorationScreen> {
  final TextEditingController _storeNameController = TextEditingController(text: 'Fashion Hub Official Store');
  final TextEditingController _storeBioController = TextEditingController(text: 'Premium eastern fashion, unstitched lawn, and designer apparel in Pakistan.');
  final TextEditingController _storeUrlController = TextEditingController(text: 'apnastore.pk/shop/fashion-hub');
  final TextEditingController _phoneController = TextEditingController(text: '+92 321 9876543');
  final TextEditingController _addressController = TextEditingController(text: 'Shop 14, Main Liberty Market, Gulberg III, Lahore');

  bool _vacationMode = false;

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeBioController.dispose();
    _storeUrlController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storefront Customization & Decoration'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store Badges Banner Card
            Card(
              color: const Color(0xFF004D40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        CircleAvatar(radius: 28, backgroundColor: Colors.white, child: Icon(Icons.store, size: 32, color: Color(0xFF004D40))),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Fashion Hub Official', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              SizedBox(height: 4),
                              Text('Rating: ⭐ 4.8 / 5.0 (1,240 Reviews) | 2,450 Followers', style: TextStyle(fontSize: 12, color: Colors.amberAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 8,
                      children: [
                        _buildBadgeChip('Official Brand', Icons.verified, Colors.lightBlueAccent),
                        _buildBadgeChip('Top Seller', Icons.star, Colors.amberAccent),
                        _buildBadgeChip('Fast Shipping', Icons.local_shipping, Colors.lightGreenAccent),
                        _buildBadgeChip('Verified KYC', Icons.security, Colors.tealAccent),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Vacation Mode Switch Card
            Card(
              color: _vacationMode ? Colors.amber.withOpacity(0.1) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _vacationMode ? Colors.amber : Colors.grey.shade300)),
              child: SwitchListTile(
                title: const Text('Store Vacation Mode (Holiday Mode)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Temporarily pause new customer orders while you are away on holiday.'),
                value: _vacationMode,
                activeColor: Colors.amber,
                onChanged: (val) {
                  setState(() => _vacationMode = val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(val ? 'Vacation Mode Activated!' : 'Vacation Mode Deactivated. Store is live.')),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Store Identity & Branding Details
            const Text('Store Profile & Branding Identity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            TextField(
              controller: _storeNameController,
              decoration: const InputDecoration(labelText: 'Store Display Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _storeUrlController,
              decoration: const InputDecoration(labelText: 'Custom Storefront Web URL', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _storeBioController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Store Biography & Description', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            // Location & Contact Details
            const Text('Store Contact & Physical Location', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Support Phone Number', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Store Pickup Address (Lahore)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Storefront Customization'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Storefront Profile Saved Successfully!')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeChip(String label, IconData icon, Color color) {
    return Chip(
      avatar: Icon(icon, size: 14, color: color),
      label: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
      backgroundColor: Colors.black.withOpacity(0.3),
    );
  }
}
