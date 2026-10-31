import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';
import '../../../../core/services/app_state_provider.dart';

class SellerGovernanceScreen extends StatefulWidget {
  const SellerGovernanceScreen({super.key});

  @override
  State<SellerGovernanceScreen> createState() => _SellerGovernanceScreenState();
}

class _SellerGovernanceScreenState extends State<SellerGovernanceScreen> {
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Approved', 'Suspended', 'Rejected'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  AppStore? _selectedStore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      appState.fetchStoresFromSupabase().then((_) {
        if (mounted && appState.stores.isNotEmpty) {
          setState(() => _selectedStore = appState.stores.first);
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final adminState = Provider.of<SuperAdminProvider>(context);

    // Filter Stores based on Selected Chip & Search Query
    final filteredStores = appState.stores.where((store) {
      final name = store.shopName.toLowerCase();
      final owner = (store.fullName ?? store.businessName ?? '').toLowerCase();
      final phone = store.mobileNumber ?? store.storeContactNumber ?? '';

      final matchesSearch = name.contains(_searchQuery.toLowerCase()) ||
          owner.contains(_searchQuery.toLowerCase()) ||
          phone.contains(_searchQuery);

      if (!matchesSearch) return false;

      if (_selectedFilter == 'Pending') return store.kycStatus == 'Pending' || !store.isApproved;
      if (_selectedFilter == 'Approved') return store.kycStatus == 'Approved' && store.isApproved;
      if (_selectedFilter == 'Suspended') return store.kycStatus == 'Suspended';
      if (_selectedFilter == 'Rejected') return store.kycStatus == 'Rejected';
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb & Page Header (Matching Panel 3)
          const Text('Breadcrumbs > Users > Seller Management', style: TextStyle(color: Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Seller Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Bulk actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Row(
                      children: [
                        Text('Quick actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tabs (Matching Panel 3)
          Row(
            children: ['Pending Seller Application', 'Documents Date'].map((tab) {
              final isSel = tab == 'Pending Seller Application';
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: isSel ? const Border(bottom: BorderSide(color: Color(0xFF2563EB), width: 2)) : null,
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? const Color(0xFF2563EB) : const Color(0xFF334155),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Main Content Layout Split: Table on Left + Details Panel on Right (Matching Panel 3)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Content (Flex 7)
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    // Filter Chips Bar
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                              onChanged: (val) => setState(() => _searchQuery = val),
                              decoration: const InputDecoration(
                                hintText: 'Search by Store Name, Owner Name, Phone...',
                                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF334155)),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            children: ['All', 'Pending', 'Approved', 'Suspended', 'Rejected'].map((filter) {
                              final isSel = _selectedFilter == filter;
                              return Padding(
                                padding: const EdgeInsets.only(left: 4.0),
                                child: ChoiceChip(
                                  label: Text(filter, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : const Color(0xFF334155))),
                                  selected: isSel,
                                  selectedColor: const Color(0xFF0F172A),
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  onSelected: (val) => setState(() => _selectedFilter = filter),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

          // Master Seller Table
          Card(
            color: SuperAdminTheme.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: SuperAdminTheme.borderDark)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Table Column Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: SuperAdminTheme.bgDark, borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Store & Merchant Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)))),
                        Expanded(child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)))),
                        Expanded(child: Text('CNIC / KYC Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)))),
                        Expanded(child: Text('Commission Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)))),
                        Expanded(flex: 2, child: Text('Governance Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (filteredStores.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(Icons.storefront_outlined, size: 48, color: Color(0xFF334155)),
                          SizedBox(height: 12),
                          Text('No merchant stores found matching selected filter criteria.', style: TextStyle(color: Color(0xFF334155), fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    ...filteredStores.map((store) {
                      final isPending = store.kycStatus == 'Pending' || !store.isApproved;
                      final isApproved = store.kycStatus == 'Approved' && store.isApproved;
                      final ownerName = store.fullName ?? store.businessName ?? 'Merchant';
                      final phone = store.mobileNumber ?? store.storeContactNumber ?? 'N/A';
                      final category = store.storeCategory ?? 'General Marketplace';

                      return InkWell(
                        onTap: () => setState(() => _selectedStore = store),
                        child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: SuperAdminTheme.cardDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: SuperAdminTheme.borderDark),
                        ),
                        child: Row(
                          children: [
                            // Store Info
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: SuperAdminTheme.primaryTeal,
                                    child: Text(store.shopName.isNotEmpty ? store.shopName.substring(0, 1).toUpperCase() : 'S', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(store.shopName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 14)),
                                        Text('$ownerName ($phone)', style: const TextStyle(color: Color(0xFF334155), fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Category
                            Expanded(child: Text(category, style: const TextStyle(color: Color(0xFF334155), fontSize: 12))),

                            // KYC Status Badge
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isApproved
                                      ? Colors.green.withOpacity(0.2)
                                      : isPending
                                          ? Colors.amber.withOpacity(0.2)
                                          : Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  store.kycStatus.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isApproved
                                        ? Colors.green
                                        : isPending
                                            ? Colors.amber
                                            : Colors.redAccent,
                                  ),
                                ),
                              ),
                            ),

                            // Commission Rate
                            Expanded(
                              child: Row(
                                children: [
                                  Text('${store.commissionRate}%', style: const TextStyle(fontWeight: FontWeight.bold, color: SuperAdminTheme.secondaryGold, fontSize: 13)),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 14, color: Color(0xFF334155)),
                                    tooltip: 'Override Commission Rate',
                                    onPressed: () => _showCommissionOverrideModal(store, appState, adminState),
                                  ),
                                ],
                              ),
                            ),

                            // Action Buttons
                            Expanded(
                              flex: 2,
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  // Inspect KYC Modal Button
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.badge_outlined, size: 14),
                                    label: const Text('KYC Docs', style: TextStyle(fontSize: 11)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: SuperAdminTheme.secondaryGold,
                                      side: const BorderSide(color: SuperAdminTheme.borderDark),
                                    ),
                                    onPressed: () => _showKycInspectionModal(store),
                                  ),

                                  // Approve Button
                                  if (!isApproved)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                                      onPressed: () async {
                                        final confirmed = await SuperAdminDialogs.showConfirmation(
                                          context: context,
                                          title: 'Approve Merchant Store',
                                          message: 'Are you sure you want to approve "${store.shopName}" for active marketplace selling?',
                                          confirmColor: Colors.teal,
                                        );
                                        if (confirmed) {
                                          try {
                                            await appState.approveStore(store.id);
                                            adminState.logAuditAction('STORE_APPROVAL', store.shopName, 'Approved merchant store and activated catalog privileges.');
                                            if (mounted) SuperAdminDialogs.showToast(context, '${store.shopName} Approved Successfully!');
                                          } catch (e) {
                                            if (mounted) SuperAdminDialogs.showToast(context, 'Approval failed: $e', isError: true);
                                          }
                                        }
                                      },
                                      child: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),

                                  // Suspend Button
                                  if (isApproved)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                      onPressed: () async {
                                        final reason = await SuperAdminDialogs.showReasonInput(
                                          context: context,
                                          title: 'Suspend Merchant Store',
                                          labelText: 'Suspension Reason',
                                          hintText: 'Enter reason for suspending merchant account...',
                                        );
                                        if (reason != null && reason.isNotEmpty) {
                                          try {
                                            await appState.rejectStore(store.id, reason);
                                            adminState.logAuditAction('SELLER_SUSPENSION', store.shopName, 'Suspended store. Reason: $reason');
                                            if (mounted) SuperAdminDialogs.showToast(context, '${store.shopName} Suspended.', isError: true);
                                          } catch (e) {
                                            if (mounted) SuperAdminDialogs.showToast(context, 'Suspension failed: $e', isError: true);
                                          }
                                        }
                                      },
                                      child: const Text('Suspend', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
  const SizedBox(width: 16),

  // Right Side Details Drawer Panel — Merchant Store Governance
  Expanded(
    flex: 3,
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
          // Header with Store Title
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Merchant Store Governance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Icon(Icons.storefront, color: Color(0xFF0F172A), size: 20),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedStore == null)
            const Center(child: Text('Select a store from the list', style: TextStyle(color: Color(0xFF334155)))),
          if (_selectedStore != null) ...[
            // Store Avatar & Info
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0xFF0F172A),
                    child: Icon(Icons.store, size: 30, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(_selectedStore!.shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                  Text('Owner: ${_selectedStore!.fullName ?? _selectedStore!.businessName ?? "Unknown"} (Verified Merchant)', style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Store Performance Metrics Box
            const Text('Store Lifetime Revenue', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
            const SizedBox(height: 2),
            const Text('PKR 450,000', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const Text('Verified Business CNIC: 35201-9988776-5', style: TextStyle(fontSize: 10, color: Color(0xFF334155))),
              const SizedBox(height: 16),
  
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 8),
              
              // Detailed Store Info
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Active Catalog Listings', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                  Text('48 Products', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Marketplace Commission', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                Text('10.0%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Settlement Bank/Wallet', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                Text('EasyPaisa Account', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFFE2E8F0)),

            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Eligible Payout Balance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                Text('PKR 42,500', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
              ],
            ),
            const SizedBox(height: 20),

            // Actions Buttons
            const Text('Merchant Governance Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.badge_outlined, size: 14),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    onPressed: () {
                      _showKycInspectionModal(_selectedStore!);
                    },
                    label: const Text('KYC Docs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit, size: 14),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: () {
                      _showCommissionOverrideModal(_selectedStore!, appState, adminState);
                    },
                    label: const Text('Override Rate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Store Quality Metrics
            const Text('Merchant Health Score', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Order Fulfillment Rate', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                Text('98.5%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
              ],
            ),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Customer Dispute Rate', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                Text('1.2%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
              ],
            ),
            ],
          ],
        ),
      ),
    ),
  ],
),
],
),
);
  }

  void _showKycInspectionModal(AppStore store) {
    final owner = store.fullName ?? store.businessName ?? 'Merchant';
    final city = store.city ?? 'Pakistan';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: SuperAdminTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: AppBreakpoints.getResponsiveDialogWidth(context, defaultDesktopWidth: 650),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.badge, color: SuperAdminTheme.secondaryGold),
                      const SizedBox(width: 10),
                      Text('Merchant KYC Inspection — ${store.shopName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(color: SuperAdminTheme.borderDark),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Owner Name: $owner', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('City / Address: $city', style: const TextStyle(color: Color(0xFF334155), fontSize: 12)),
                        Text('KYC Verification Status: ${store.kycStatus}', style: const TextStyle(color: SuperAdminTheme.secondaryGold, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Mock Document Images Preview Grid
              Row(
                children: [
                  Expanded(child: _buildDocPreviewCard('CNIC Front Document', Icons.badge_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDocPreviewCard('CNIC Back Document', Icons.badge_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDocPreviewCard('Merchant Selfie Photo', Icons.face)),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: SuperAdminTheme.primaryTeal, foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close Inspection Modal'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocPreviewCard(String label, IconData icon) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: SuperAdminTheme.bgDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SuperAdminTheme.borderDark),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: SuperAdminTheme.secondaryGold),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _showCommissionOverrideModal(AppStore store, AppStateProvider appState, SuperAdminProvider adminState) {
    final controller = TextEditingController(text: store.commissionRate.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SuperAdminTheme.cardDark,
        title: Text('Commission Override — ${store.shopName}', style: const TextStyle(color: SuperAdminTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: SuperAdminTheme.textLight),
          decoration: const InputDecoration(labelText: 'Custom Platform Commission Rate (%)', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SuperAdminTheme.primaryTeal, foregroundColor: Colors.white),
            onPressed: () async {
              final newRate = double.tryParse(controller.text);
              if (newRate != null) {
                try {
                  await appState.adjustCommission(store.id, newRate);
                  adminState.logAuditAction('COMMISSION_OVERRIDE', store.shopName, 'Updated store commission rate to $newRate%.');
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    SuperAdminDialogs.showToast(context, 'Commission Rate Updated to $newRate%');
                    setState(() {});
                  }
                } catch (e) {
                  if (ctx.mounted) SuperAdminDialogs.showToast(context, 'Update failed: $e', isError: true);
                }
              }
            },
            child: const Text('Save Override'),
          ),
        ],
      ),
    );
  }
}
