import 'package:flutter/material.dart';
import '../../../../core/services/app_state_provider.dart';

// 1. Executive Add Product Screen (Daraz / Shopify / Amazon Seller Studio Form Layout)
class SellerAddProductSection extends StatefulWidget {
  final AppStateProvider state;
  final String activeSellerId;

  const SellerAddProductSection({
    super.key,
    required this.state,
    required this.activeSellerId,
  });

  @override
  State<SellerAddProductSection> createState() => _SellerAddProductSectionState();
}

class _SellerAddProductSectionState extends State<SellerAddProductSection> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _brandCtrl;

  String _selectedCategory = 'Apparel & Clothing';
  String _selectedBrand = 'Sapphire';
  String _selectedWeight = '0.5 kg';
  String _selectedDim = '10x5x5 in';
  String _selectedReturn = '7 Days';
  String _uploadedImgUrl = 'https://images.unsplash.com/photo-1583391733956-3750e0ff4e8b?w=600&auto=format&fit=crop';
  bool _isSubmitting = false;

  final List<String> _sampleImages = [
    'https://images.unsplash.com/photo-1583391733956-3750e0ff4e8b?w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=600&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=600&auto=format&fit=crop',
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: 'Embroidered Cotton Kurta');
    _descCtrl = TextEditingController(text: 'Solid Color., multi-graid description');
    _stockCtrl = TextEditingController(text: '50');
    _priceCtrl = TextEditingController(text: '3500');
    _brandCtrl = TextEditingController(text: 'Sapphire');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _stockCtrl.dispose();
    _priceCtrl.dispose();
    _brandCtrl.dispose();
    super.dispose();
  }

  Widget _buildMiniThumb(String url) {
    final bool isSelected = _uploadedImgUrl == url;
    return InkWell(
      onTap: () => setState(() => _uploadedImgUrl = url),
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1), width: isSelected ? 2 : 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 14)),
        ),
      ),
    );
  }

  Widget _buildFormDropdown(String label, List<String> items, String currentVal, Function(String) onChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(currentVal) ? currentVal : items.first,
              isExpanded: true,
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
              icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
              items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
              onChanged: (v) {
                if (v != null) onChange(v);
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 800;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Add Product', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Create a new product listing in your seller catalog.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Product saved as draft!'), backgroundColor: Color(0xFF475569)),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Save as draft', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            if (_titleCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a product title.'), backgroundColor: Color(0xFFDC2626)),
                              );
                              return;
                            }
                            if (_priceCtrl.text.trim().isEmpty || double.tryParse(_priceCtrl.text.trim()) == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a valid price.'), backgroundColor: Color(0xFFDC2626)),
                              );
                              return;
                            }
                            if (_stockCtrl.text.trim().isEmpty || int.tryParse(_stockCtrl.text.trim()) == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a valid stock quantity.'), backgroundColor: Color(0xFFDC2626)),
                              );
                              return;
                            }

                            setState(() => _isSubmitting = true);
                            final newProduct = AppProduct(
                              id: 'prod_${DateTime.now().millisecondsSinceEpoch}',
                              sellerId: widget.activeSellerId,
                              name: _titleCtrl.text.trim(),
                              price: _priceCtrl.text.trim(),
                              rating: '0.0',
                              description: _descCtrl.text.trim(),
                              imageUrl: _uploadedImgUrl,
                              category: _selectedCategory,
                              stock: int.tryParse(_stockCtrl.text.trim()) ?? 0,
                              approvalStatus: 'Pending',
                              variations: const [],
                              wholesalePrices: const {},
                            );

                            widget.state.addProduct(newProduct);
                            setState(() => _isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Product submitted for review (Pending approval).'), backgroundColor: Color(0xFF059669)),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Add product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main 2-Column Form Body
          if (isWeb)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column (Media Upload & Core Product Fields)
                Expanded(
                  flex: 7,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Upload Block
                        const Text('Image upload', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 120,
                              height: 110,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: Image.network(_uploadedImgUrl, width: 120, height: 110, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt_outlined, color: Color(0xFF94A3B8), size: 32),
                                        SizedBox(height: 4),
                                        Text('Upload image', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                      ],
                                    )),
                                  ),
                                  Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                                      child: const Icon(Icons.edit, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 38,
                                    child: TextField(
                                      controller: _titleCtrl,
                                      style: const TextStyle(fontSize: 12),
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 38,
                                    child: TextField(
                                      controller: _descCtrl,
                                      style: const TextStyle(fontSize: 12),
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: _sampleImages.map((url) => _buildMiniThumb(url)).toList(),
                        ),

                        const SizedBox(height: 20),
                        const Divider(color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 16),

                        // Category, Brand, Pricing & Stock Grid Row
                        Row(
                          children: [
                            Expanded(child: _buildFormDropdown('Category', ['Apparel & Clothing', 'Electronics', 'Mobiles', 'Footwear'], _selectedCategory, (v) => setState(() => _selectedCategory = v))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildFormDropdown('Brand', ['Sapphire', 'Khaadi', 'Gul Ahmed', 'Generic'], _selectedBrand, (v) => setState(() => _selectedBrand = v))),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Price (PKR)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 38,
                                    child: TextField(
                                      controller: _priceCtrl,
                                      style: const TextStyle(fontSize: 11),
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Stock Quantity', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 38,
                                    child: TextField(
                                      controller: _stockCtrl,
                                      style: const TextStyle(fontSize: 11),
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                // Right Section (Shipping & Logistics Specs Card)
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Shipping & Logistics Specs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 14),
                        _buildFormDropdown('Package Weight', ['0.5 kg', '1.0 kg', '2.0 kg', '5.0 kg'], _selectedWeight, (v) => setState(() => _selectedWeight = v)),
                        const SizedBox(height: 12),
                        _buildFormDropdown('Dimensions (L x W x H)', ['116"', '10x5x5 in', '15x10x8 in'], _selectedDim, (v) => setState(() => _selectedDim = v)),
                        const SizedBox(height: 12),
                        _buildFormDropdown('Return Warranty (Days)', ['0', '7 Days', '14 Days', '30 Days'], _selectedReturn, (v) => setState(() => _selectedReturn = v)),
                      ],
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                const Text('Mobile product form view', style: TextStyle(color: Color(0xFF64748B))),
              ],
            ),
        ],
      ),
    );
  }
}

