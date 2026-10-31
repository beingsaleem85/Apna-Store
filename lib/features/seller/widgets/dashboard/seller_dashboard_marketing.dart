import 'package:flutter/material.dart';
import '../../../../core/services/app_state_provider.dart';

// 1. Executive Ads Manager & Sponsored CPC Campaigns Desk
class SellerAdsManagerSection extends StatefulWidget {
  final AppStateProvider state;

  const SellerAdsManagerSection({
    super.key,
    required this.state,
  });

  @override
  State<SellerAdsManagerSection> createState() => _SellerAdsManagerSectionState();
}

class _SellerAdsManagerSectionState extends State<SellerAdsManagerSection> {
  final List<Map<String, String>> _campaigns = [
    {
      'name': 'Cotton Kurta Search Boost',
      'keyword': 'cotton kurta',
      'cpc': 'PKR 12',
      'budget': 'PKR 1,000 / day',
      'impressions': '45.2k',
      'clicks': '2.1k',
      'roas': '6.2x ROAS',
      'status': 'Active',
    },
    {
      'name': 'Earbuds Flash Sponsored',
      'keyword': 'bluetooth earbuds',
      'cpc': 'PKR 18',
      'budget': 'PKR 1,500 / day',
      'impressions': '68.9k',
      'clicks': '3.4k',
      'roas': '4.8x ROAS',
      'status': 'Active',
    },
    {
      'name': 'Unstitched Suits Promo',
      'keyword': 'lawn suit',
      'cpc': 'PKR 10',
      'budget': 'PKR 800 / day',
      'impressions': '28.4k',
      'clicks': '1.2k',
      'roas': '5.1x ROAS',
      'status': 'Active',
    },
  ];

