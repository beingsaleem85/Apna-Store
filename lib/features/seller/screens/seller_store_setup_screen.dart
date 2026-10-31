import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_breakpoints.dart';
import '../../../core/services/app_state_provider.dart';
import '../../../core/services/supabase_seller_service.dart';
import '../../../core/constants/theme.dart';

class SellerStoreSetupScreen extends StatefulWidget {
  const SellerStoreSetupScreen({super.key});

  @override
  State<SellerStoreSetupScreen> createState() => _SellerStoreSetupScreenState();
}

class _SellerStoreSetupScreenState extends State<SellerStoreSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _storeNameController;
  late TextEditingController _storeDescController;
  late TextEditingController _storeLogoController;
  late TextEditingController _storeBannerController;
  late TextEditingController _contactNumberController;
  late TextEditingController _businessEmailController;
  late TextEditingController _pickupAddressController;
  late TextEditingController _warehouseAddressController;
  late TextEditingController _openingHoursController;
  late TextEditingController _facebookController;
  late TextEditingController _instagramController;
  late TextEditingController _whatsappController;
  late TextEditingController _tiktokController;
  late TextEditingController _youtubeController;

  String _businessCategory = 'Fashion';
  String _businessType = 'Sole Proprietorship';
  Color _selectedThemeColor = AppTheme.primaryGreen;

  final List<Color> _themeColorOptions = [
    const Color(0xFF004D40), // Deep Teal (Default)
    const Color(0xFF1E3A8A), // Royal Blue
    const Color(0xFF854D0E), // Amber Gold
    const Color(0xFF065F46), // Forest Emerald
    const Color(0xFF701A75), // Deep Purple
    const Color(0xFF111827), // Midnight Dark
  ];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final state = Provider.of<AppStateProvider>(context, listen: false);
    final store = state.activeSellerStore;

    _storeNameController = TextEditingController(text: store?.shopName ?? '');
    _storeDescController = TextEditingController(text: store?.shopDescription ?? '');
    _storeLogoController = TextEditingController(text: store?.shopLogo ?? 'https://images.unsplash.com/photo-1547082299-de196ea013d6');
    _storeBannerController = TextEditingController(text: store?.shopBanner ?? 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e');
    _contactNumberController = TextEditingController(text: store?.mobileNumber ?? '');
    _businessEmailController = TextEditingController(text: store?.email ?? '');
    _pickupAddressController = TextEditingController(text: store?.businessAddress ?? '');
    _warehouseAddressController = TextEditingController(text: store?.businessAddress ?? 'Warehouse Hub 1, Industrial Area');
    _openingHoursController = TextEditingController(text: 'Mon-Sat: 09:00 AM - 09:00 PM');
    _facebookController = TextEditingController(text: 'https://facebook.com/${store?.storeSlug ?? "apnastore"}');
    _instagramController = TextEditingController(text: 'https://instagram.com/${store?.storeSlug ?? "apnastore"}');
    _whatsappController = TextEditingController(text: store?.mobileNumber ?? '');
    _tiktokController = TextEditingController();
    _youtubeController = TextEditingController();
    _businessCategory = store?.storeCategory ?? 'Fashion';
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeDescController.dispose();
    _storeLogoController.dispose();
    _storeBannerController.dispose();
    _contactNumberController.dispose();
    _businessEmailController.dispose();
    _pickupAddressController.dispose();
    _warehouseAddressController.dispose();
    _openingHoursController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _whatsappController.dispose();
    _tiktokController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateProvider>(context);
    final supabaseSeller = Provider.of<SupabaseSellerService>(context);
    final isWeb = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Store Setup & Customization'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.remove_red_eye_outlined),
            tooltip: 'Preview Live Store Front',
            onPressed: _showStorePreviewModal,
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryGold,
                foregroundColor: Colors.black,
                elevation: 2,
              ),
              onPressed: _isSaving ? null : () => _saveStoreSettings(state, supabaseSeller),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner Header Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.storefront, size: 36, color: AppTheme.primaryGreen),
                          ),
                          const SizedBox(width: 20),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Store Identity & Customization', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
                                SizedBox(height: 4),
                                Text('Manage store branding, contact info, operating hours, social links, and theme color.', style: TextStyle(fontSize: 13, color: AppTheme.lightText)),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.remove_red_eye, size: 16),
                            label: const Text('Live Store Preview'),
                            onPressed: _showStorePreviewModal,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 1. Basic Store & Branding Info
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('1. Store Branding & Identity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField('Store Name', _storeNameController, Icons.storefront, (val) => val == null || val.isEmpty ? 'Required' : null),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _businessCategory,
                                  decoration: InputDecoration(
                                    labelText: 'Business Category',
                                    prefixIcon: const Icon(Icons.category_outlined, color: AppTheme.lightText),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: ['Fashion', 'Electronics', 'Groceries', 'Home & Living', 'Beauty', 'Mobiles', 'Laptops', 'Sports', 'Automotive', 'Books']
                                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                      .toList(),
                                  onChanged: (val) => setState(() => _businessCategory = val!),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _businessType,
                                  decoration: InputDecoration(
                                    labelText: 'Business Type',
                                    prefixIcon: const Icon(Icons.business_center_outlined, color: AppTheme.lightText),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  items: ['Sole Proprietorship', 'Private Limited Company', 'Partnership', 'Individual']
                                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                      .toList(),
                                  onChanged: (val) => setState(() => _businessType = val!),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField('Opening Hours', _openingHoursController, Icons.access_time_outlined, (val) => null),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildTextField('Store Description', _storeDescController, Icons.description_outlined, (val) => null, maxLines: 3),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField('Store Logo URL', _storeLogoController, Icons.image_outlined, (val) => null),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField('Store Banner URL', _storeBannerController, Icons.panorama_outlined, (val) => null),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Contact & Address Details
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('2. Locations & Contact Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField('Store Contact Number', _contactNumberController, Icons.phone_outlined, (val) => val == null || val.isEmpty ? 'Required' : null),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField('Business Email', _businessEmailController, Icons.email_outlined, (val) => val == null || val.isEmpty ? 'Required' : null),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildTextField('Order Pickup Address', _pickupAddressController, Icons.pin_drop_outlined, (val) => val == null || val.isEmpty ? 'Required' : null),
                          const SizedBox(height: 16),
                          _buildTextField('Warehouse Storage Address', _warehouseAddressController, Icons.warehouse_outlined, (val) => null),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Social Links & Store Theme Customization
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('3. Social Media Links & Store Theme', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(child: _buildTextField('Facebook Page', _facebookController, Icons.link, (val) => null)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField('Instagram Handle', _instagramController, Icons.camera_alt_outlined, (val) => null)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildTextField('WhatsApp Business Number', _whatsappController, Icons.chat_outlined, (val) => null)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildTextField('TikTok Account', _tiktokController, Icons.music_note_outlined, (val) => null)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text('Select Store Theme Primary Color:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkText)),
                          const SizedBox(height: 12),
                          Row(
                            children: _themeColorOptions.map((c) {
                              final isSelected = _selectedThemeColor == c;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedThemeColor = c),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 16),
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: isSelected ? Border.all(color: AppTheme.secondaryGold, width: 4) : null,
                                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                  ),
                                  child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bottom Save Action
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save, size: 20),
                      label: const Text('Save & Publish Store Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSaving ? null : () => _saveStoreSettings(state, supabaseSeller),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, String? Function(String?) validator, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.lightText),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: validator,
    );
  }

  void _saveStoreSettings(AppStateProvider state, SupabaseSellerService supabaseSeller) async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final store = state.activeSellerStore;
      if (store != null) {
        store.shopName = _storeNameController.text;
        store.shopDescription = _storeDescController.text;
        store.shopLogo = _storeLogoController.text;
        store.shopBanner = _storeBannerController.text;
        store.mobileNumber = _contactNumberController.text;
        store.email = _businessEmailController.text;
        store.businessAddress = _pickupAddressController.text;
        store.storeCategory = _businessCategory;

        state.saveStoresToLocalStorage();
      }

      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Store settings and customization saved successfully!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  void _showStorePreviewModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: AppBreakpoints.getResponsiveDialogWidth(context, defaultDesktopWidth: 850),
          constraints: const BoxConstraints(maxHeight: 650),
          child: Column(
            children: [
              // Modal Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: _selectedThemeColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.remove_red_eye, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Storefront Preview: ${_storeNameController.text}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Preview Content Area
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Banner
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(_storeBannerController.text.isNotEmpty
                                ? _storeBannerController.text
                                : 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      // Store Logo & Info Bar
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundImage: NetworkImage(_storeLogoController.text.isNotEmpty
                                  ? _storeLogoController.text
                                  : 'https://images.unsplash.com/photo-1547082299-de196ea013d6'),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_storeNameController.text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('${_businessCategory} | ${_openingHoursController.text}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(_storeDescController.text, style: const TextStyle(fontSize: 13, color: AppTheme.darkText)),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.chat, size: 16),
                              label: const Text('Contact Seller'),
                              style: ElevatedButton.styleFrom(backgroundColor: _selectedThemeColor, foregroundColor: Colors.white),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      ),
                      const Divider(),

                      // Sample Products Grid Preview
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Featured Store Products', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 3,
                              childAspectRatio: 0.8,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              children: [
                                _buildPreviewProductCard('Premium Leather Handbag', 'PKR 4,999', 'https://images.unsplash.com/photo-1548036328-c9fa89d128fa'),
                                _buildPreviewProductCard('Casual Cotton Polo Shirt', 'PKR 1,850', 'https://images.unsplash.com/photo-1521572267360-ee0c2909d518'),
                                _buildPreviewProductCard('Wireless Bluetooth Earbuds', 'PKR 3,200', 'https://images.unsplash.com/photo-1590658268037-6bf12165a8df'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewProductCard(String title, String price, String img) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                image: DecorationImage(image: NetworkImage(img), fit: BoxFit.cover),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(price, style: TextStyle(fontWeight: FontWeight.bold, color: _selectedThemeColor, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
