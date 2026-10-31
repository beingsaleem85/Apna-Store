import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';
import '../../../../core/services/app_state_provider.dart';

class CustomerUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String city;
  final int totalOrders;
  final double totalSpent;
  double walletBalance;
  bool isSuspended;
  bool isRiskFlagged;
  final String loyaltyTier;

  CustomerUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.totalOrders,
    required this.totalSpent,
    required this.walletBalance,
    this.isSuspended = false,
    this.isRiskFlagged = false,
    required this.loyaltyTier,
  });
}

class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  State<CustomerManagementScreen> createState() => _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
  String _selectedFilter = 'All'; // 'All', 'Active', 'VIP', 'Risk Flagged', 'Suspended'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<CustomerUser> _customers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, email, mobile_number, created_at')
          .limit(100);
      if (res is List && res.isNotEmpty && mounted) {
        setState(() {
          _customers.clear();
          for (final r in res) {
            _customers.add(CustomerUser(
              id: (r['id'] ?? '').toString().substring(0, 8).toUpperCase(),
              name: (r['full_name'] != null && r['full_name'].toString().trim().isNotEmpty)
                  ? r['full_name'].toString()
                  : 'Registered Customer',
              email: (r['email'] ?? '').toString(),
              phone: (r['mobile_number'] ?? 'N/A').toString(),
              city: 'Pakistan',
              totalOrders: 0,
              totalSpent: 0.0,
              walletBalance: 0.0,
              loyaltyTier: 'Member',
            ));
          }
        });
      }
    } catch (_) {
      // Empty state on error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = Provider.of<SuperAdminProvider>(context);

    // Filter Customers based on Filter & Search Query
    final filteredCustomers = _customers.where((cust) {
      final matchesSearch = cust.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          cust.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          cust.phone.contains(_searchQuery) ||
          cust.city.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (_selectedFilter == 'Active') return !cust.isSuspended && !cust.isRiskFlagged;
      if (_selectedFilter == 'VIP') return cust.loyaltyTier == 'Gold' || cust.loyaltyTier == 'Platinum';
      if (_selectedFilter == 'Risk Flagged') return cust.isRiskFlagged;
      if (_selectedFilter == 'Suspended') return cust.isSuspended;
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb & Page Header (Matching Panel 4)
          const Text('Breadcrumbs > Users > Buyer Management', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Buyer Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Export', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Filter Tabs (Matching Panel 4)
          Row(
            children: ['Active', 'Blocked', 'Suspended', 'Verified'].map((tab) {
              final isSel = _selectedFilter == tab || (_selectedFilter == 'All' && tab == 'Active');
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFFEFF6FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSel ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Search Bar
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
                      hintText: 'Search by Customer Name, Email, Phone, City...',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: ['All', 'Active', 'VIP', 'Risk Flagged', 'Suspended'].map((filter) {
                    final isSel = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: ChoiceChip(
                        label: Text(filter, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : const Color(0xFF64748B))),
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

          // Table
          Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Customer Name & Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                        Expanded(child: Text('City', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                        Expanded(child: Text('Loyalty Tier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                        Expanded(child: Text('Wallet Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                        Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                        Expanded(flex: 2, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (filteredCustomers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(Icons.people_outline, size: 48, color: Color(0xFF94A3B8)),
                          SizedBox(height: 12),
                          Text('No registered customer profiles found.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    ...filteredCustomers.map((cust) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          // Customer Info
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF0F172A),
                                  child: Text(cust.name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(cust.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
                                      Text('${cust.email} | ${cust.phone}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // City
                          Expanded(child: Text(cust.city, style: const TextStyle(color: Color(0xFF334155), fontSize: 12))),

                          // Tier Badge
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: cust.loyaltyTier == 'Platinum'
                                    ? const Color(0xFFF3E8FF)
                                    : cust.loyaltyTier == 'Gold'
                                        ? const Color(0xFFFEF3C7)
                                        : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(cust.loyaltyTier.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cust.loyaltyTier == 'Platinum' ? Colors.purple : (cust.loyaltyTier == 'Gold' ? const Color(0xFFD97706) : const Color(0xFF64748B)))),
                            ),
                          ),

                          // Wallet Balance
                          Expanded(
                            child: Row(
                              children: [
                                Text('Rs. ${cust.walletBalance.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 12)),
                                IconButton(
                                  icon: const Icon(Icons.account_balance_wallet, size: 14, color: Color(0xFF64748B)),
                                  tooltip: 'Adjust Wallet Credit',
                                  onPressed: () => _showWalletAdjustmentModal(cust, adminState),
                                ),
                              ],
                            ),
                          ),

                          // Status
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: cust.isSuspended
                                    ? const Color(0xFFFEE2E2)
                                    : cust.isRiskFlagged
                                        ? const Color(0xFFFEF3C7)
                                        : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                cust.isSuspended
                                    ? 'SUSPENDED'
                                    : cust.isRiskFlagged
                                        ? 'RISK FLAGGED'
                                        : 'ACTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: cust.isSuspended
                                      ? Colors.redAccent
                                      : cust.isRiskFlagged
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF059669),
                                ),
                              ),
                            ),
                          ),

                          // Actions
                          Expanded(
                            flex: 2,
                            child: Wrap(
                              spacing: 6,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.person_search_outlined, size: 14),
                                  label: const Text('Inspect', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(foregroundColor: SuperAdminTheme.secondaryGold, side: const BorderSide(color: SuperAdminTheme.borderDark)),
                                  onPressed: () => _showCustomerProfileModal(cust),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cust.isSuspended ? Colors.teal : Colors.redAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () async {
                                    final confirmed = await SuperAdminDialogs.showConfirmation(
                                      context: context,
                                      title: cust.isSuspended ? 'Restore Customer Account' : 'Suspend Customer Account',
                                      message: 'Are you sure you want to ${cust.isSuspended ? 'restore' : 'suspend'} buyer privileges for ${cust.name}?',
                                    );
                                    if (confirmed) {
                                      setState(() => cust.isSuspended = !cust.isSuspended);
                                      adminState.logAuditAction('CUSTOMER_SUSPENSION', cust.name, cust.isSuspended ? 'Suspended account.' : 'Restored account.');
                                      if (mounted) SuperAdminDialogs.showToast(context, '${cust.name} status updated.');
                                    }
                                  },
                                  child: Text(cust.isSuspended ? 'Restore' : 'Suspend', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomerProfileModal(CustomerUser cust) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: SuperAdminTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: AppBreakpoints.getResponsiveDialogWidth(context, defaultDesktopWidth: 550),
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
                      Text('Customer Profile — ${cust.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(color: SuperAdminTheme.borderDark),
              const SizedBox(height: 12),
              Text('Email: ${cust.email}', style: const TextStyle(color: Colors.white70)),
              Text('Phone: ${cust.phone}', style: const TextStyle(color: Colors.white70)),
              Text('City: ${cust.city}', style: const TextStyle(color: Colors.white70)),
              Text('Loyalty Tier: ${cust.loyaltyTier}', style: const TextStyle(color: SuperAdminTheme.secondaryGold, fontWeight: FontWeight.bold)),
              Text('Total Platform Orders: ${cust.totalOrders}', style: const TextStyle(color: Colors.white)),
              Text('Total GMV Spent: Rs. ${cust.totalSpent.toInt()}', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
              Text('Wallet Balance: Rs. ${cust.walletBalance.toInt()}', style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: SuperAdminTheme.primaryTeal),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWalletAdjustmentModal(CustomerUser cust, SuperAdminProvider adminState) {
    final controller = TextEditingController();
    final reasonController = TextEditingController(text: 'Customer support compensation credit.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SuperAdminTheme.cardDark,
        title: Text('Wallet Credit/Debit — ${cust.name}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Amount (e.g. +500 or -200)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Reason for Adjustment', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SuperAdminTheme.primaryTeal),
            onPressed: () {
              final amt = double.tryParse(controller.text);
              if (amt != null) {
                setState(() => cust.walletBalance += amt);
                adminState.logAuditAction('CUSTOMER_WALLET_ADJUSTMENT', cust.name, 'Adjusted wallet balance by Rs. $amt. Reason: ${reasonController.text}');
                Navigator.pop(ctx);
                SuperAdminDialogs.showToast(context, 'Wallet balance updated!');
              }
            },
            child: const Text('Apply Adjustment'),
          ),
        ],
      ),
    );
  }
}
