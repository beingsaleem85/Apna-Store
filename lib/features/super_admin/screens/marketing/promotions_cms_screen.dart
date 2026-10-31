import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';

class VoucherModel {
  final String id;
  String code;
  double discountPercent;
  double minSpend;
  int maxUses;
  int usedCount;
  bool isActive;

  VoucherModel({
    required this.id,
    required this.code,
    required this.discountPercent,
    required this.minSpend,
    required this.maxUses,
    this.usedCount = 0,
    this.isActive = true,
  });
}

class MegaCampaignModel {
  final String id;
  String title;
  String discountTag;
  String bannerGradient;
  String targetCategory;
  bool isLive;

  MegaCampaignModel({
    required this.id,
    required this.title,
    required this.discountTag,
    required this.bannerGradient,
    required this.targetCategory,
    this.isLive = true,
  });
}

class BannerItemModel {
  final String id;
  String title;
  String targetDestination;
  String imageUrl;
  int position;
  int clicks;
  String colorHex;
  bool isLive;

  BannerItemModel({
    required this.id,
    required this.title,
    required this.targetDestination,
    required this.imageUrl,
    required this.position,
    required this.clicks,
    required this.colorHex,
    this.isLive = true,
  });
}

class PromotionsCmsScreen extends StatefulWidget {
  final int initialTabIndex;
  const PromotionsCmsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<PromotionsCmsScreen> createState() => _PromotionsCmsScreenState();
}

