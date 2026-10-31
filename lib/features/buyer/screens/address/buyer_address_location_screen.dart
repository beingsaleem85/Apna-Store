import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:apna_store/core/services/app_state_provider.dart';

class BuyerAddressLocationScreen extends StatefulWidget {
  const BuyerAddressLocationScreen({super.key});

  @override
  State<BuyerAddressLocationScreen> createState() => _BuyerAddressLocationScreenState();
}

class _BuyerAddressLocationScreenState extends State<BuyerAddressLocationScreen> {
  // Form Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _promoController = TextEditingController();

  String _selectedProvince = 'Punjab';
  String _selectedCity = 'Lahore';
  String _selectedArea = 'Johar Town';
  String _deliveryLabel = 'HOME'; // 'HOME' or 'OFFICE'

  final List<String> _provinces = [
    'Punjab',
    'Sindh',
    'Khyber Pakhtunkhwa',
    'Balochistan',
    'Islamabad Capital Territory',
    'Azad Kashmir',
    'Gilgit-Baltistan'
  ];

  final List<String> _cities = [
    'Lahore',
    'Karachi',
    'Islamabad',
    'Rawalpindi',
    'Faisalabad',
    'Multan',
    'Peshawar',
    'Quetta',
    'Sialkot',
    'Other'
  ];

