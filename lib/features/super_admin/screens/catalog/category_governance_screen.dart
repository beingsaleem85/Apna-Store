import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/app_state_provider.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';

class CategoryItem {
  final String id;
  String name;
  String parentCategory;
  double commissionRate;
  int productCount;
  bool isActive;

  CategoryItem({
    required this.id,
    required this.name,
    required this.parentCategory,
    required this.commissionRate,
    required this.productCount,
    this.isActive = true,
  });
}

class BrandItem {
  final String id;
  String name;
  String category;
  bool isVerified;
  String logoUrl;
  int storeCount;

  BrandItem({
    required this.id,
    required this.name,
    required this.category,
    this.isVerified = false,
    required this.logoUrl,
    required this.storeCount,
  });
}

class CategoryGovernanceScreen extends StatefulWidget {
  final int initialTabIndex;
  const CategoryGovernanceScreen({super.key, this.initialTabIndex = 0});

  @override
  State<CategoryGovernanceScreen> createState() => _CategoryGovernanceScreenState();
}

class _CategoryGovernanceScreenState extends State<CategoryGovernanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<CategoryItem> _categories = [
    CategoryItem(id: 'CAT-01', name: 'Fashion & Apparel', parentCategory: 'Root', commissionRate: 12.0, productCount: 450),
    CategoryItem(id: 'CAT-02', name: 'Men\'s Clothing', parentCategory: 'Fashion & Apparel', commissionRate: 12.0, productCount: 210),
    CategoryItem(id: 'CAT-03', name: 'Women\'s Wear', parentCategory: 'Fashion & Apparel', commissionRate: 12.0, productCount: 240),
    CategoryItem(id: 'CAT-04', name: 'Mobiles & Electronics', parentCategory: 'Root', commissionRate: 5.0, productCount: 320),
    CategoryItem(id: 'CAT-05', name: 'Smartphones', parentCategory: 'Mobiles & Electronics', commissionRate: 5.0, productCount: 180),
    CategoryItem(id: 'CAT-06', name: 'Groceries & Household', parentCategory: 'Root', commissionRate: 3.5, productCount: 600),
  ];

  final List<BrandItem> _brands = [
    BrandItem(id: 'BRD-01', name: 'Junaid Jamshed (J.)', category: 'Fashion & Apparel', isVerified: true, logoUrl: '', storeCount: 15),
    BrandItem(id: 'BRD-02', name: 'Khaadi Official', category: 'Fashion & Apparel', isVerified: true, logoUrl: '', storeCount: 22),
    BrandItem(id: 'BRD-03', name: 'Samsung Pakistan', category: 'Mobiles & Electronics', isVerified: true, logoUrl: '', storeCount: 8),
    BrandItem(id: 'BRD-04', name: 'Local Artisan Crafts', category: 'Handicrafts', isVerified: false, logoUrl: '', storeCount: 3),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = Provider.of<SuperAdminProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Executive Breadcrumb & Page Header
          const Text('Breadcrumbs > Catalog > Category & Brand Governance', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Category Tree & Brand Governance', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _showAddCategoryModal(adminState),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.verified, size: 16),
                    label: const Text('Add Official Brand', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _showAddBrandModal(adminState),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tabs Navigation
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF334155),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.account_tree_outlined, size: 18), text: 'Category Tree & Rates'),
                Tab(icon: Icon(Icons.verified_outlined, size: 18), text: 'Brand Verification Desk'),
                Tab(icon: Icon(Icons.straighten_outlined, size: 18), text: 'Attributes & Size Charts'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 600,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryTreeTab(adminState),
                _buildBrandVerificationTab(adminState),
                _buildAttributesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTreeTab(SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Marketplace Category Tree & Rates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                  onPressed: () => _showAddCategoryModal(adminState),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isRoot = cat.parentCategory == 'Root';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.only(left: isRoot ? 16 : 44, right: 16, top: 14, bottom: 14),
                    decoration: BoxDecoration(
                      color: isRoot ? const Color(0xFFF8FAFC) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isRoot ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isRoot ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isRoot ? Icons.folder_rounded : Icons.subdirectory_arrow_right_rounded,
                            size: 20,
                            color: isRoot ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    cat.name,
                                    style: TextStyle(
                                      fontWeight: isRoot ? FontWeight.bold : FontWeight.w600,
                                      color: const Color(0xFF0F172A),
                                      fontSize: isRoot ? 14 : 13,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isRoot ? const Color(0xFFE0E7FF) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isRoot ? 'Main Category' : 'Sub-Category',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isRoot ? const Color(0xFF3730A3) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isRoot ? 'Root category level • Controls global catalog navigation' : 'Parent: ${cat.parentCategory}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.percent, size: 12, color: Color(0xFF059669)),
                              const SizedBox(width: 4),
                              Text(
                                'Commission: ${cat.commissionRate}%',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            '${cat.productCount} Products',
                            style: const TextStyle(color: Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Edit Commission Rate',
                          icon: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF0F172A)),
                          onPressed: () => _showEditCategoryModal(cat, adminState),
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

  Widget _buildBrandVerificationTab(SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Official Brand Registry & Verification Desk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    SizedBox(height: 4),
                    Text('Verify trademarked brand ownership and grant official verified merchant badges.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Register Brand', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                  onPressed: () => _showAddBrandModal(adminState),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: ListView.builder(
                itemCount: _brands.length,
                itemBuilder: (context, index) {
                  final brand = _brands[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF0F172A),
                          child: Text(brand.name.substring(0, 1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(brand.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14)),
                                  if (brand.isVerified) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFBFDBFE))),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.verified, size: 13, color: Color(0xFF2563EB)),
                                          SizedBox(width: 4),
                                          Text('Official Verified', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('${brand.category} • ${brand.storeCount} Authorized Merchant Stores Selling', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: Icon(brand.isVerified ? Icons.close : Icons.verified, size: 16),
                          label: Text(brand.isVerified ? 'Revoke Badge' : 'Grant Verified Badge', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brand.isVerified ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            setState(() => brand.isVerified = !brand.isVerified);
                            adminState.logAuditAction('BRAND_VERIFICATION', brand.name, brand.isVerified ? 'Granted Official Verified Brand Badge.' : 'Revoked Official Brand Badge.');
                            SuperAdminDialogs.showToast(context, '${brand.name} badge updated.');
                          },
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

  Widget _buildAttributesTab() {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Standard Product Attributes & Size Charts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      SizedBox(height: 4),
                      Text('Configure global size guides, color swatches, and technical specifications for sellers.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Attribute Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                    onPressed: () {
                      SuperAdminDialogs.showToast(context, 'Attribute Group builder opened.');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 1. Apparel Sizes Section
              _buildAttributeCard(
                icon: Icons.straighten,
                iconColor: const Color(0xFFEAB308),
                title: 'Fashion Apparel Size Charts',
                subtitle: 'Standardized clothing and footwear size scales enforced across fashion vendors.',
                tags: ['XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL', 'UK 6 - 12', 'US 7 - 13', 'EUR 38 - 46'],
              ),
              const SizedBox(height: 12),

              // 2. Color Palette Section
              _buildAttributeCard(
                icon: Icons.color_lens,
                iconColor: const Color(0xFF0D9488),
                title: 'Standard Color Palette & Swatches',
                subtitle: 'Pre-defined 50+ color codes with localized color names (Urdu & English).',
                tags: ['Jet Black', 'Pure White', 'Navy Blue', 'Maroon', 'Emerald Green', 'Royal Gold', 'Heather Grey', 'Pastel Pink'],
              ),
              const SizedBox(height: 12),

              // 3. Tech Specifications Section
              _buildAttributeCard(
                icon: Icons.memory,
                iconColor: const Color(0xFF2563EB),
                title: 'Electronics & Mobiles Technical Specs',
                subtitle: 'Mandatory technical attribute fields required for gadgets and smartphone listings.',
                tags: ['RAM (4GB / 8GB / 12GB / 16GB)', 'Storage (64GB / 128GB / 256GB / 512GB / 1TB)', 'PTA Status (Approved / Non-PTA)', 'Screen Size', 'Battery (mAh)'],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttributeCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<String> tags,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Manage Values', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: () {
                  SuperAdminDialogs.showToast(context, 'Attribute editor for "$title" ready.');
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: tags.map((t) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryModal(SuperAdminProvider adminState) {
    final nameController = TextEditingController();
    final rateController = TextEditingController(text: '10.0');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Add New Category', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(
                labelText: 'Category Name',
                labelStyle: TextStyle(color: Color(0xFF64748B)),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rateController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(
                labelText: 'Commission Rate (%)',
                labelStyle: TextStyle(color: Color(0xFF64748B)),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                setState(() {
                  _categories.add(CategoryItem(
                    id: 'CAT-0${_categories.length + 1}',
                    name: nameController.text,
                    parentCategory: 'Root',
                    commissionRate: double.tryParse(rateController.text) ?? 10.0,
                    productCount: 0,
                  ));
                });
                Provider.of<AppStateProvider>(context, listen: false).addCategory(
                  nameController.text,
                  'https://images.unsplash.com/photo-1498049794561-7780e7231661?w=200&q=80',
                );
                adminState.logAuditAction('CATEGORY_CREATE', nameController.text, 'Created new category with ${rateController.text}% commission rate.');
                Navigator.pop(ctx);
                SuperAdminDialogs.showToast(context, 'Category "${nameController.text}" added & saved to Supabase!');
              }
            },
            child: const Text('Add Category'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryModal(CategoryItem cat, SuperAdminProvider adminState) {
    final rateController = TextEditingController(text: cat.commissionRate.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Edit Commission — ${cat.name}', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        content: TextField(
          controller: rateController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Color(0xFF0F172A)),
          decoration: const InputDecoration(
            labelText: 'Commission Rate (%)',
            labelStyle: TextStyle(color: Color(0xFF64748B)),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final newRate = double.tryParse(rateController.text);
              if (newRate != null) {
                setState(() => cat.commissionRate = newRate);
                adminState.logAuditAction('CATEGORY_COMMISSION_UPDATE', cat.name, 'Updated category commission rate to $newRate%.');
                Navigator.pop(ctx);
                SuperAdminDialogs.showToast(context, 'Category Commission Updated!');
              }
            },
            child: const Text('Save Rate'),
          ),
        ],
      ),
    );
  }

  void _showAddBrandModal(SuperAdminProvider adminState) {
    final brandController = TextEditingController();
    final categoryController = TextEditingController(text: 'Fashion & Apparel');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Add Official Brand Badge', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: brandController,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(
                labelText: 'Brand Name',
                labelStyle: TextStyle(color: Color(0xFF64748B)),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryController,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(
                labelText: 'Primary Category',
                labelStyle: TextStyle(color: Color(0xFF64748B)),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (brandController.text.isNotEmpty) {
                setState(() {
                  _brands.add(BrandItem(
                    id: 'BRD-0${_brands.length + 1}',
                    name: brandController.text,
                    category: categoryController.text,
                    isVerified: true,
                    logoUrl: '',
                    storeCount: 1,
                  ));
                });
                adminState.logAuditAction('BRAND_CREATE', brandController.text, 'Registered official verified brand badge.');
                Navigator.pop(ctx);
                SuperAdminDialogs.showToast(context, 'Brand "${brandController.text}" registered!');
              }
            },
            child: const Text('Add Brand'),
          ),
        ],
      ),
    );
  }
}