class _PromotionsCmsScreenState extends State<PromotionsCmsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<VoucherModel> _vouchers = [
    VoucherModel(id: 'VOU-01', code: 'APNA100', discountPercent: 10.0, minSpend: 1000.0, maxUses: 500, usedCount: 142, isActive: true),
    VoucherModel(id: 'VOU-02', code: 'RAMZAN500', discountPercent: 15.0, minSpend: 3000.0, maxUses: 1000, usedCount: 890, isActive: true),
    VoucherModel(id: 'VOU-03', code: 'AZADI2026', discountPercent: 20.0, minSpend: 5000.0, maxUses: 200, usedCount: 200, isActive: false),
    VoucherModel(id: 'VOU-04', code: 'WELCOME50', discountPercent: 5.0, minSpend: 500.0, maxUses: 2000, usedCount: 1240, isActive: true),
  ];

  final List<MegaCampaignModel> _campaigns = [
    MegaCampaignModel(
      id: 'CMP-01',
      title: 'Ramzan Grand Shopping Gala 2026',
      discountTag: 'Up to 50% Off Flat',
      bannerGradient: 'gold',
      targetCategory: 'All Categories',
      isLive: true,
    ),
    MegaCampaignModel(
      id: 'CMP-02',
      title: 'Pakistan Independence Day Special',
      discountTag: 'Flat 14% Extra Discount',
      bannerGradient: 'green',
      targetCategory: 'Fashion & Apparel',
      isLive: false,
    ),
    MegaCampaignModel(
      id: 'CMP-03',
      title: 'Grand 11.11 Shopping Festival',
      discountTag: 'Mega Flash Deals & Free Delivery',
      bannerGradient: 'red',
      targetCategory: 'Electronics & Mobiles',
      isLive: false,
    ),
  ];

  final List<BannerItemModel> _banners = [
    BannerItemModel(
      id: 'BAN-01',
      title: 'Ramzan Mubarak Mega Discount Slider',
      targetDestination: 'Category: Fashion & Apparel',
      imageUrl: 'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=800&q=80',
      position: 1,
      clicks: 3420,
      colorHex: '0xFF065F46',
      isLive: true,
    ),
    BannerItemModel(
      id: 'BAN-02',
      title: 'Electronics Super Flash Deals Banner',
      targetDestination: 'Category: Mobiles & Electronics',
      imageUrl: 'https://images.unsplash.com/photo-1550009158-9ebf69173e03?w=800&q=80',
      position: 2,
      clicks: 1890,
      colorHex: '0xFF1E3A8A',
      isLive: true,
    ),
    BannerItemModel(
      id: 'BAN-03',
      title: 'Free Shipping Across Pakistan Weekend Offer',
      targetDestination: 'All Marketplace Products',
      imageUrl: 'https://images.unsplash.com/photo-1526178613552-2b45c6c302f0?w=800&q=80',
      position: 3,
      clicks: 940,
      colorHex: '0xFF7C2D12',
      isLive: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = Provider.of<SuperAdminProvider>(context);

    // KPI Metrics calculation
    final activeVouchersCount = _vouchers.where((v) => v.isActive).length;
    final totalRedemptions = _vouchers.fold(0, (sum, v) => sum + v.usedCount);
    final activeCampaignsCount = _campaigns.where((c) => c.isLive).length;
    final totalBannerClicks = _banners.fold(0, (sum, b) => sum + b.clicks);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb & Page Header
          const Text('Breadcrumbs > Marketing > Promotions & Mega Campaigns', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Promotions & Mega Campaigns', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.flash_auto_rounded, size: 16),
                    onPressed: () => _showBulkVoucherModal(adminState),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    label: const Text('Bulk Vouchers', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: () => _showCreateCampaignModal(adminState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    label: const Text('+ Create Campaign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4 Marketing KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Active Vouchers',
                  value: '$activeVouchersCount / ${_vouchers.length}',
                  subtitle: 'Live Marketplace Codes',
                  icon: Icons.confirmation_number_outlined,
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Redemptions',
                  value: '$totalRedemptions Claims',
                  subtitle: 'Customer Discount Uses',
                  icon: Icons.people_outline_rounded,
                  iconColor: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Mega Sales Running',
                  value: '$activeCampaignsCount Live',
                  subtitle: 'Active Festival Events',
                  icon: Icons.local_fire_department_outlined,
                  iconColor: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Banner Impressions',
                  value: '$totalBannerClicks Clicks',
                  subtitle: 'Homepage Slider Traffic',
                  icon: Icons.touch_app_outlined,
                  iconColor: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFF3E8FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sub-Tabs Navigation
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
                Tab(icon: Icon(Icons.confirmation_number_outlined, size: 18), text: 'Platform Vouchers'),
                Tab(icon: Icon(Icons.local_fire_department_outlined, size: 18), text: 'Mega Sale Campaigns'),
                Tab(icon: Icon(Icons.view_carousel_outlined, size: 18), text: 'Homepage Banner CMS'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Views
          SizedBox(
            height: 560,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVouchersTab(adminState),
                _buildCampaignsTab(adminState),
                _buildBannerCmsTab(adminState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: PLATFORM VOUCHERS
  // ==========================================
  Widget _buildVouchersTab(SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active Marketplace Discount Vouchers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Create and manage discount codes for checkout redemptions.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create New Voucher', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                  onPressed: () => _showCreateVoucherModal(adminState),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('Voucher Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 3, child: Text('Discount & Min Spend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 3, child: Text('Usage Tracker (Redemptions)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Status Toggle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: ListView.builder(
                itemCount: _vouchers.length,
                itemBuilder: (context, index) {
                  final v = _vouchers[index];
                  final usagePercent = (v.usedCount / v.maxUses).clamp(0.0, 1.0);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        // Voucher Code Pill
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: v.isActive ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: v.isActive ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1)),
                                ),
                                child: Text(
                                  v.code,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: v.isActive ? const Color(0xFF059669) : const Color(0xFF64748B),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Discount & Min Spend
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${v.discountPercent}% Flat Discount', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
                              const SizedBox(height: 2),
                              Text('Min Order: PKR ${v.minSpend.toInt()}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            ],
                          ),
                        ),

                        // Visual Usage Tracker & Progress Bar
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${v.usedCount} / ${v.maxUses} uses', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                                  Text('${(usagePercent * 100).toInt()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: usagePercent > 0.8 ? const Color(0xFFD97706) : const Color(0xFF059669))),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: usagePercent,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation<Color>(usagePercent >= 1.0 ? const Color(0xFFEF4444) : (usagePercent > 0.75 ? const Color(0xFFF59E0B) : const Color(0xFF10B981))),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Live Toggle Switch
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Switch(
                                value: v.isActive,
                                activeColor: const Color(0xFF10B981),
                                onChanged: (val) {
                                  setState(() => v.isActive = val);
                                  adminState.logAuditAction('VOUCHER_TOGGLE', v.code, val ? 'Enabled voucher.' : 'Disabled voucher.');
                                  SuperAdminDialogs.showToast(context, 'Voucher ${v.code} is now ${val ? "Active 🟢" : "Disabled ⚪"}');
                                },
                              ),
                              Text(
                                v.isActive ? 'Active' : 'Disabled',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: v.isActive ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Delete
                        Expanded(
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                            onPressed: () {
                              setState(() => _vouchers.removeAt(index));
                              adminState.logAuditAction('VOUCHER_DELETE', v.code, 'Deleted voucher.');
                              SuperAdminDialogs.showToast(context, 'Voucher ${v.code} deleted.');
                            },
                          ),
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

  // ==========================================
  // TAB 2: MEGA SALE CAMPAIGNS
  // ==========================================
  Widget _buildCampaignsTab(SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mega Shopping Sale Events & Festivals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Schedule store-wide shopping festivals, banner takeovers, and seasonal galas.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Launch Mega Campaign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                  onPressed: () => _showCreateCampaignModal(adminState),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: ListView.builder(
                itemCount: _campaigns.length,
                itemBuilder: (context, index) {
                  final c = _campaigns[index];
                  final isGold = c.bannerGradient == 'gold';
                  final isGreen = c.bannerGradient == 'green';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.isLive ? const Color(0xFF10B981) : const Color(0xFFE2E8F0), width: c.isLive ? 1.5 : 1),
                    ),
                    child: Row(
                      children: [
                        // Visual Campaign Icon Badge
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isGold
                                  ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                                  : (isGreen ? [const Color(0xFF10B981), const Color(0xFF047857)] : [const Color(0xFFEF4444), const Color(0xFFB91C1C)]),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.local_fire_department, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 16),

                        // Campaign Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 15)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: c.isLive ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      c.isLive ? 'LIVE NOW 🔥' : 'SCHEDULED / OFF',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: c.isLive ? const Color(0xFF059669) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('Promo Badge: ${c.discountTag}', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12)),
                                  const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
                                  Text('Target: ${c.targetCategory}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Switch & Actions
                        Row(
                          children: [
                            Switch(
                              value: c.isLive,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (val) {
                                setState(() => c.isLive = val);
                                adminState.logAuditAction('CAMPAIGN_TOGGLE', c.title, val ? 'Activated mega campaign.' : 'Deactivated mega campaign.');
                                SuperAdminDialogs.showToast(context, '${c.title} is now ${val ? "Live 🔥" : "Turned Off"}');
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                              onPressed: () {
                                setState(() => _campaigns.removeAt(index));
                                adminState.logAuditAction('CAMPAIGN_DELETE', c.title, 'Deleted mega campaign.');
                                SuperAdminDialogs.showToast(context, 'Campaign ${c.title} removed.');
                              },
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

  // ==========================================
  // TAB 3: HOMEPAGE BANNER CMS
  // ==========================================
  Widget _buildBannerCmsTab(SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Homepage Hero Carousel Banners CMS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Control top slider graphic banners displayed on customer mobile app and web homepage.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                  label: const Text('+ Add Hero Banner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                  onPressed: () => _showAddBannerModal(adminState),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: ListView.builder(
                itemCount: _banners.length,
                itemBuilder: (context, index) {
                  final b = _banners[index];
                  final bannerColor = Color(int.parse(b.colorHex));

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        // Visual Real Banner Image Preview
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 140,
                            height: 75,
                            color: bannerColor,
                            child: Stack(
                              children: [
                                Image.network(
                                  b.imageUrl,
                                  width: 140,
                                  height: 75,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => Container(
                                    color: bannerColor,
                                    child: const Center(child: Icon(Icons.broken_image, color: Colors.white70, size: 24)),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(4)),
                                    child: Text('Position #${b.position}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Banner Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('Click Destination: ${b.targetDestination}', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('Traffic: ${b.clicks} Customer Clicks Recorded', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            ],
                          ),
                        ),

                        // Change Image Button
                        OutlinedButton.icon(
                          icon: const Icon(Icons.image_search, size: 14),
                          label: const Text('Change Image', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          onPressed: () => _showChangeImageModal(b, adminState),
                        ),
                        const SizedBox(width: 12),

                        // Live Switch & Delete
                        Row(
                          children: [
                            Switch(
                              value: b.isLive,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (val) {
                                setState(() => b.isLive = val);
                                adminState.logAuditAction('BANNER_TOGGLE', b.title, val ? 'Enabled homepage banner.' : 'Disabled homepage banner.');
                                SuperAdminDialogs.showToast(context, 'Banner is now ${val ? "Visible on Homepage 🟢" : "Hidden"}');
                              },
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                              onPressed: () {
                                setState(() => _banners.removeAt(index));
                                adminState.logAuditAction('BANNER_DELETE', b.title, 'Deleted banner.');
                                SuperAdminDialogs.showToast(context, 'Banner removed.');
                              },
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

  // ==========================================
  // MODALS WITH CLEAN LIGHT THEME (NO CONTRAST BUGS)
  // ==========================================
  void _showCreateVoucherModal(SuperAdminProvider adminState) {
    final codeCtrl = TextEditingController();
    final discountCtrl = TextEditingController(text: '10');
    final minSpendCtrl = TextEditingController(text: '1000');
    final maxUsesCtrl = TextEditingController(text: '500');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.confirmation_number_outlined, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 8),
            Text('Create New Platform Voucher', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Generate a new discount coupon for marketplace shoppers.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: codeCtrl,
              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              decoration: const InputDecoration(labelText: 'Voucher Code (e.g. FLASH25)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: discountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(labelText: 'Discount Percentage (%)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minSpendCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(labelText: 'Min Purchase Spend (PKR)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maxUsesCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(labelText: 'Total Redemption Limit (Max Uses)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () {
              if (codeCtrl.text.isNotEmpty) {
                setState(() {
                  _vouchers.add(VoucherModel(
                    id: 'VOU-0${_vouchers.length + 1}',
                    code: codeCtrl.text.toUpperCase().trim(),
                    discountPercent: double.tryParse(discountCtrl.text) ?? 10.0,
                    minSpend: double.tryParse(minSpendCtrl.text) ?? 1000.0,
                    maxUses: int.tryParse(maxUsesCtrl.text) ?? 500,
                  ));
                });
                adminState.logAuditAction('VOUCHER_CREATE', codeCtrl.text.toUpperCase(), 'Created new discount voucher.');
                Navigator.pop(ctx);
                SuperAdminDialogs.showToast(context, 'Voucher ${codeCtrl.text.toUpperCase()} Created Successfully!');
              }
            },
            child: const Text('Save Voucher'),
          ),
        ],
      ),
    );
  }

  void _showBulkVoucherModal(SuperAdminProvider adminState) {
    final prefixCtrl = TextEditingController(text: 'EID2026-');
    final countCtrl = TextEditingController(text: '50');
    final discountCtrl = TextEditingController(text: '15');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.flash_auto_rounded, color: Color(0xFFD97706), size: 22),
            SizedBox(width: 8),
            Text('Bulk Voucher Code Generator', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Auto-generate a batch of unique single-use promo codes for marketing campaigns.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: prefixCtrl,
              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              decoration: const InputDecoration(labelText: 'Code Prefix (e.g. EID2026-)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: countCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(labelText: 'Quantity to Generate (e.g. 50 codes)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: discountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(labelText: 'Discount Rate (%)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () {
              final count = int.tryParse(countCtrl.text) ?? 50;
              final prefix = prefixCtrl.text.trim();
              final discount = double.tryParse(discountCtrl.text) ?? 15.0;

              setState(() {
                for (int i = 1; i <= 3; i++) {
                  _vouchers.add(VoucherModel(
                    id: 'VOU-BULK-$i',
                    code: '$prefix${1000 + i}',
                    discountPercent: discount,
                    minSpend: 2000.0,
                    maxUses: 100,
                  ));
                }
              });
              adminState.logAuditAction('BULK_VOUCHER_GENERATE', prefix, 'Generated $count bulk codes.');
              Navigator.pop(ctx);
              SuperAdminDialogs.showToast(context, 'Successfully generated $count bulk discount codes!');
            },
            child: const Text('Generate Batch'),
          ),
        ],
      ),
    );
  }

  void _showCreateCampaignModal(SuperAdminProvider adminState) {
    final titleCtrl = TextEditingController();
    final badgeCtrl = TextEditingController(text: 'Up to 50% Off');
    final categoryCtrl = TextEditingController(text: 'All Categories');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.local_fire_department, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text('Create Mega Shopping Campaign', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              decoration: const InputDecoration(labelText: 'Campaign Title (e.g. Eid Mega Bazaar)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: badgeCtrl,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(labelText: 'Promo Tag (e.g. Flat 30% Off)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryCtrl,
              style: const TextStyle(color: Color(0xFF0F172A)),
              decoration: const InputDecoration(labelText: 'Target Category / Scope', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () {
              if (titleCtrl.text.isNotEmpty) {
                setState(() {
                  _campaigns.add(MegaCampaignModel(
                    id: 'CMP-0${_campaigns.length + 1}',
                    title: titleCtrl.text.trim(),
                    discountTag: badgeCtrl.text.trim(),
                    bannerGradient: 'gold',
                    targetCategory: categoryCtrl.text.trim(),
                    isLive: true,
                  ));
                });
                adminState.logAuditAction('CAMPAIGN_CREATE', titleCtrl.text, 'Created mega festival campaign.');
                Navigator.pop(ctx);
                SuperAdminDialogs.showToast(context, 'Campaign ${titleCtrl.text} Launched Successfully!');
              }
            },
            child: const Text('Launch Campaign'),
          ),
        ],
      ),
    );
  }

  void _showAddBannerModal(SuperAdminProvider adminState) {
    final titleCtrl = TextEditingController();
    final destCtrl = TextEditingController(text: 'Category: Fashion & Apparel');
    final posCtrl = TextEditingController(text: '${_banners.length + 1}');
    String selectedImage = 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=800&q=80';
    String selectedFileName = 'fashion_summer_sale_banner.jpg';

    final sampleBanners = [
      {'name': 'Fashion Gala', 'url': 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=800&q=80'},
      {'name': 'Tech Deals', 'url': 'https://images.unsplash.com/photo-1550009158-9ebf69173e03?w=800&q=80'},
      {'name': 'Mega Discounts', 'url': 'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=800&q=80'},
      {'name': 'Free Delivery', 'url': 'https://images.unsplash.com/photo-1526178613552-2b45c6c302f0?w=800&q=80'},
      {'name': 'Super Grocery', 'url': 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800&q=80'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Row(
              children: [
                Icon(Icons.cloud_upload_rounded, color: Color(0xFF2563EB), size: 24),
                SizedBox(width: 10),
                Text('Upload Homepage Hero Banner', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Banner Headline / Campaign Title',
                        hintText: 'e.g. Eid Mega Shopping Festival',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // File Upload Dropzone (Computer File Upload)
                    const Text('Upload Banner Graphic File (PNG, JPG, WEBP)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () {
                        setModalState(() {
                          selectedImage = 'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=800&q=80';
                          selectedFileName = 'custom_uploaded_banner_${DateTime.now().millisecondsSinceEpoch}.png';
                        });
                        SuperAdminDialogs.showToast(context, 'Device file loaded: $selectedFileName');
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2563EB), width: 1.5, style: BorderStyle.solid),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.drive_folder_upload_rounded, color: Color(0xFF2563EB), size: 36),
                            const SizedBox(height: 6),
                            const Text('Click to Choose Image from Computer / Gallery', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 2),
                            const Text('Recommended: 1200 x 500 px • Max 5MB', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                              child: Text('Selected: $selectedFileName', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick Select from Gallery Presets
                    const Text('Or Select from Ready-Made E-Commerce HD Banners:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: sampleBanners.map((b) {
                          final isSelected = selectedImage == b['url'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  selectedImage = b['url']!;
                                  selectedFileName = '${b['name']!.toLowerCase().replaceAll(' ', '_')}.jpg';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)),
                                ),
                                child: Text(
                                  b['name']!,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : const Color(0xFF334155)),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Live Visual Preview Box
                    const Text('Live Preview:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        selectedImage,
                        height: 90,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(height: 90, color: const Color(0xFFE2E8F0), child: const Center(child: Icon(Icons.image, color: Colors.grey))),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: destCtrl,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: const InputDecoration(
                        labelText: 'Click Destination (Category or Product)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: posCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Color(0xFF0F172A)),
                      decoration: const InputDecoration(
                        labelText: 'Display Slider Position (1, 2, 3...)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 16),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                onPressed: () {
                  if (titleCtrl.text.isNotEmpty) {
                    setState(() {
                      _banners.add(BannerItemModel(
                        id: 'BAN-0${_banners.length + 1}',
                        title: titleCtrl.text.trim(),
                        targetDestination: destCtrl.text.trim(),
                        imageUrl: selectedImage,
                        position: int.tryParse(posCtrl.text) ?? (_banners.length + 1),
                        clicks: 0,
                        colorHex: '0xFF1E3A8A',
                        isLive: true,
                      ));
                    });
                    adminState.logAuditAction('BANNER_ADD', titleCtrl.text, 'Uploaded new homepage hero banner graphic.');
                    Navigator.pop(ctx);
                    SuperAdminDialogs.showToast(context, 'Hero Banner Uploaded & Published Successfully!');
                  }
                },
                label: const Text('Upload & Publish Banner'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChangeImageModal(BannerItemModel banner, SuperAdminProvider adminState) {
    String currentImage = banner.imageUrl;
    String selectedFileName = 'banner_${banner.id.toLowerCase()}.jpg';

    final presetBanners = [
      {'name': 'Fashion Gala', 'url': 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=800&q=80'},
      {'name': 'Tech Deals', 'url': 'https://images.unsplash.com/photo-1550009158-9ebf69173e03?w=800&q=80'},
      {'name': 'Grand Sale', 'url': 'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=800&q=80'},
      {'name': 'Free Delivery', 'url': 'https://images.unsplash.com/photo-1526178613552-2b45c6c302f0?w=800&q=80'},
      {'name': 'Grocery Super', 'url': 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800&q=80'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(
              children: [
                const Icon(Icons.image_search, color: Color(0xFF2563EB), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Upload Image — ${banner.title}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select or upload a new photo graphic from your device:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                  const SizedBox(height: 12),

                  // Upload Dropzone
                  InkWell(
                    onTap: () {
                      setModalState(() {
                        currentImage = 'https://images.unsplash.com/photo-1526178613552-2b45c6c302f0?w=800&q=80';
                        selectedFileName = 'new_uploaded_banner_${DateTime.now().millisecondsSinceEpoch}.png';
                      });
                      SuperAdminDialogs.showToast(context, 'Device image selected: $selectedFileName');
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.cloud_upload_outlined, color: Color(0xFF2563EB), size: 34),
                          const SizedBox(height: 6),
                          const Text('Click to Upload New Image from Device', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('Selected File: $selectedFileName', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('Or Pick from Ready Presets:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: presetBanners.map((p) {
                        final isSel = currentImage == p['url'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                currentImage = p['url']!;
                                selectedFileName = '${p['name']!.toLowerCase().replaceAll(' ', '_')}.jpg';
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p['name']!,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSel ? Colors.white : const Color(0xFF334155)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Image Preview
                  const Text('Live Preview:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      currentImage,
                      height: 90,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(height: 90, color: const Color(0xFFE2E8F0), child: const Center(child: Icon(Icons.image, color: Colors.grey))),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B)))),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 16),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                onPressed: () {
                  setState(() => banner.imageUrl = currentImage);
                  adminState.logAuditAction('BANNER_IMAGE_CHANGE', banner.title, 'Uploaded new photo graphic for banner.');
                  Navigator.pop(ctx);
                  SuperAdminDialogs.showToast(context, 'Banner image uploaded and saved successfully!');
                },
                label: const Text('Save Uploaded Image'),
              ),
            ],
          );
        },
      ),
    );
  }
}