  void _showCreateCampaignModal() {
    final nameCtrl = TextEditingController(text: 'Summer Collection Boost');
    final kwCtrl = TextEditingController(text: 'summer kurta');
    final cpcCtrl = TextEditingController(text: '15');
    final budgetCtrl = TextEditingController(text: '1200');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Create New Sponsored CPC Campaign', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Campaign Name', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: kwCtrl, decoration: const InputDecoration(labelText: 'Target Search Keyword', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: cpcCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max Cost-Per-Click Bid (PKR)', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: budgetCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Daily Budget Limit (PKR)', isDense: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _campaigns.add({
                  'name': nameCtrl.text,
                  'keyword': kwCtrl.text,
                  'cpc': 'PKR ${cpcCtrl.text}',
                  'budget': 'PKR ${budgetCtrl.text} / day',
                  'impressions': '0',
                  'clicks': '0',
                  'roas': '0.0x ROAS',
                  'status': 'Active',
                });
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sponsored Ad Campaign created & launched!'), backgroundColor: Color(0xFF059669)),
              );
            },
            child: const Text('Launch Campaign'),
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
                  Text('Sponsored Product Ads & CPC Campaign Manager', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Promote your catalog listings, manage CPC bids, target search keywords, and maximize ROAS revenue.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showCreateCampaignModal,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create Sponsored Campaign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                  _buildKpiBox('Active Campaigns', '${_campaigns.length} Active Ads', Icons.campaign_outlined, const Color(0xFF0284C7)),
                  _buildKpiBox('Total Impressions', '142,500 Views', Icons.visibility_outlined, const Color(0xFF7C3AED)),
                  _buildKpiBox('Click-Through Rate', '4.8% Avg CTR', Icons.mouse_outlined, const Color(0xFF059669)),
                  _buildKpiBox('Return On Ad Spend', '5.4x ROAS', Icons.trending_up, const Color(0xFFB45309)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Campaigns Table Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Active Sponsored Product Campaigns', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 14),

                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Expanded(flex: 3, child: Text('CAMPAIGN NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('TARGET KEYWORD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('CPC BID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('DAILY BUDGET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('IMPRESSIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('ROAS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Campaign Rows
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _campaigns.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final c = _campaigns[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          // Campaign Name
                          Expanded(flex: 3, child: Text(c['name']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),

                          // Target Keyword
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                              child: Text(c['keyword']!, style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),

                          // CPC Bid
                          Expanded(flex: 2, child: Text(c['cpc']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)))),

                          // Daily Budget
                          Expanded(flex: 2, child: Text(c['budget']!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),

                          // Impressions
                          Expanded(flex: 2, child: Text(c['impressions']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),

                          // ROAS
                          Expanded(flex: 2, child: Text(c['roas']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)))),

                          // Status
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                              child: Text(c['status']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                            ),
                          ),

                          // Actions
                          Expanded(
                            flex: 2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Campaign ${c['name']} paused!'), backgroundColor: const Color(0xFF475569)),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  child: const Text('Pause', style: TextStyle(fontSize: 10, color: Color(0xFF334155))),
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

// 2. Executive Store Vouchers & Mega Discount Coupons Desk
class SellerVouchersCouponsSection extends StatefulWidget {
  final AppStateProvider state;

  const SellerVouchersCouponsSection({
    super.key,
    required this.state,
  });

  @override
  State<SellerVouchersCouponsSection> createState() => _SellerVouchersCouponsSectionState();
}

class _SellerVouchersCouponsSectionState extends State<SellerVouchersCouponsSection> {
  final List<Map<String, String>> _vouchers = [
    {
      'code': 'EID500',
      'discount': 'PKR 500 OFF',
      'minSpend': 'PKR 3,000',
      'usage': '84 / 100 Used',
      'validity': '31 Aug 2026',
      'status': 'Active',
    },
    {
      'code': 'APNA10',
      'discount': '10% OFF',
      'minSpend': 'PKR 1,500',
      'usage': '62 / 200 Used',
      'validity': '15 Sep 2026',
      'status': 'Active',
    },
    {
      'code': 'WELCOME200',
      'discount': 'PKR 200 OFF',
      'minSpend': 'PKR 1,000',
      'usage': '38 / 50 Used',
      'validity': '30 Sep 2026',
      'status': 'Active',
    },
  ];

  void _showCreateVoucherModal() {
    final codeCtrl = TextEditingController(text: 'PAYDAY300');
    final discountCtrl = TextEditingController(text: '300');
    final minSpendCtrl = TextEditingController(text: '2000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Create Store Discount Voucher', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Voucher Promo Code', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: discountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discount Value (PKR)', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: minSpendCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minimum Order Spend (PKR)', isDense: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            onPressed: () {
              final code = codeCtrl.text.toUpperCase();
              final disc = double.tryParse(discountCtrl.text) ?? 250.0;

              widget.state.addVoucher(code, disc);
              setState(() {
                _vouchers.add({
                  'code': code,
                  'discount': 'PKR ${discountCtrl.text} OFF',
                  'minSpend': 'PKR ${minSpendCtrl.text}',
                  'usage': '0 / 100 Used',
                  'validity': '31 Dec 2026',
                  'status': 'Active',
                });
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Voucher $code created & active on store!'), backgroundColor: const Color(0xFF059669)),
              );
            },
            child: const Text('Create Voucher'),
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
                  Text('Store Vouchers & Promotional Discounts Desk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Create discount coupon codes, set minimum purchase thresholds, and participate in Mega Campaigns.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showCreateVoucherModal,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create Store Voucher', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                  _buildKpiBox('Active Store Vouchers', '${_vouchers.length} Vouchers', Icons.confirmation_number_outlined, const Color(0xFF059669)),
                  _buildKpiBox('Total Redemptions', '184 Redeemed', Icons.redeem_outlined, const Color(0xFF0284C7)),
                  _buildKpiBox('Discounts Granted', 'PKR 46,000 Saved', Icons.savings_outlined, const Color(0xFFB45309)),
                  _buildKpiBox('Conversion Boost', '+32% Cart Checkout', Icons.bolt_outlined, const Color(0xFF7C3AED)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Vouchers Table
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Active Store Vouchers & Discount Coupons', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 14),

                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Expanded(flex: 3, child: Text('PROMO CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)))),
                      Expanded(flex: 2, child: Text('DISCOUNT VALUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)))),
                      Expanded(flex: 2, child: Text('MIN SPEND', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)))),
                      Expanded(flex: 2, child: Text('USAGE LIMIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)))),
                      Expanded(flex: 2, child: Text('VALIDITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)))),
                      Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)))),
                      Expanded(flex: 2, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46)))),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Voucher Rows
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _vouchers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final v = _vouchers[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          // Promo Code
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(6)),
                                  child: Text(v['code']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                                ),
                              ],
                            ),
                          ),

                          // Discount Value
                          Expanded(flex: 2, child: Text(v['discount']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)))),

                          // Min Spend
                          Expanded(flex: 2, child: Text(v['minSpend']!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),

                          // Usage Limit
                          Expanded(flex: 2, child: Text(v['usage']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),

                          // Validity
                          Expanded(flex: 2, child: Text(v['validity']!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),

                          // Status
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                              child: Text(v['status']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                            ),
                          ),

                          // Actions
                          Expanded(
                            flex: 2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Voucher ${v['code']} copied to clipboard!'), backgroundColor: const Color(0xFF059669)),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  child: const Text('Copy Code', style: TextStyle(fontSize: 10, color: Color(0xFF334155))),
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
