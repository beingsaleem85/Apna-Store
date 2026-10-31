import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/app_auth_provider.dart';
import '../../../../core/services/app_state_provider.dart';

class BuyerAccountSection extends StatefulWidget {
  final AppStateProvider state;
  final double screenWidth;
  final VoidCallback onGoHome;
  final VoidCallback onShowCart;

  const BuyerAccountSection({
    super.key,
    required this.state,
    required this.screenWidth,
    required this.onGoHome,
    required this.onShowCart,
  });

  @override
  State<BuyerAccountSection> createState() => _BuyerAccountSectionState();
}

class _BuyerAccountSectionState extends State<BuyerAccountSection> {
  String _selectedSizePref = 'Medium (M)';
  String _selectedSkinPref = 'Sensitive / Combination';
  String _selectedDietPref = 'Halal / Organic';

  Widget _buildBuyerSidebarItem(IconData icon, String label, bool isActive, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: isActive ? const Color(0xFF004D40) : const Color(0xFF64748B), size: 20),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? const Color(0xFF004D40) : const Color(0xFF334155),
          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          fontSize: 13,
        ),
      ),
      selected: isActive,
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }

  Widget _buildBuyerOrderRow({
    required String orderId,
    required String date,
    required String status,
    required String total,
    required Color statusColor,
    required String itemsCount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(orderId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$itemsCount • Placed on $date', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              Text(total, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004D40))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountHubCard({
    required String title,
    required IconData icon,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildAccountTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: const Color(0xFF004D40), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildPrefDropdown(String label, String currentVal, List<String> options, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCBD5E1)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentVal,
              isExpanded: true,
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
              items: options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Utility Bar
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1280),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () {},
                      child: const Text('Set a Password', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    ),
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () => Navigator.pushNamed(context, '/buyer/order-tracking'),
                      child: const Text('Track Orders', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: const [
                        Text('English', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
                        Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF475569)),
                        SizedBox(width: 8),
                        Text('اردو', style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main Account Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1280),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    InkWell(
                      onTap: widget.onGoHome,
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: const Color(0xFF004D40), borderRadius: BorderRadius.circular(6)),
                            child: const Center(child: Icon(Icons.storefront, color: Colors.white, size: 18)),
                          ),
                          const SizedBox(width: 8),
                          const Text('APNA STORE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF334155)),
                      onPressed: widget.onShowCart,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Account Center Body
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1280),
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Navigation Sidebar (Desktop)
                  if (widget.screenWidth > 850)
                    SizedBox(
                      width: 250,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            const CircleAvatar(
                              radius: 32,
                              backgroundColor: Color(0xFF004D40),
                              child: Icon(Icons.person, size: 36, color: Colors.white),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.state.isCustomerLoggedIn ? (widget.state.loggedInCustomerName ?? 'Customer') : 'Guest Customer',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              widget.state.isCustomerLoggedIn ? (widget.state.loggedInCustomerEmail ?? 'No email') : 'Not signed in',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            _buildBuyerSidebarItem(Icons.person_outline, 'Profile Information', true),
                            _buildBuyerSidebarItem(Icons.location_on_outlined, 'Address Book', false, onTap: () => Navigator.pushNamed(context, '/buyer/addresses')),
                            _buildBuyerSidebarItem(Icons.local_shipping_outlined, 'My Orders', false, onTap: () => Navigator.pushNamed(context, '/buyer/orders')),
                            _buildBuyerSidebarItem(Icons.account_balance_wallet_outlined, 'Wallet & BNPL', false, onTap: () => Navigator.pushNamed(context, '/buyer/wallet')),
                            _buildBuyerSidebarItem(Icons.favorite_border, 'Wishlist', false, onTap: () => Navigator.pushNamed(context, '/buyer/wishlist')),
                            _buildBuyerSidebarItem(
                              Icons.tune_outlined,
                              'Personal Preferences',
                              false,
                              onTap: () => _showPersonalPreferencesDialog(context),
                            ),
                            _buildBuyerSidebarItem(Icons.help_outline, 'Help & Support', false, onTap: () => Navigator.pushNamed(context, '/buyer/chat-qa')),
                            const Divider(height: 1, indent: 16, endIndent: 16),
                            ListTile(
                              leading: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                              title: const Text(
                                'Logout Account',
                                style: TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              onTap: () async {
                                await Provider.of<AppAuthProvider>(context, listen: false).signOut();
                                widget.onGoHome();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Logged out successfully!'),
                                      backgroundColor: Color(0xFFDC2626),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                  if (widget.screenWidth > 850) const SizedBox(width: 24),

                  // Main Account Dashboard Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hub Stats Cards Grid
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: widget.screenWidth > 1000 ? 3 : (widget.screenWidth > 600 ? 2 : 1),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.6,
                          children: [
                            _buildAccountHubCard(
                              title: 'Wallet Balance',
                              icon: Icons.account_balance_wallet,
                              value: 'PKR ${widget.state.walletCash.toStringAsFixed(0)}',
                              subtitle: 'Cash Credit Ledger',
                              color: const Color(0xFF004D40),
                            ),
                            _buildAccountHubCard(
                              title: 'Promo Credits',
                              icon: Icons.card_giftcard,
                              value: 'PKR ${widget.state.walletPromoCredits.toStringAsFixed(0)}',
                              subtitle: 'App Store Rewards',
                              color: const Color(0xFFFDB913),
                            ),
                            _buildAccountHubCard(
                              title: 'BNPL Credit Limit',
                              icon: Icons.credit_score,
                              value: 'PKR ${widget.state.bnplCreditLimit.toStringAsFixed(0)}',
                              subtitle: 'Pay in 4 Installments',
                              color: const Color(0xFF0284C7),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // Personalization Preferences Box
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
                                children: const [
                                  Icon(Icons.auto_awesome, color: Color(0xFF004D40), size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'AI Personalization & Sizing Profile',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Customize your sizing and product preferences for personalized recommendations.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildPrefDropdown(
                                      'Preferred Size',
                                      _selectedSizePref,
                                      ['Small (S)', 'Medium (M)', 'Large (L)', 'XL'],
                                      (v) => setState(() => _selectedSizePref = v!),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildPrefDropdown(
                                      'Skin Type',
                                      _selectedSkinPref,
                                      ['Normal', 'Sensitive / Combination', 'Oily', 'Dry'],
                                      (v) => setState(() => _selectedSkinPref = v!),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildPrefDropdown(
                                      'Dietary Preference',
                                      _selectedDietPref,
                                      ['Halal / Organic', 'Vegan', 'Gluten Free'],
                                      (v) => setState(() => _selectedDietPref = v!),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Recent Orders List Section
                        const Text('Recent Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 12),
                        _buildBuyerOrderRow(
                          orderId: 'Order #ORD-2026-8891',
                          date: '12 Aug 2026',
                          status: 'Delivered',
                          total: 'PKR 14,500',
                          statusColor: const Color(0xFF16A34A),
                          itemsCount: '3 Items',
                        ),
                        _buildBuyerOrderRow(
                          orderId: 'Order #ORD-2026-7732',
                          date: '04 Aug 2026',
                          status: 'In Transit',
                          total: 'PKR 3,200',
                          statusColor: const Color(0xFF0284C7),
                          itemsCount: '1 Item',
                        ),

                        const SizedBox(height: 28),

                        // Quick Account Tiles
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              _buildAccountTile(
                                icon: Icons.location_on,
                                title: 'Shipping & Delivery Addresses',
                                subtitle: 'Manage saved addresses for quick checkout',
                                onTap: () => Navigator.pushNamed(context, '/buyer/addresses'),
                              ),
                              const Divider(height: 1),
                              _buildAccountTile(
                                icon: Icons.assignment_return,
                                title: 'Returns & Claims Center',
                                subtitle: 'Track active return requests and refunds',
                                onTap: () => Navigator.pushNamed(context, '/buyer/returns'),
                              ),
                              const Divider(height: 1),
                              _buildAccountTile(
                                icon: Icons.support_agent,
                                title: '24/7 Customer Support',
                                subtitle: 'Get help with orders, wallet, and products',
                                onTap: () => Navigator.pushNamed(context, '/buyer/chat-qa'),
                              ),
                            ],
                          ),
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
    );
  }

  void _showPersonalPreferencesDialog(BuildContext context) {
    bool emailNotifications = true;
    bool smsAlerts = true;
    bool promoOffers = false;
    String selectedLanguage = 'English';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.tune_outlined, color: Color(0xFF0F172A)),
                  SizedBox(width: 10),
                  Text('Personal Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Customize your shopping & notification preferences.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 16),

                  // Language Preference
                  const Text('App Language', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedLanguage,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'English', child: Text('English (US)')),
                      DropdownMenuItem(value: 'Urdu', child: Text('اردو (Urdu)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedLanguage = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Notification Toggles
                  const Text('Notifications & Alerts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                  const SizedBox(height: 8),

                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Email Order Updates', style: TextStyle(fontSize: 13)),
                    value: emailNotifications,
                    activeColor: const Color(0xFF059669),
                    onChanged: (val) => setModalState(() => emailNotifications = val),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('SMS Shipping Alerts', style: TextStyle(fontSize: 13)),
                    value: smsAlerts,
                    activeColor: const Color(0xFF059669),
                    onChanged: (val) => setModalState(() => smsAlerts = val),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Flash Sale & Promotional Offers', style: TextStyle(fontSize: 13)),
                    value: promoOffers,
                    activeColor: const Color(0xFF059669),
                    onChanged: (val) => setModalState(() => promoOffers = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Personal preferences saved successfully!'),
                        backgroundColor: Color(0xFF059669),
                      ),
                    );
                  },
                  child: const Text('Save Preferences'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
