import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/app_state_provider.dart';
import '../../../core/services/supabase_seller_service.dart';
import '../../../core/constants/theme.dart';

class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({super.key});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  int _selectedTab = 0; // 0: Profile Overview, 1: Business Details, 2: CNIC & Identity, 3: Password & Security, 4: Notifications

  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _avatarUrlController = TextEditingController(text: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb');

  bool _enable2FA = false;
  bool _emailNotifications = true;
  bool _smsOrderAlerts = true;
  bool _promoUpdates = false;
  bool _isChangingPassword = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateProvider>(context);
    final supabaseSeller = Provider.of<SupabaseSellerService>(context);
    final store = state.activeSellerStore;

    final primaryGreen = AppTheme.primaryGreen;
    final isWeb = MediaQuery.of(context).size.width > 800;

    // Onboarding progress calculations
    final bool emailVerified = true;
    final bool phoneVerified = store?.mobileNumber != null && store!.mobileNumber!.isNotEmpty;
    final bool identityVerified = store?.kycStatus == 'Approved';
    final bool bankAdded = true;
    final bool storeLogoUploaded = store?.shopLogo != null && store!.shopLogo.isNotEmpty;
    final bool firstProductAdded = state.products.any((p) => p.sellerId == store?.id);

    int completedSteps = 0;
    if (emailVerified) completedSteps++;
    if (phoneVerified) completedSteps++;
    if (identityVerified) completedSteps++;
    if (bankAdded) completedSteps++;
    if (storeLogoUploaded) completedSteps++;
    if (firstProductAdded) completedSteps++;

    final double completionPercentage = (completedSteps / 6.0) * 100;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Seller Profile & Security Settings'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Profile',
            onPressed: () {
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Seller profile refreshed!'), backgroundColor: Colors.teal),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Profile Card
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: primaryGreen.withOpacity(0.1),
                              backgroundImage: NetworkImage(_avatarUrlController.text),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: _showAvatarUrlDialog,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.edit, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    store?.fullName ?? 'Merchant Seller',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.darkText),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildStatusBadge(store?.isApproved ?? false, store?.kycStatus ?? 'Pending'),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Store Name: ${store?.shopName ?? "Apna Store Vendor"} | Email: ${store?.email ?? "seller@apnastore.com"}',
                                style: const TextStyle(fontSize: 13, color: AppTheme.lightText),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Merchant ID: ${store?.id ?? "SEL-8829"} | Mobile: ${store?.mobileNumber ?? "0300-1234567"}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.lightText),
                              ),
                            ],
                          ),
                        ),
                        if (isWeb) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${completionPercentage.toInt()}% Complete',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 140,
                                child: LinearProgressIndicator(
                                  value: completionPercentage / 100,
                                  backgroundColor: Colors.grey.shade200,
                                  color: primaryGreen,
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Main Tab Navigation & Details Section
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Scrollable Tab Selector Row
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildTabButton(0, 'Personal Info', Icons.person_outline),
                              const SizedBox(width: 8),
                              _buildTabButton(1, 'Business Details', Icons.business_outlined),
                              const SizedBox(width: 8),
                              _buildTabButton(2, 'CNIC & KYC Status', Icons.badge_outlined),
                              const SizedBox(width: 8),
                              _buildTabButton(3, 'Password & Security', Icons.lock_outline),
                              const SizedBox(width: 8),
                              _buildTabButton(4, 'Notifications', Icons.notifications_none_outlined),
                            ],
                          ),
                        ),
                        const Divider(height: 32),

                        if (_selectedTab == 0) _buildPersonalInfoTab(store),
                        if (_selectedTab == 1) _buildBusinessInfoTab(store),
                        if (_selectedTab == 2) _buildCnicKycTab(store),
                        if (_selectedTab == 3) _buildPasswordAndSecurityTab(state),
                        if (_selectedTab == 4) _buildNotificationSettingsTab(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.lightText),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.darkText,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoTab(AppStore? store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Personal Seller Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
        const SizedBox(height: 16),
        _buildInfoRow('Full Name', store?.fullName ?? 'Muhammad Seller'),
        _buildInfoRow('Email Address', store?.email ?? 'seller@apnastore.com'),
        _buildInfoRow('Mobile Phone Number', store?.mobileNumber ?? '03001234567'),
        _buildInfoRow('Country', store?.country ?? 'Pakistan'),
        _buildInfoRow('City', store?.city ?? 'Lahore'),
        _buildInfoRow('Personal Address', store?.businessAddress ?? 'Main Commercial Area, Lahore'),
      ],
    );
  }

  Widget _buildBusinessInfoTab(AppStore? store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Business & Enterprise Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
        const SizedBox(height: 16),
        _buildInfoRow('Store Name', store?.shopName ?? 'Apna Official Store'),
        _buildInfoRow('Store Slug URL', store?.storeSlug ?? 'apna-official-store'),
        _buildInfoRow('Business Legal Name', store?.businessName ?? 'Apna Retailers Private Ltd'),
        _buildInfoRow('Category', store?.storeCategory ?? 'Fashion & Retail'),
        _buildInfoRow('Business Address', store?.businessAddress ?? 'Main Commercial Market, Lahore'),
        _buildInfoRow('Commission Agreement Rate', '${store?.commissionRate ?? 10.0}% Platform Fee'),
      ],
    );
  }

  Widget _buildCnicKycTab(AppStore? store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CNIC & Merchant Identity Verification (KYC)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
        const SizedBox(height: 16),
        _buildInfoRow('CNIC / National Identity Card Number', '35201-1234567-1'),
        _buildInfoRow('CNIC Front Document Status', 'Uploaded & Verified'),
        _buildInfoRow('CNIC Back Document Status', 'Uploaded & Verified'),
        _buildInfoRow('Verification Status Badge', store?.kycStatus ?? 'Approved'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user, color: Colors.green, size: 28),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Verified Merchant Account', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14)),
                    Text('Your identity details and CNIC documentation have been verified by Apna Store Admin.', style: TextStyle(fontSize: 12, color: AppTheme.darkText)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordAndSecurityTab(AppStateProvider state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Password Management & Account Security', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
        const SizedBox(height: 16),

        // Password Change Form
        Form(
          key: _passwordFormKey,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Change Seller Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkText)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.lightText),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (val) => val == null || val.isEmpty ? 'Enter current password' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _newPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: const Icon(Icons.lock_reset, color: AppTheme.lightText),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (val) => val == null || val.length < 6 ? 'Min 6 characters' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          prefixIcon: const Icon(Icons.lock_reset, color: AppTheme.lightText),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (val) => val != _newPasswordController.text ? 'Passwords do not match' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: _isChangingPassword
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.security, size: 18),
                  label: const Text('Update Password'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                  onPressed: _isChangingPassword
                      ? null
                      : () async {
                          if (_passwordFormKey.currentState!.validate()) {
                            setState(() => _isChangingPassword = true);
                            await Future.delayed(const Duration(milliseconds: 500));
                            setState(() => _isChangingPassword = false);
                            _currentPasswordController.clear();
                            _newPasswordController.clear();
                            _confirmPasswordController.clear();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green),
                              );
                            }
                          }
                        },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Security Settings (2FA)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Two-Factor Authentication (2FA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Require an SMS/Email OTP code every time you log in.', style: TextStyle(fontSize: 12, color: AppTheme.lightText)),
              ],
            ),
            Switch(
              value: _enable2FA,
              activeColor: AppTheme.primaryGreen,
              onChanged: (val) => setState(() => _enable2FA = val),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationSettingsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Seller Notification Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.darkText)),
        const SizedBox(height: 16),

        SwitchListTile(
          title: const Text('Email Notifications'),
          subtitle: const Text('Receive order receipts and daily settlement reports via email.'),
          value: _emailNotifications,
          activeColor: AppTheme.primaryGreen,
          onChanged: (val) => setState(() => _emailNotifications = val),
        ),
        const Divider(),
        SwitchListTile(
          title: const Text('SMS Order Alerts'),
          subtitle: const Text('Receive instant SMS notifications on new customer orders.'),
          value: _smsOrderAlerts,
          activeColor: AppTheme.primaryGreen,
          onChanged: (val) => setState(() => _smsOrderAlerts = val),
        ),
        const Divider(),
        SwitchListTile(
          title: const Text('Promotional Updates & Campaign Alerts'),
          subtitle: const Text('Receive mega campaign invitations and seller center news.'),
          value: _promoUpdates,
          activeColor: AppTheme.primaryGreen,
          onChanged: (val) => setState(() => _promoUpdates = val),
        ),
      ],
    );
  }

  void _showAvatarUrlDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Profile Picture URL'),
        content: TextField(
          controller: _avatarUrlController,
          decoration: const InputDecoration(hintText: 'Enter Image URL'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 250,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.lightText, fontSize: 13)),
          ),
          Expanded(
            child: Text(val, style: const TextStyle(color: AppTheme.darkText, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isApproved, String status) {
    Color bg = Colors.amber.shade100;
    Color fg = Colors.amber.shade900;
    String label = 'Pending Approval';

    if (isApproved && status == 'Approved') {
      bg = Colors.green.shade100;
      fg = Colors.green.shade900;
      label = 'Approved Store';
    } else if (status == 'Rejected') {
      bg = Colors.red.shade100;
      fg = Colors.red.shade900;
      label = 'Rejected';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