// 2. Executive Product Variations & Wholesale Tier Matrix
class SellerProductVariationsSection extends StatefulWidget {
  final AppStateProvider state;

  const SellerProductVariationsSection({
    super.key,
    required this.state,
  });

  @override
  State<SellerProductVariationsSection> createState() => _SellerProductVariationsSectionState();
}

class _SellerProductVariationsSectionState extends State<SellerProductVariationsSection> {
  String _selectedProduct = 'Embroidered Cotton Kurta';

  final List<Map<String, String>> _variants = [
    {'sku': 'KURTA-BLK-S', 'color': 'Jet Black', 'size': 'Small (S)', 'price': '3,500', 'stock': '15', 'status': 'Active'},
    {'sku': 'KURTA-BLK-M', 'color': 'Jet Black', 'size': 'Medium (M)', 'price': '3,500', 'stock': '28', 'status': 'Active'},
    {'sku': 'KURTA-BLK-L', 'color': 'Jet Black', 'size': 'Large (L)', 'price': '3,500', 'stock': '12', 'status': 'Active'},
    {'sku': 'KURTA-BLU-M', 'color': 'Royal Blue', 'size': 'Medium (M)', 'price': '3,650', 'stock': '8', 'status': 'Low Stock'},
    {'sku': 'KURTA-WHT-XL', 'color': 'Off White', 'size': 'X-Large (XL)', 'price': '3,800', 'stock': '0', 'status': 'Out of Stock'},
  ];

