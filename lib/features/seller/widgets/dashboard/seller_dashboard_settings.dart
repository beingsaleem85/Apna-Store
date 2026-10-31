import 'package:flutter/material.dart';
import '../../../../core/services/app_state_provider.dart';

// 1. Executive Store Design & Homepage Decoration Studio Desk
class SellerStoreDesignSection extends StatefulWidget {
  final AppStateProvider state;
  final AppStore store;

  const SellerStoreDesignSection({
    super.key,
    required this.state,
    required this.store,
  });

  @override
  State<SellerStoreDesignSection> createState() => _SellerStoreDesignSectionState();
}

class _SellerStoreDesignSectionState extends State<SellerStoreDesignSection> {
  late String _bannerUrl;
  late String _logoUrl;
  String _selectedLayoutMode = 'Grid View';
  String _selectedThemePreset = 'Royal Blue Enterprise';

  final List<String> _sampleBanners = [
    'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=1200&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=1200&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1472851294608-062f824d29cc?w=1200&auto=format&fit=crop',
  ];

  final List<String> _sampleLogos = [
    'https://images.unsplash.com/photo-1547082299-de196ea013d6?w=400&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=400&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400&auto=format&fit=crop',
  ];

  @override
  void initState() {
    super.initState();
    _bannerUrl = widget.store.shopBanner.isNotEmpty ? widget.store.shopBanner : _sampleBanners.first;
    _logoUrl = widget.store.shopLogo.isNotEmpty ? widget.store.shopLogo : _sampleLogos.first;
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
                  Text('Store Decoration & Front-page Branding Studio', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Customize your seller store homepage banner, logo icon, category display layout, and featured product slider.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Store Design layout saved & published to live storefront!'), backgroundColor: Color(0xFF059669)),
                  );
                },
                icon: const Icon(Icons.palette_outlined, size: 16),
                label: const Text('Publish Store Design', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // KPI Grid
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
                  _buildKpiBox('Active Store Theme', 'Royal Blue Enterprise', Icons.color_lens_outlined, const Color(0xFF0284C7)),
                  _buildKpiBox('Hero Banner Status', '1920x450 HD Active', Icons.view_carousel_outlined, const Color(0xFF059669)),
                  _buildKpiBox('Brand Logo Badge', 'Verified Store Logo', Icons.verified_outlined, const Color(0xFF7C3AED)),
                  _buildKpiBox('Monthly Storefront Traffic', '14,250 Visitors', Icons.visibility_outlined, const Color(0xFFB45309)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Banner Preview Card
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
                const Text('Storefront Hero Banner (1920 x 450 Recommended)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Image.network(_bannerUrl, width: double.infinity, height: 160, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 160, color: const Color(0xFFE2E8F0))),
                      Positioned(
                        bottom: 12,
                        left: 16,
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                image: DecorationImage(image: NetworkImage(_logoUrl), fit: BoxFit.cover),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.store.shopName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 4, color: Colors.black54)])),
                                const Text('Official Verified Storefront', style: TextStyle(fontSize: 11, color: Colors.white70)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Select Preset Banner:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 8),
                Row(
                  children: _sampleBanners.map((url) {
                    final bool isSel = _bannerUrl == url;
                    return InkWell(
                      onTap: () => setState(() => _bannerUrl = url),
                      child: Container(
                        width: 90,
                        height: 50,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isSel ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1), width: isSel ? 2 : 1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.network(url, fit: BoxFit.cover),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Layout & Color Theme Options Card
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
                const Text('Storefront Layout & Color Customization', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Featured Product Layout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedLayoutMode,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Grid View', child: Text('Standard 4-Column Grid')),
                              DropdownMenuItem(value: 'Carousel Slider', child: Text('Interactive Carousel Slider')),
                              DropdownMenuItem(value: 'Category Tabs', child: Text('Categorized Tabbed View')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedLayoutMode = v);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Color Theme Preset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            value: _selectedThemePreset,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Royal Blue Enterprise', child: Text('Royal Blue Enterprise')),
                              DropdownMenuItem(value: 'Forest Emerald', child: Text('Forest Emerald Green')),
                              DropdownMenuItem(value: 'Midnight Dark Studio', child: Text('Midnight Dark Studio')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedThemePreset = v);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 2. Executive Shipping, Courier Logistics & Dispatch Settings Desk
class SellerShippingSettingsSection extends StatefulWidget {
  final AppStateProvider state;
  final AppStore store;

  const SellerShippingSettingsSection({
    super.key,
    required this.state,
    required this.store,
  });

  @override
  State<SellerShippingSettingsSection> createState() => _SellerShippingSettingsSectionState();
}

class _SellerShippingSettingsSectionState extends State<SellerShippingSettingsSection> {
  late final TextEditingController _standardFeeCtrl;
  late final TextEditingController _expressFeeCtrl;
  late final TextEditingController _freeShippingMinCtrl;

  String _selectedCourier = 'Apna Express Logistics';
  String _selectedReturnPolicy = 'Free 7-Day Returns (Seller Paid)';

  @override
  void initState() {
    super.initState();
    _standardFeeCtrl = TextEditingController(text: '199');
    _expressFeeCtrl = TextEditingController(text: '350');
    _freeShippingMinCtrl = TextEditingController(text: '1999');
  }

  @override
  void dispose() {
    _standardFeeCtrl.dispose();
    _expressFeeCtrl.dispose();
    _freeShippingMinCtrl.dispose();
    super.dispose();
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
                  Text('Logistics, Dispatch Rules & Shipping Rates', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Configure default courier partners (Apna Express, TCS, Leopard), flat delivery fees, free shipping rules, and return policies.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shipping rates & courier logistics rules updated!'), backgroundColor: Color(0xFF059669)),
                  );
                },
                icon: const Icon(Icons.local_shipping_outlined, size: 16),
                label: const Text('Save Shipping Rules', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
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
                  _buildKpiBox('Primary Courier Partner', 'Apna Express', Icons.local_shipping_outlined, const Color(0xFF0284C7)),
                  _buildKpiBox('Standard Shipping Fee', 'PKR ${_standardFeeCtrl.text}', Icons.payments_outlined, const Color(0xFF059669)),
                  _buildKpiBox('Free Shipping Minimum', '> PKR ${_freeShippingMinCtrl.text}', Icons.card_giftcard_outlined, const Color(0xFFB45309)),
                  _buildKpiBox('Dispatch Fulfillment SLA', 'Same-Day (24 Hours)', Icons.speed_outlined, const Color(0xFF7C3AED)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Configuration Form Box
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
                const Text('Courier Partner & Shipping Rates Setup', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _selectedCourier,
                  decoration: const InputDecoration(labelText: 'Primary Logistics Courier', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Apna Express Logistics', child: Text('Apna Express Logistics (Recommended - 24h Delivery)')),
                    DropdownMenuItem(value: 'TCS Express Courier', child: Text('TCS Express Courier')),
                    DropdownMenuItem(value: 'Leopard Courier', child: Text('Leopard Courier')),
                    DropdownMenuItem(value: 'M&P Express', child: Text('M&P Express')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedCourier = v);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _standardFeeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Standard Shipping Fee (PKR)', border: OutlineInputBorder()),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: _expressFeeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Same-Day Express Fee (PKR)', border: OutlineInputBorder()),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _freeShippingMinCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Free Shipping Threshold Minimum Order Amount (PKR)', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _selectedReturnPolicy,
                  decoration: const InputDecoration(labelText: 'Store Return Shipping Policy', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Free 7-Day Returns (Seller Paid)', child: Text('Free 7-Day Returns (Seller Paid)')),
                    DropdownMenuItem(value: 'Standard Return (Buyer Pays Shipping)', child: Text('Standard Return (Buyer Pays Shipping)')),
                    DropdownMenuItem(value: 'No Returns (Replacement Only)', child: Text('No Returns (Replacement Only)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedReturnPolicy = v);
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