  final List<String> _areas = [
    'Johar Town',
    'Model Town',
    'Gulberg III',
    'DHA Phase 5',
    'Bahria Town',
    'F-7 Markaz',
    'Clifton Block 4',
    'Other Area'
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _buildingController.dispose();
    _landmarkController.dispose();
    _addressController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    // Calculate dynamic order summary from AppStateProvider
    int subtotal = 0;
    for (final p in appState.cartProducts) {
      subtotal += int.tryParse(p.price) ?? 1000;
    }

    final uniqueStores = appState.cartProducts.map((p) => p.sellerId).toSet().length;
    final int shippingFee = uniqueStores == 0 ? 0 : uniqueStores * 150;
    final int couponDiscount = subtotal > 0 ? 500 : 0;
    final int finalTotal = (subtotal + shippingFee - couponDiscount).clamp(0, 999999);

    final brandGreen = const Color(0xFF004D40);
    final goldColor = const Color(0xFFFDB913);

    return Scaffold(
      backgroundColor: const Color(0xFFEFF0F5), // Clean background grey tint
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Center constrained content container to keep layout compact and elegant
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Main Content: Delivery Form & Package List
                            Expanded(
                              flex: 7,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDeliveryFormCard(brandGreen, goldColor),
                                  const SizedBox(height: 16),
                                  _buildPackageItemsCard(appState, brandGreen),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Right Summary Sidebar: Promotion, Invoice & Order Summary
                            SizedBox(
                              width: 340,
                              child: Column(
                                children: [
                                  _buildPromotionCard(brandGreen),
                                  const SizedBox(height: 12),
                                  _buildInvoiceContactCard(brandGreen),
                                  const SizedBox(height: 12),
                                  _buildOrderSummaryCard(appState.cartProducts.length, subtotal, shippingFee, couponDiscount, finalTotal, brandGreen, goldColor),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDeliveryFormCard(brandGreen, goldColor),
                            const SizedBox(height: 16),
                            _buildPackageItemsCard(appState, brandGreen),
                            const SizedBox(height: 16),
                            _buildPromotionCard(brandGreen),
                            const SizedBox(height: 12),
                            _buildInvoiceContactCard(brandGreen),
                            const SizedBox(height: 12),
                            _buildOrderSummaryCard(appState.cartProducts.length, subtotal, shippingFee, couponDiscount, finalTotal, brandGreen, goldColor),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Official Apna Store Premium System Footer (Dark Emerald Background)
            _buildOfficialAppFooter(context, screenWidth),
          ],
        ),
      ),
    );
  }

  // 1. Compact Delivery Information Form Card (Apna Store Brand Colors)
  Widget _buildDeliveryFormCard(Color brandGreen, Color goldColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: brandGreen, size: 18),
              const SizedBox(width: 6),
              Text('Delivery Information', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: brandGreen)),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFEAEAEA)),

          // Full Name & Province Row
          Row(
            children: [
              Expanded(
                child: _buildCompactInputField('Full name', _fullNameController, 'Enter your first and last name', brandGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactDropdown('Province', _selectedProvince, _provinces, (val) => setState(() => _selectedProvince = val!), brandGreen),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Phone Number & City Row
          Row(
            children: [
              Expanded(
                child: _buildCompactInputField('Phone Number', _phoneController, 'Please enter your phone number', brandGreen, keyboardType: TextInputType.phone),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactDropdown('City', _selectedCity, _cities, (val) => setState(() => _selectedCity = val!), brandGreen),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Building/House & Area Row
          Row(
            children: [
              Expanded(
                child: _buildCompactInputField('Building / House No / Floor / Street', _buildingController, 'Please enter', brandGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactDropdown('Area', _selectedArea, _areas, (val) => setState(() => _selectedArea = val!), brandGreen),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Landmark & Address Row
          Row(
            children: [
              Expanded(
                child: _buildCompactInputField('Colony / Suburb / Locality / Landmark', _landmarkController, 'Please enter', brandGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCompactInputField('Address', _addressController, 'For Example: House# 123, Street# 123, ABC Road', brandGreen),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Delivery Label Buttons & SAVE Action
          Row(
            children: [
              const Text('Select a label for effective delivery:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              _buildLabelChip('OFFICE', Icons.business, brandGreen),
              const SizedBox(width: 8),
              _buildLabelChip('HOME', Icons.home, brandGreen),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  elevation: 0,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Delivery address saved successfully!')),
                  );
                },
                child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper: Compact Input Field
  Widget _buildCompactInputField(String label, TextEditingController controller, String hint, Color brandGreen, {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SizedBox(
          height: 42,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: const BorderRadius.all(Radius.circular(4)), borderSide: BorderSide(color: brandGreen, width: 1.5)),
            ),
          ),
        ),
      ],
    );
  }

  // Helper: Compact Dropdown
  Widget _buildCompactDropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged, Color brandGreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SizedBox(
          height: 42,
          child: DropdownButtonFormField<String>(
            value: value,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
            items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildLabelChip(String label, IconData icon, Color brandGreen) {
    final bool isSelected = _deliveryLabel == label;
    return InkWell(
      onTap: () => setState(() => _deliveryLabel = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? brandGreen.withOpacity(0.08) : Colors.white,
          border: Border.all(color: isSelected ? brandGreen : Colors.grey.shade300, width: 1.5),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? brandGreen : Colors.grey),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? brandGreen : Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Package Items & Delivery Option Card (Apna Store Emerald Theme)
  Widget _buildPackageItemsCard(AppStateProvider appState, Color brandGreen) {
    final products = appState.cartProducts;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Package 1 of 1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: brandGreen)),
              const Text('Shipped by Official Vendor', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const Divider(height: 20, color: Color(0xFFEAEAEA)),

          // Delivery Option Selection Box (Apna Store Green Selected Card)
          Container(
            width: 260,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50.withOpacity(0.4),
              border: Border.all(color: brandGreen, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: brandGreen, size: 16),
                    const SizedBox(width: 6),
                    const Text('Rs. 150', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 2),
                const Padding(
                  padding: EdgeInsets.only(left: 22),
                  child: Text('Standard Delivery', style: TextStyle(fontSize: 11, color: Colors.black87)),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.only(left: 22),
                  child: Text('Guaranteed in 3-5 business days by TCS', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Render Product List Tiles
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text('No items in cart to ship.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              separatorBuilder: (ctx, i) => const Divider(height: 16, color: Color(0xFFF4F4F4)),
              itemBuilder: (context, index) {
                final p = products[index];
                final priceVal = int.tryParse(p.price) ?? 1000;
                final originalPrice = (priceVal * 1.35).toInt();

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        p.imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          width: 60, height: 60, color: Colors.grey.shade200,
                          child: const Icon(Icons.shopping_bag, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('Category: ${p.category}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Rs. $priceVal', style: TextStyle(fontWeight: FontWeight.bold, color: brandGreen, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('Rs. $originalPrice', style: const TextStyle(fontSize: 10, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                        const SizedBox(height: 2),
                        const Text('-27%', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(height: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            appState.removeFromCart(p.id);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    const Text('Qty: 1', style: TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold)),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // 3. Promotion Code Card (Brand Theme)
  Widget _buildPromotionCard(Color brandGreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Promotion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _promoController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Enter Store / Voucher Code',
                      hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(3), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  elevation: 0,
                ),
                onPressed: () async {
                  final code = _promoController.text.trim();
                  if (code.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a voucher code.')),
                    );
                    return;
                  }
                  final result = await Provider.of<AppStateProvider>(context, listen: false)
                      .validateVoucherOnline(code: code, subtotal: 1000.0);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.isValid
                            ? 'Voucher $code Applied: Rs. ${result.discountAmount.toStringAsFixed(0)} Discount!'
                            : (result.errorMessage ?? 'Invalid voucher code.')),
                      ),
                    );
                  }
                },
                child: const Text('APPLY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 4. Invoice & Contact Info Card (Brand Theme)
  Widget _buildInvoiceContactCard(Color brandGreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Invoice and Contact Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              Text(_fullNameController.text, style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold)),
              Text(_phoneController.text, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text('Edit', style: TextStyle(color: brandGreen, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 5. Order Summary Card & Proceed to Pay Button (Brand Theme)
  Widget _buildOrderSummaryCard(int itemCount, int subtotal, int shippingFee, int couponDiscount, int finalTotal, Color brandGreen, Color goldColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: brandGreen)),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Items Total ($itemCount items)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text('Rs. $subtotal', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Delivery Fee', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('Rs. $shippingFee', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          if (couponDiscount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Voucher Discount', style: TextStyle(fontSize: 12, color: Colors.green)),
                Text('- Rs. $couponDiscount', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
          ],
          const Divider(height: 20, color: Color(0xFFEAEAEA)),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Rs. $finalTotal', style: TextStyle(fontWeight: FontWeight.bold, color: brandGreen, fontSize: 18)),
                  const Text('VAT included, where applicable', style: TextStyle(fontSize: 9, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Proceed to Pay Button (Apna Store Brand Green)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: brandGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                elevation: 1,
              ),
              onPressed: subtotal == 0
                  ? null
                  : () {
                      Navigator.pushNamed(context, '/buyer/payment');
                    },
              child: const Text('Proceed to Pay', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // 6. Official Apna Store Premium System Footer (Identical to BuyerDashboard)
  Widget _buildOfficialAppFooter(BuildContext context, double screenWidth) {
    final footerBg = const Color(0xFF0B5D50);
    final linkColor = const Color(0xFFD1D5DB);

    return Container(
      color: footerBg,
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1180),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Row: 4 Columns of links
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildFooterLinksCol('Quick Links', ['Home', 'Categories', 'Flash Sale', 'New Arrivals', 'Contact Us'], linkColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFooterLinksCol('Customer Service', ['My Account', 'My Orders', 'Wishlist', 'Return Policy', 'FAQs'], linkColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFooterLinksCol('Seller Center', ['Become a Seller', 'Seller Dashboard', 'Seller Support'], linkColor),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFooterLinksCol('Company', ['About Us', 'Privacy Policy', 'Terms & Conditions', 'Careers'], linkColor),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              Divider(color: Colors.white.withOpacity(0.15), height: 1),
              const SizedBox(height: 24),

              // Bottom Row: Copyright & Security Badges
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('© 2026 Apna Store. All rights reserved.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const Row(
                    children: [
                      Icon(Icons.lock, size: 12, color: Colors.amber),
                      SizedBox(width: 4),
                      Text('100% Encrypted & SSL Secure Checkout', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLinksCol(String title, List<String> links, Color linkColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...links.map((link) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                link,
                style: TextStyle(color: linkColor, fontSize: 11),
              ),
            )),
      ],
    );
  }

  // 7. Light Grey Customer Care, Apna Store Info & Mobile App Download Badges (Exact 1:1 match to screenshot)
  Widget _buildCustomerCareAndAppDownloadSection() {
    return Container(
      color: const Color(0xFFEFF0F5),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Column 1: Customer Care
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer Care', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004D40))),
                  SizedBox(height: 10),
                  Text('Help Center\nHow to Buy\nCorporate & Bulk Purchasing\nReturns & Refunds\nApna Store Shop\nContact Us\nPurchase Protection', style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.7)),
                ],
              ),
              // Column 2: Apna Store
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Apna Store', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004D40))),
                  SizedBox(height: 10),
                  Text('About Us\nDigital Payments\nTerms & Conditions\nPrivacy Policy\nNTN Number: 4012118-6\nSTRN Number: 1700401211818\nOnline Shopping App\nSell on Apna Store\nJoin Affiliate Program', style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.7)),
                ],
              ),
              // Column 3: Happy Shopping App Download Badges
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: const Color(0xFF004D40).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF004D40), size: 24),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Happy Shopping', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFDB913))),
                          Text('Download App', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildAppBadge(Icons.apple, 'Available on the', 'App Store'),
                  const SizedBox(height: 8),
                  _buildAppBadge(Icons.play_arrow, 'ANDROID APP ON', 'Google Play'),
                  const SizedBox(height: 8),
                  _buildAppBadge(Icons.phone_android, 'EXPLORE IT ON', 'AppGallery'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBadge(IconData icon, String subtitle, String title) {
    return Container(
      width: 155,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(6)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle, style: const TextStyle(fontSize: 8, color: Colors.white70)),
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
}
