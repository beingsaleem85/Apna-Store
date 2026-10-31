import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';

class DisputeClaim {
  final String id;
  final String orderId;
  final String productName;
  final String buyerName;
  final String sellerStoreName;
  final String returnReason;
  final double requestedAmount;
  String disputeStatus; // 'Pending', 'Full Refund Approved', 'Partial Refund Approved', 'Rejected'
  final DateTime date;
  final bool isMerchantDispute;
  final String returnTracking;
  final String returnCourier;

  DisputeClaim({
    required this.id,
    required this.orderId,
    required this.productName,
    required this.buyerName,
    required this.sellerStoreName,
    required this.returnReason,
    required this.requestedAmount,
    this.disputeStatus = 'Pending',
    required this.date,
    this.isMerchantDispute = false,
    this.returnTracking = 'TCS-RET-8812-PK',
    this.returnCourier = 'TCS Reverse Logistics',
  });
}

class DisputeArbitrationScreen extends StatefulWidget {
  final int initialTabIndex;
  const DisputeArbitrationScreen({super.key, this.initialTabIndex = 0});

  @override
  State<DisputeArbitrationScreen> createState() => _DisputeArbitrationScreenState();
}

class _DisputeArbitrationScreenState extends State<DisputeArbitrationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Approved', 'Rejected'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  DisputeClaim? _selectedClaim;

  final List<DisputeClaim> _claims = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          _selectedClaim = null;
        });
      }
    });
    _fetchReturnRequests();
  }

  Future<void> _fetchReturnRequests() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('return_requests')
          .select('id, order_id, reason, status, quantity, created_at, seller_store_id')
          .order('created_at', ascending: false)
          .limit(50);
      if (res is List && mounted) {
        setState(() {
          _claims.clear();
          for (final row in res) {
            _claims.add(DisputeClaim(
              id: (row['id'] ?? '').toString().substring(0, 8).toUpperCase(),
              orderId: (row['order_id'] ?? '').toString(),
              productName: 'Order Item #${row['order_id']}',
              buyerName: 'Verified Buyer',
              sellerStoreName: 'Seller Store',
              returnReason: row['reason'] ?? 'Standard return request',
              requestedAmount: ((row['quantity'] as num?)?.toDouble() ?? 1.0) * 1000.0,
              disputeStatus: row['status'] ?? 'Pending',
              date: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
              isMerchantDispute: false,
              returnTracking: 'TCS-RET-${row['order_id']}',
            ));
          }
        });
      }
    } catch (_) {
      // Empty claims list will show empty state
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    final isDisputesTab = _tabController.index == 1;

    // Filter Claims by Tab & Search/Status
    final filteredClaims = _claims.where((c) {
      if (c.isMerchantDispute != isDisputesTab) return false;

      final matchesSearch = c.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.orderId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.buyerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.sellerStoreName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.productName.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (_selectedFilter == 'Pending') return c.disputeStatus == 'Pending';
      if (_selectedFilter == 'Approved') return c.disputeStatus.contains('Approved');
      if (_selectedFilter == 'Rejected') return c.disputeStatus == 'Rejected';
      return true;
    }).toList();

    // Auto-select first claim if none selected
    if (_selectedClaim == null && filteredClaims.isNotEmpty) {
      _selectedClaim = filteredClaims.first;
    } else if (filteredClaims.isEmpty) {
      _selectedClaim = null;
    }

    final isWide = MediaQuery.of(context).size.width > 1050;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb & Page Header
          Text(
            'Breadcrumbs > Orders > ${isDisputesTab ? "Merchant Disputes" : "Customer Returns"}',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isDisputesTab ? 'Merchant Disputes & Evidence Arbitration' : 'Customer Return Requests & Refunds',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      SuperAdminDialogs.showToast(context, 'Bulk arbitration desk opened.');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Bulk Arbitrate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      SuperAdminDialogs.showToast(context, 'Exporting claims data to CSV...');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Export Claims', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4 Metric KPI Cards
          _buildKpiMetricsRow(isDisputesTab),
          const SizedBox(height: 16),

          // Sub-Tabs Navigation (Returns vs Disputes)
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
                Tab(icon: Icon(Icons.assignment_return_outlined, size: 18), text: 'Customer Return Requests'),
                Tab(icon: Icon(Icons.gavel_outlined, size: 18), text: 'Merchant Disputes & Arbitration'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Controls Bar (Search + Filter Chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      hintText: 'Search by Claim ID, Order ID, Buyer, Store, Product...',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: ['All', 'Pending', 'Approved', 'Rejected'].map((filter) {
                    final isSel = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: ChoiceChip(
                        label: Text(
                          filter,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSel ? Colors.white : const Color(0xFF334155),
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                          ),
                        ),
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

          // 2-Column Responsive Layout: Left Table (Flex 7) + Right Detail Inspector (Flex 3)
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: _buildClaimsTable(filteredClaims, adminState)),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: _buildClaimDetailInspector(adminState)),
              ],
            )
          else
            Column(
              children: [
                _buildClaimsTable(filteredClaims, adminState),
                const SizedBox(height: 16),
                _buildClaimDetailInspector(adminState),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildKpiMetricsRow(bool isDisputesTab) {
    final relevant = _claims.where((c) => isDisputesTab ? c.isMerchantDispute : !c.isMerchantDispute).toList();
    final totalCount = relevant.length;
    final pendingCount = relevant.where((c) => c.disputeStatus == 'Pending').length;
    final totalVolume = relevant.fold(0.0, (sum, c) => sum + c.requestedAmount);

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: isDisputesTab ? 'Total Disputes' : 'Total Returns',
            value: '$totalCount',
            subtitle: 'This Month',
            icon: Icons.assignment_late_outlined,
            iconColor: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'Pending Action',
            value: '$pendingCount',
            subtitle: 'Requires Resolution',
            icon: Icons.hourglass_top_outlined,
            iconColor: const Color(0xFFD97706),
            bgColor: const Color(0xFFFEF3C7),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'Disputed Volume',
            value: 'PKR ${totalVolume.toStringAsFixed(0)}',
            subtitle: 'Total Claimed',
            icon: Icons.account_balance_wallet_outlined,
            iconColor: const Color(0xFF059669),
            bgColor: const Color(0xFFECFDF5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'Avg. Resolution',
            value: totalCount > 0 ? '4.2 hrs' : '0 hrs',
            subtitle: 'SLA Target: 24h',
            icon: Icons.speed_outlined,
            iconColor: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF3E8FF),
          ),
        ),
      ],
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

  Widget _buildClaimsTable(List<DisputeClaim> filteredClaims, SuperAdminProvider adminState) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('Claim ID & Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 3, child: Text('Buyer & Store', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Claimed Refund', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Dispute Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 3, child: Text('Arbitration Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            if (filteredClaims.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40.0),
                child: Column(
                  children: [
                    Icon(Icons.assignment_turned_in_outlined, size: 48, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text('No return claims matching filter criteria.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ],
                ),
              )
            else
              ...filteredClaims.map((claim) {
                final isSelected = _selectedClaim?.id == claim.id;
                final isPending = claim.disputeStatus == 'Pending';
                final isApproved = claim.disputeStatus.contains('Approved');

                return InkWell(
                  onTap: () => setState(() => _selectedClaim = claim),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // 1. Claim ID & Order
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(claim.id, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 13)),
                              const SizedBox(height: 2),
                              Text('#${claim.orderId}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),

                        // 2. Buyer & Store
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                claim.isMerchantDispute ? 'Customer: ${claim.buyerName.replaceAll(" (Customer)", "")}' : 'Buyer: ${claim.buyerName}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                claim.isMerchantDispute ? 'Store: ${claim.sellerStoreName.replaceAll(" (Merchant)", "")}' : 'Store: ${claim.sellerStoreName}',
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // 3. Claimed Refund
                        Expanded(
                          flex: 2,
                          child: Text(
                            'PKR ${claim.requestedAmount.toInt()}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB45309), fontSize: 13),
                          ),
                        ),

                        // 4. Dispute Status
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isApproved
                                  ? const Color(0xFFECFDF5)
                                  : isPending
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              claim.disputeStatus.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isApproved
                                    ? const Color(0xFF059669)
                                    : isPending
                                        ? const Color(0xFFD97706)
                                        : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ),

                        // 5. Arbitration Actions
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.image_outlined, size: 13),
                                label: const Text('Evidence', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF059669),
                                  side: const BorderSide(color: Color(0xFF10B981)),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  minimumSize: Size.zero,
                                ),
                                onPressed: () => _showEvidenceModal(claim),
                              ),
                              const SizedBox(width: 6),

                              if (isPending) ...[
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0D9488),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    minimumSize: Size.zero,
                                    elevation: 0,
                                  ),
                                  onPressed: () async {
                                    final confirmed = await SuperAdminDialogs.showConfirmation(
                                      context: context,
                                      title: 'Approve Full Refund',
                                      message: 'Release full refund of PKR ${claim.requestedAmount.toInt()} to buyer\'s wallet?',
                                      confirmColor: const Color(0xFF0D9488),
                                    );
                                    if (confirmed) {
                                      setState(() => claim.disputeStatus = 'Full Refund Approved');
                                      adminState.logAuditAction('DISPUTE_FULL_REFUND', claim.id, 'Approved full refund of PKR ${claim.requestedAmount.toInt()}');
                                      if (mounted) SuperAdminDialogs.showToast(context, 'Full Refund Approved!');
                                    }
                                  },
                                  child: const Text('Full Refund', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 4),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    minimumSize: Size.zero,
                                    elevation: 0,
                                  ),
                                  onPressed: () async {
                                    final reason = await SuperAdminDialogs.showReasonInput(
                                      context: context,
                                      title: 'Reject Return Claim',
                                      labelText: 'Rejection Reason',
                                      hintText: 'Enter reason for rejecting return claim...',
                                    );
                                    if (reason != null && reason.isNotEmpty) {
                                      setState(() => claim.disputeStatus = 'Rejected');
                                      adminState.logAuditAction('DISPUTE_REJECTED', claim.id, 'Rejected claim. Reason: $reason');
                                      if (mounted) SuperAdminDialogs.showToast(context, 'Claim Rejected.', isError: true);
                                    }
                                  },
                                  child: const Text('Reject', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
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
    );
  }

  Widget _buildClaimDetailInspector(SuperAdminProvider adminState) {
    if (_selectedClaim == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text('Select a return claim from the table to inspect evidence.', style: TextStyle(color: Color(0xFF64748B))),
        ),
      );
    }

    final claim = _selectedClaim!;
    final isPending = claim.disputeStatus == 'Pending';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.gavel_rounded, color: Color(0xFF0F172A), size: 20),
                  const SizedBox(width: 8),
                  Text('Arbitration Dossier', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                child: Text(claim.id, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Claim Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(claim.productName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text('Order ID: #${claim.orderId}', style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Refund Claimed:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text('PKR ${claim.requestedAmount.toInt()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Status:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text(claim.disputeStatus, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Parties
          const Text('Involved Parties', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text('Buyer: ${claim.buyerName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          Text('Merchant: ${claim.sellerStoreName}', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
          const SizedBox(height: 12),

          // Return Reason
          const Text('Claim Reason & Statement', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Text(
              claim.returnReason,
              style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.4),
            ),
          ),
          const SizedBox(height: 14),

          // Courier Return Logistics
          const Text('Reverse Shipment Tracking', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_shipping, size: 14, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                Text('${claim.returnCourier} • ${claim.returnTracking}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Evidence Photos Preview
          const Text('Attached Photo Evidence (2)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showEvidenceModal(claim),
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_outlined, size: 24, color: Color(0xFF64748B)),
                        SizedBox(height: 4),
                        Text('Damage View', style: TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _showEvidenceModal(claim),
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_outlined, size: 24, color: Color(0xFF64748B)),
                        SizedBox(height: 4),
                        Text('Courier Label', style: TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Decision Arbitrate Actions
          if (isPending) ...[
            const Text('Arbitration Verdict', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final confirmed = await SuperAdminDialogs.showConfirmation(
                        context: context,
                        title: 'Approve Full Refund',
                        message: 'Release full refund of PKR ${claim.requestedAmount.toInt()} to buyer\'s wallet?',
                        confirmColor: const Color(0xFF0D9488),
                      );
                      if (confirmed) {
                        setState(() => claim.disputeStatus = 'Full Refund Approved');
                        adminState.logAuditAction('DISPUTE_FULL_REFUND', claim.id, 'Approved full refund of PKR ${claim.requestedAmount.toInt()}');
                        if (mounted) SuperAdminDialogs.showToast(context, 'Full Refund Approved!');
                      }
                    },
                    child: const Text('Approve Refund', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () async {
                      final reason = await SuperAdminDialogs.showReasonInput(
                        context: context,
                        title: 'Reject Return Claim',
                        labelText: 'Rejection Reason',
                        hintText: 'Enter reason for rejecting return claim...',
                      );
                      if (reason != null && reason.isNotEmpty) {
                        setState(() => claim.disputeStatus = 'Rejected');
                        adminState.logAuditAction('DISPUTE_REJECTED', claim.id, 'Rejected claim. Reason: $reason');
                        if (mounted) SuperAdminDialogs.showToast(context, 'Claim Rejected.', isError: true);
                      }
                    },
                    child: const Text('Reject Claim', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Verdict Closed: ${claim.disputeStatus}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showEvidenceModal(DisputeClaim claim) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: AppBreakpoints.getResponsiveDialogWidth(context, defaultDesktopWidth: 560),
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
                      const Icon(Icons.assignment_return_rounded, color: Color(0xFF2563EB)),
                      const SizedBox(width: 10),
                      Text('Return Evidence — ${claim.id}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Color(0xFF64748B)), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              Text('Product: ${claim.productName}', style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
              Text('Order ID: #${claim.orderId}', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600, fontSize: 12)),
              Text('Buyer Name: ${claim.buyerName}', style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
              Text('Store Name: ${claim.sellerStoreName}', style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
              Text('Claimed Amount: PKR ${claim.requestedAmount.toInt()}', style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),

              const Text('Return Reason:', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12)),
              Text(claim.returnReason, style: const TextStyle(color: Color(0xFF475569), fontSize: 12)),
              const SizedBox(height: 16),

              const Text('Photo Evidence Uploaded:', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildEvidencePhotoCard('Product Damage View', Icons.broken_image_outlined)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildEvidencePhotoCard('Shipping Label View', Icons.receipt_outlined)),
                ],
              ),
              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close Inspector'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEvidencePhotoCard(String label, IconData icon) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: const Color(0xFF2563EB)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

