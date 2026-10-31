import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';
import '../../../../core/services/app_state_provider.dart';

class PaymentTransaction {
  final String id;
  final String orderId;
  final String customerName;
  final String customerPhone;
  final String paymentMethod;
  final double amount;
  final double gatewayFee;
  final String gatewayRef;
  final String status;
  final DateTime date;

  PaymentTransaction({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.customerPhone,
    required this.paymentMethod,
    required this.amount,
    required this.gatewayFee,
    required this.gatewayRef,
    required this.status,
    required this.date,
  });
}

class PayoutLedgerScreen extends StatefulWidget {
  final int initialTabIndex;
  const PayoutLedgerScreen({super.key, this.initialTabIndex = 0});

  @override
  State<PayoutLedgerScreen> createState() => _PayoutLedgerScreenState();
}

class _PayoutLedgerScreenState extends State<PayoutLedgerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  PaymentTransaction? _selectedTxn;
  AppStore? _selectedStore;

  final List<PaymentTransaction> _paymentTxns = [
    PaymentTransaction(
      id: 'TXN-LEDGER-01',
      orderId: 'ORD-9912',
      customerName: 'Muhammad Ahmed',
      customerPhone: '+92 300 1234567',
      paymentMethod: 'EasyPaisa Mobile Wallet',
      amount: 3500.0,
      gatewayFee: 52.5,
      gatewayRef: 'EP-994821034',
      status: 'Success',
      date: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    PaymentTransaction(
      id: 'TXN-LEDGER-02',
      orderId: 'ORD-8820',
      customerName: 'Fatima Malik',
      customerPhone: '+92 321 9876543',
      paymentMethod: 'JazzCash Direct Checkout',
      amount: 5200.0,
      gatewayFee: 78.0,
      gatewayRef: 'JC-883920194',
      status: 'Success',
      date: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    PaymentTransaction(
      id: 'TXN-LEDGER-03',
      orderId: 'ORD-7741',
      customerName: 'Bilal Khan',
      customerPhone: '+92 333 4455667',
      paymentMethod: 'Visa Debit Card ****4242',
      amount: 1800.0,
      gatewayFee: 36.0,
      gatewayRef: 'STRIPE-CH-772910',
      status: 'Refunded',
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
    PaymentTransaction(
      id: 'TXN-LEDGER-04',
      orderId: 'ORD-6611',
      customerName: 'Zainab Bibi',
      customerPhone: '+92 345 8899001',
      paymentMethod: 'Cash On Delivery (COD)',
      amount: 2100.0,
      gatewayFee: 0.0,
      gatewayRef: 'COD-TCS-6611',
      status: 'Settled to Seller',
      date: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          _selectedFilter = 'All';
          _searchQuery = '';
          _searchController.clear();
        });
      }
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
    final appState = Provider.of<AppStateProvider>(context);
    final adminState = Provider.of<SuperAdminProvider>(context);
    final isPayoutsTab = _tabController.index == 1;

    // Filter Stores for Payout Table
    final stores = appState.stores.where((s) {
      final name = s.shopName.toLowerCase();
      final owner = (s.fullName ?? s.businessName ?? '').toLowerCase();

      final matchesSearch = name.contains(_searchQuery.toLowerCase()) || owner.contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      if (_selectedFilter == 'Pending Payout') return s.pendingPayout > 0;
      if (_selectedFilter == 'Completed Payout') return s.lastPayout > 0;
      return true;
    }).toList();

    // Filter Payments for Gateway Table
    final txns = _paymentTxns.where((t) {
      final matchesSearch = t.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.orderId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.paymentMethod.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      if (_selectedFilter == 'Success') return t.status == 'Success';
      if (_selectedFilter == 'Refunded') return t.status == 'Refunded';
      if (_selectedFilter == 'Settled') return t.status.contains('Settled');
      return true;
    }).toList();

    // Auto-select first items
    if (!isPayoutsTab) {
      if (_selectedTxn == null && txns.isNotEmpty) _selectedTxn = txns.first;
    } else {
      if (_selectedStore == null && stores.isNotEmpty) _selectedStore = stores.first;
    }

    final double totalPendingPayouts = appState.stores.fold(0.0, (sum, s) => sum + s.pendingPayout);
    final isWide = MediaQuery.of(context).size.width > 1050;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb & Page Header
          Text(
            'Breadcrumbs > Finance > ${isPayoutsTab ? "Seller Payouts" : "Customer Payments"}',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPayoutsTab ? 'Payouts & Settlement Ledger' : 'Customer Payments & Gateway Logs',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      final label = isPayoutsTab ? 'Seller Payouts Ledger' : 'Customer Payment Gateway Logs';
                      SuperAdminDialogs.showToast(context, 'Exporting $label to CSV...');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text(isPayoutsTab ? 'Export Payouts' : 'Export Payment Logs', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (isPayoutsTab) {
                        final confirmed = await SuperAdminDialogs.showConfirmation(
                          context: context,
                          title: 'Batch Settlement Disbursement',
                          message: 'Disburse all pending merchant payouts totaling PKR ${totalPendingPayouts.toInt()}?',
                          confirmColor: const Color(0xFF10B981),
                        );
                        if (confirmed) {
                          for (var s in appState.stores) {
                            if (s.pendingPayout > 0) {
                              s.lastPayout += s.pendingPayout;
                              s.pendingPayout = 0.0;
                            }
                          }
                          adminState.logAuditAction('BATCH_PAYOUT', 'All Merchants', 'Batch disbursed PKR ${totalPendingPayouts.toInt()}');
                          if (mounted) SuperAdminDialogs.showToast(context, 'All Batch Payouts Disbursed Successfully!');
                          setState(() {});
                        }
                      } else {
                        SuperAdminDialogs.showToast(context, 'Reconciling EasyPaisa, JazzCash & Stripe Gateway logs... (100% matched)');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPayoutsTab ? const Color(0xFF10B981) : const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text(isPayoutsTab ? 'Batch Settlement' : 'Reconcile Gateway', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4 Financial KPI Cards
          _buildFinancialKpiCards(isPayoutsTab, totalPendingPayouts),
          const SizedBox(height: 16),

          // Sub-Tabs Navigation (Payments vs Payouts)
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
                Tab(icon: Icon(Icons.payment_outlined, size: 18), text: 'Customer Payments & Gateway Logs'),
                Tab(icon: Icon(Icons.account_balance_wallet_outlined, size: 18), text: 'Seller Payouts & Settlement Ledger'),
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
                    decoration: InputDecoration(
                      hintText: isPayoutsTab ? 'Search by Store Name, Owner Name...' : 'Search by Txn ID, Order ID, Customer, Method...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: (isPayoutsTab ? ['All', 'Pending Payout', 'Completed Payout'] : ['All', 'Success', 'Refunded', 'Settled']).map((filter) {
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
                Expanded(flex: 7, child: isPayoutsTab ? _buildPayoutsTable(stores, adminState) : _buildPaymentsTable(txns)),
                const SizedBox(width: 16),
                Expanded(flex: 3, child: isPayoutsTab ? _buildPayoutInspector(adminState) : _buildPaymentInspector()),
              ],
            )
          else
            Column(
              children: [
                isPayoutsTab ? _buildPayoutsTable(stores, adminState) : _buildPaymentsTable(txns),
                const SizedBox(height: 16),
                isPayoutsTab ? _buildPayoutInspector(adminState) : _buildPaymentInspector(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFinancialKpiCards(bool isPayoutsTab, double totalPendingPayouts) {
    if (isPayoutsTab) {
      return Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              title: 'Pending Payout Queue',
              value: 'PKR ${totalPendingPayouts.toInt()}',
              subtitle: 'Awaiting Bank Transfer',
              icon: Icons.hourglass_bottom_rounded,
              iconColor: const Color(0xFFD97706),
              bgColor: const Color(0xFFFEF3C7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              title: 'Disbursed This Month',
              value: 'PKR 345.5k',
              subtitle: 'Settled to Merchants',
              icon: Icons.check_circle_outline_rounded,
              iconColor: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              title: 'Escrow Reserve',
              value: 'PKR 520.0k',
              subtitle: 'Secured Balance',
              icon: Icons.shield_outlined,
              iconColor: const Color(0xFF2563EB),
              bgColor: const Color(0xFFEFF6FF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              title: 'Active Merchants',
              value: '4 Stores',
              subtitle: 'KYC Verified',
              icon: Icons.store_outlined,
              iconColor: const Color(0xFF7C3AED),
              bgColor: const Color(0xFFF3E8FF),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Processed Volume',
            value: 'PKR 126.8k',
            subtitle: 'Gross Inflow',
            icon: Icons.account_balance_wallet_outlined,
            iconColor: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'EasyPaisa & JazzCash',
            value: 'PKR 64.5k',
            subtitle: '51% of Digital Volume',
            icon: Icons.phone_android_rounded,
            iconColor: const Color(0xFF10B981),
            bgColor: const Color(0xFFECFDF5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'Cards & Online',
            value: 'PKR 38.2k',
            subtitle: 'Visa / Mastercard',
            icon: Icons.credit_card_rounded,
            iconColor: const Color(0xFF7C3AED),
            bgColor: const Color(0xFFF3E8FF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            title: 'Gateway Success',
            value: '99.4%',
            subtitle: 'Near Zero Failures',
            icon: Icons.verified_outlined,
            iconColor: const Color(0xFF059669),
            bgColor: const Color(0xFFECFDF5),
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

  // --- TAB 1: CUSTOMER PAYMENTS TABLE ---
  Widget _buildPaymentsTable(List<PaymentTransaction> txns) {
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
                  Expanded(flex: 2, child: Text('Txn ID & Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 3, child: Text('Payment Gateway Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Amount (Rs.)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Gateway Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            ...txns.map((txn) {
              final isSelected = _selectedTxn?.id == txn.id;
              final isSuccess = txn.status == 'Success';
              final isRefunded = txn.status == 'Refunded';

              return InkWell(
                onTap: () => setState(() => _selectedTxn = txn),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: isSelected ? 1.5 : 1),
                  ),
                  child: Row(
                    children: [
                      // Txn ID
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(txn.id, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), fontSize: 13)),
                            const SizedBox(height: 2),
                            Text('#${txn.orderId}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),

                      // Customer
                      Expanded(
                        flex: 2,
                        child: Text(txn.customerName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 12)),
                      ),

                      // Method
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Icon(
                              txn.paymentMethod.contains('EasyPaisa')
                                  ? Icons.account_balance_wallet
                                  : (txn.paymentMethod.contains('JazzCash') ? Icons.phone_android : (txn.paymentMethod.contains('COD') ? Icons.local_shipping : Icons.credit_card)),
                              size: 16,
                              color: const Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(txn.paymentMethod, style: const TextStyle(color: Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),

                      // Amount
                      Expanded(
                        flex: 2,
                        child: Text('Rs. ${txn.amount.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
                      ),

                      // Status
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSuccess ? const Color(0xFFECFDF5) : (isRefunded ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            txn.status,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSuccess ? const Color(0xFF059669) : (isRefunded ? const Color(0xFFD97706) : const Color(0xFF2563EB)),
                            ),
                          ),
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

  // --- TAB 2: SELLER PAYOUTS TABLE ---
  Widget _buildPayoutsTable(List<AppStore> stores, SuperAdminProvider adminState) {
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
                  Expanded(flex: 3, child: Text('Merchant Store & Owner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Pending Payout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Last Disbursed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Bank Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                  Expanded(flex: 2, child: Text('Payout Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569)))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            ...stores.map((store) {
              final isSelected = _selectedStore?.id == store.id;
              final owner = store.fullName ?? store.businessName ?? 'Merchant';

              return InkWell(
                onTap: () => setState(() => _selectedStore = store),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: isSelected ? 1.5 : 1),
                  ),
                  child: Row(
                    children: [
                      // Store Name
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(store.shopName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(owner, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),

                      // Pending
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Rs. ${store.pendingPayout.toInt()}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: store.pendingPayout > 0 ? const Color(0xFFB45309) : const Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                      ),

                      // Last Disbursed
                      Expanded(
                        flex: 2,
                        child: Text('Rs. ${store.lastPayout.toInt()}', style: const TextStyle(color: Color(0xFF059669), fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                      // IBAN Modal Button
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.account_balance, size: 13),
                          label: const Text('IBAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          onPressed: () => _showBankDetailsModal(store),
                        ),
                      ),

                      // Action
                      Expanded(
                        flex: 2,
                        child: store.pendingPayout > 0
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  minimumSize: Size.zero,
                                  elevation: 0,
                                ),
                                onPressed: () async {
                                  final confirmed = await SuperAdminDialogs.showConfirmation(
                                    context: context,
                                    title: 'Approve Merchant Payout',
                                    message: 'Approve settlement payout of Rs. ${store.pendingPayout.toInt()} for ${store.shopName}?',
                                    confirmColor: const Color(0xFF10B981),
                                  );
                                  if (confirmed) {
                                    store.lastPayout += store.pendingPayout;
                                    store.pendingPayout = 0.0;
                                    adminState.logAuditAction('PAYOUT_DISBURSEMENT', store.shopName, 'Disbursed payout of Rs. ${store.lastPayout.toInt()}');
                                    if (mounted) SuperAdminDialogs.showToast(context, 'Payout Disbursed!');
                                    setState(() {});
                                  }
                                },
                                child: const Text('Approve Payout', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              )
                            : const Text('Settled', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 12)),
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

  // --- RIGHT DRAWER 1: PAYMENT GATEWAY INSPECTOR ---
  Widget _buildPaymentInspector() {
    if (_selectedTxn == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: const Center(child: Text('Select a transaction to inspect gateway log.', style: TextStyle(color: Color(0xFF64748B)))),
      );
    }

    final txn = _selectedTxn!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: Color(0xFF0F172A), size: 20),
                  SizedBox(width: 8),
                  Text('Gateway Receipt', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                child: Text(txn.id, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn.paymentMethod, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 4),
                Text('Order Ref: #${txn.orderId}', style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Gross Paid:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text('PKR ${txn.amount.toInt()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Gateway Processing Fee:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text('PKR ${txn.gatewayFee.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Text('Buyer Identity', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(txn.customerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          Text(txn.customerPhone, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
          const SizedBox(height: 12),

          const Text('Gateway RRN / Transaction Ref', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
            child: Text(txn.gatewayRef, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            icon: const Icon(Icons.print_outlined, size: 14),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 38)),
            onPressed: () => SuperAdminDialogs.showToast(context, 'Printing gateway receipt for ${txn.id}...'),
            label: const Text('Print Gateway Slip', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- RIGHT DRAWER 2: SELLER PAYOUT INSPECTOR ---
  Widget _buildPayoutInspector(SuperAdminProvider adminState) {
    if (_selectedStore == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: const Center(child: Text('Select a store to view settlement details.', style: TextStyle(color: Color(0xFF64748B)))),
      );
    }

    final store = _selectedStore!;
    final owner = store.fullName ?? store.businessName ?? 'Merchant';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF0F172A), size: 20),
                  SizedBox(width: 8),
                  Text('Settlement Dossier', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                child: const Text('VERIFIED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Payout Balance Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(store.shopName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text('Owner: $owner', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pending Settlement:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text('PKR ${store.pendingPayout.toInt()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Disbursed:', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    Text('PKR ${store.lastPayout.toInt()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bank Details
          const Text('Verified Bank Account', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(owner, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const Text('Meezan Bank Limited • Main Gulberg Branch', style: TextStyle(fontSize: 11, color: Color(0xFF475569))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
            child: const Text('PK36MEZN0001928374659102', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
          ),
          const SizedBox(height: 20),

          if (store.pendingPayout > 0)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 38)),
              onPressed: () async {
                final confirmed = await SuperAdminDialogs.showConfirmation(
                  context: context,
                  title: 'Approve Merchant Payout',
                  message: 'Approve settlement payout of Rs. ${store.pendingPayout.toInt()} for ${store.shopName}?',
                  confirmColor: const Color(0xFF10B981),
                );
                if (confirmed) {
                  store.lastPayout += store.pendingPayout;
                  store.pendingPayout = 0.0;
                  adminState.logAuditAction('PAYOUT_DISBURSEMENT', store.shopName, 'Disbursed payout of Rs. ${store.lastPayout.toInt()}');
                  if (mounted) SuperAdminDialogs.showToast(context, 'Payout Disbursed!');
                  setState(() {});
                }
              },
              child: const Text('Disburse Payout Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
              child: const Text('All Balance Settled to Bank', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
            ),
        ],
      ),
    );
  }

  void _showBankDetailsModal(AppStore store) {
    final owner = store.fullName ?? store.businessName ?? 'Merchant';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.account_balance, color: Color(0xFF2563EB), size: 20),
            const SizedBox(width: 8),
            Text('Bank Account — ${store.shopName}', style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Account Title', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            Text(owner, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 10),
            const Text('Bank Name & Branch', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const Text('Meezan Bank Limited • Main Gulberg Branch, Lahore', style: TextStyle(color: Color(0xFF334155), fontSize: 12)),
            const SizedBox(height: 10),
            const Text('Verified IBAN', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
              child: const Text('PK36MEZN0001928374659102', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