  final List<Map<String, String>> _wholesaleTiers = [
    {'minQty': '5 - 9 Units', 'discount': '10% OFF', 'unitPrice': 'PKR 3,150', 'target': 'All Buyers'},
    {'minQty': '10 - 49 Units', 'discount': '18% OFF', 'unitPrice': 'PKR 2,870', 'target': 'Verified B2B Retailers'},
    {'minQty': '50+ Units', 'discount': '25% OFF', 'unitPrice': 'PKR 2,625', 'target': 'Wholesale Distributors'},
  ];

  void _showAddVariantModal() {
    final skuCtrl = TextEditingController(text: 'KURTA-NEW-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    final colorCtrl = TextEditingController(text: 'Emerald Green');
    final sizeCtrl = TextEditingController(text: 'Large (L)');
    final priceCtrl = TextEditingController(text: '3500');
    final stockCtrl = TextEditingController(text: '20');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Add Product Variant SKU', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: skuCtrl, decoration: const InputDecoration(labelText: 'SKU Code', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: colorCtrl, decoration: const InputDecoration(labelText: 'Color / Variant Name', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: sizeCtrl, decoration: const InputDecoration(labelText: 'Size / Dimension', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (PKR)', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock Units', isDense: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _variants.add({
                  'sku': skuCtrl.text,
                  'color': colorCtrl.text,
                  'size': sizeCtrl.text,
                  'price': priceCtrl.text,
                  'stock': stockCtrl.text,
                  'status': (int.tryParse(stockCtrl.text) ?? 0) > 0 ? 'Active' : 'Out of Stock',
                });
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Variant SKU added successfully!'), backgroundColor: Color(0xFF059669)),
              );
            },
            child: const Text('Add Variant'),
          ),
        ],
      ),
    );
  }

  void _showAddTierModal() {
    final qtyCtrl = TextEditingController(text: '20 - 49 Units');
    final discCtrl = TextEditingController(text: '20% OFF');
    final priceCtrl = TextEditingController(text: 'PKR 2,800');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Add Wholesale Pricing Tier', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Minimum Quantity Range', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: discCtrl, decoration: const InputDecoration(labelText: 'Discount Percentage / Label', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Wholesale Price per Unit', isDense: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _wholesaleTiers.add({
                  'minQty': qtyCtrl.text,
                  'discount': discCtrl.text,
                  'unitPrice': priceCtrl.text,
                  'target': 'Verified B2B Buyers',
                });
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Wholesale pricing tier added!'), backgroundColor: Color(0xFF059669)),
              );
            },
            child: const Text('Save Tier Rule'),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiBox(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prodsList = widget.state.products;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Product Variations & Wholesale Desk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Manage multi-attribute SKUs (Size, Color, Material) and B2B bulk volume discount tiers.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _showAddTierModal,
                    icon: const Icon(Icons.card_giftcard, size: 14),
                    label: const Text('Add Bulk Pricing Tier', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _showAddVariantModal,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Variant SKU', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Summary KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth > 900 ? 3 : 1;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: count,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.5,
                children: [
                  _buildKpiBox('Active Variant SKUs', '${_variants.length} Combinations', Icons.style_outlined, const Color(0xFF0284C7)),
                  _buildKpiBox('Configured Attributes', '4 Sizes, 3 Colors', Icons.tune_outlined, const Color(0xFF059669)),
                  _buildKpiBox('B2B Wholesale Rules', '${_wholesaleTiers.length} Active Tiers', Icons.verified_outlined, const Color(0xFF7C3AED)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Select Target Product Selector Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sell_outlined, size: 20, color: Color(0xFF059669)),
                const SizedBox(width: 10),
                const Text('Select Target Product:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: prodsList.any((p) => p.name == _selectedProduct) ? _selectedProduct : (prodsList.isNotEmpty ? prodsList.first.name : _selectedProduct),
                        isExpanded: true,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        items: (prodsList.isNotEmpty ? prodsList.map((p) => p.name).toSet().toList() : [_selectedProduct])
                            .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedProduct = val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Variations Matrix Table Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Variation SKUs for "$_selectedProduct"', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('${_variants.length} Variants Configured', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 16),

                // Table Headers
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Expanded(flex: 3, child: Text('SKU CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 3, child: Text('COLORWAY / VARIANT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('SIZE / SPEC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('PRICE (PKR)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('STOCK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Variation Rows List
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _variants.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final v = _variants[index];
                    final bool isOut = v['status'] == 'Out of Stock';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text(v['sku']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                          Expanded(flex: 3, child: Text(v['color']!, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
                          Expanded(flex: 2, child: Text(v['size']!, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
                          Expanded(flex: 2, child: Text('PKR ${v['price']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${v['stock']} Units',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isOut ? const Color(0xFFDC2626) : const Color(0xFF059669),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                                  onPressed: () {
                                    setState(() {
                                      _variants.removeAt(index);
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Variant SKU removed!'), backgroundColor: Color(0xFFDC2626)),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Wholesale Tier Pricing Table Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('B2B Wholesale Volume Discount Tiers', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        SizedBox(height: 2),
                        Text('Automatic bulk discounts applied when buyers purchase higher quantities.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Table Headers
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Expanded(flex: 3, child: Text('MIN ORDER RANGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)))),
                      Expanded(flex: 3, child: Text('DISCOUNT LABEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)))),
                      Expanded(flex: 3, child: Text('UNIT PRICE (PKR)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)))),
                      Expanded(flex: 3, child: Text('ELIGIBLE BUYER TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)))),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Wholesale Tier Rows
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _wholesaleTiers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final t = _wholesaleTiers[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text(t['minQty']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                          Expanded(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(12)),
                              child: Text(t['discount']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                            ),
                          ),
                          Expanded(flex: 3, child: Text(t['unitPrice']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)))),
                          Expanded(flex: 3, child: Text(t['target']!, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 3. Executive Product List Section (Full Catalog with Live Pre-Loaded Items)
class SellerProductListSection extends StatefulWidget {
  final AppStateProvider state;
  final String activeSellerId;
  final VoidCallback onAddProduct;

  const SellerProductListSection({
    super.key,
    required this.state,
    required this.activeSellerId,
    required this.onAddProduct,
  });

  @override
  State<SellerProductListSection> createState() => _SellerProductListSectionState();
}

class _SellerProductListSectionState extends State<SellerProductListSection> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedStockStatus = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditStockModal(AppProduct product) {
    final stockCtrl = TextEditingController(text: product.stock.toString());
    final priceCtrl = TextEditingController(text: product.price);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Edit ${product.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Price (PKR)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Stock Units', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: stockCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                product.price = priceCtrl.text.isNotEmpty ? priceCtrl.text : product.price;
                product.stock = int.tryParse(stockCtrl.text) ?? product.stock;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Product updated successfully!'), backgroundColor: Color(0xFF059669)),
              );
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allProducts = widget.state.products;
    final sellerProds = allProducts.where((p) => p.sellerId == widget.activeSellerId || p.sellerId.startsWith('seller_')).toList();
    // Ensure displayProds NEVER renders empty catalog by defaulting to full products list
    final displayProds = sellerProds.isNotEmpty ? sellerProds : allProducts;

    final searchQuery = _searchCtrl.text.toLowerCase();
    final filtered = displayProds.where((p) {
      final matchesSearch = searchQuery.isEmpty || p.name.toLowerCase().contains(searchQuery) || p.category.toLowerCase().contains(searchQuery);
      final matchesCat = _selectedCategory == 'All' || p.category.toLowerCase().contains(_selectedCategory.toLowerCase());
      bool matchesStock = true;
      if (_selectedStockStatus == 'In Stock') matchesStock = p.stock > 10;
      if (_selectedStockStatus == 'Low Stock') matchesStock = p.stock > 0 && p.stock <= 10;
      if (_selectedStockStatus == 'Out of Stock') matchesStock = p.stock == 0;
      return matchesSearch && matchesCat && matchesStock;
    }).toList();

    final totalCount = displayProds.length;
    final activeCount = displayProds.where((p) => p.stock > 0).length;
    final lowStockCount = displayProds.where((p) => p.stock <= 10).length;
    final totalVal = displayProds.fold<int>(0, (sum, p) => sum + ((int.tryParse(p.price.replaceAll(',', '')) ?? 1000) * p.stock));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Products Catalog', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Manage store inventory, prices, stock levels, and product listings.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: widget.onAddProduct,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add New Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // KPI Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: count,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                children: [
                  _buildKpiCard('Total Products', '$totalCount Items', Icons.inventory_2_outlined, const Color(0xFF0284C7)),
                  _buildKpiCard('Active Listings', '$activeCount Active', Icons.check_circle_outline, const Color(0xFF059669)),
                  _buildKpiCard('Low / Out of Stock', '$lowStockCount Items', Icons.warning_amber_rounded, const Color(0xFFEA580C)),
                  _buildKpiCard('Total Stock Value', 'PKR ${(totalVal / 1000).toStringAsFixed(0)}k', Icons.payments_outlined, const Color(0xFF7C3AED)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Controls & Filters Bar Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Search products by title or category...',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Category Filter
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 38,
                        child: DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All Categories')),
                            DropdownMenuItem(value: 'Apparel', child: Text('Apparel & Clothing')),
                            DropdownMenuItem(value: 'Electronics', child: Text('Electronics')),
                            DropdownMenuItem(value: 'Mobiles', child: Text('Mobiles')),
                            DropdownMenuItem(value: 'Footwear', child: Text('Footwear')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedCategory = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Stock Filter
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 38,
                        child: DropdownButtonFormField<String>(
                          value: _selectedStockStatus,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All Stock Status')),
                            DropdownMenuItem(value: 'In Stock', child: Text('In Stock (>10)')),
                            DropdownMenuItem(value: 'Low Stock', child: Text('Low Stock (1-10)')),
                            DropdownMenuItem(value: 'Out of Stock', child: Text('Out of Stock (0)')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedStockStatus = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Table Header Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Expanded(flex: 4, child: Text('PRODUCT DETAILS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('PRICE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('STOCK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Products List Stream
                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: const Center(
                      child: Text('No products match your active search or filter criteria.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final bool isLow = item.stock > 0 && item.stock <= 10;
                      final bool isOut = item.stock == 0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            // Product Info (Thumbnail + Title + ID)
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      item.imageUrl,
                                      width: 42,
                                      height: 42,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 42,
                                        height: 42,
                                        color: const Color(0xFFE2E8F0),
                                        child: const Icon(Icons.image, size: 20, color: Color(0xFF94A3B8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text('ID: ${item.id} | ⭐ ${item.rating}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Category
                            Expanded(
                              flex: 2,
                              child: Text(
                                item.category,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // Price
                            Expanded(
                              flex: 2,
                              child: Text(
                                'PKR ${item.price}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ),

                            // Stock Units
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOut ? const Color(0xFFFEF2F2) : (isLow ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${item.stock} Units',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isOut ? const Color(0xFFDC2626) : (isLow ? const Color(0xFFEA580C) : const Color(0xFF059669)),
                                  ),
                                ),
                              ),
                            ),

                            // Status Pill
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isOut ? 'Out of Stock' : 'Active Listing',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isOut ? const Color(0xFF64748B) : const Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                            ),

                            // Action Buttons
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                                    tooltip: 'Edit Price & Stock',
                                    onPressed: () => _showEditStockModal(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                                    tooltip: 'Delete Product',
                                    onPressed: () {
                                      setState(() {
                                        widget.state.products.removeWhere((p) => p.id == item.id);
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Product removed from catalog!'), backgroundColor: Color(0xFFDC2626)),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
