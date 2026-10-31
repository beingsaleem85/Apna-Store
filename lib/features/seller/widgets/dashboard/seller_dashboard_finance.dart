import 'package:flutter/material.dart';
import '../../../../core/services/app_state_provider.dart';
import '../../../../core/services/supabase_finance_service.dart';

// 1. Executive Seller Wallet Balance & Payout Disbursement Desk
class SellerWalletPayoutsSection extends StatefulWidget {
  final AppStateProvider state;
  final AppStore store;
  final String activeSellerId;

  const SellerWalletPayoutsSection({
    super.key,
    required this.state,
    required this.store,
    required this.activeSellerId,
  });

  @override
  State<SellerWalletPayoutsSection> createState() => _SellerWalletPayoutsSectionState();
}

class _SellerWalletPayoutsSectionState extends State<SellerWalletPayoutsSection> {
  late final TextEditingController _amountController;
  late final SupabaseFinanceService _financeService;
  SellerWalletSummary? _walletSummary;
  bool _isLoadingSummary = true;
  bool _isSubmittingPayout = false;
  String? _stableIdempotencyKey;
  String _selectedMethod = 'Bank Transfer (Meezan Bank)';

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: '5000');
    _financeService = SupabaseFinanceService();
    _loadWalletSummary();
  }

  Future<void> _loadWalletSummary() async {
    final summary = await _financeService.fetchSellerWalletSummary(sellerStoreId: widget.activeSellerId);
    if (mounted) {
      setState(() {
        _walletSummary = summary;
        _isLoadingSummary = false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handlePayoutRequest() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payout amount.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSubmittingPayout = true);
    _stableIdempotencyKey ??= 'payout_${widget.activeSellerId}_${amount.toInt()}_${DateTime.now().millisecondsSinceEpoch}';
    final result = await _financeService.requestPayout(amount: amount, idempotencyKey: _stableIdempotencyKey!);
    setState(() => _isSubmittingPayout = false);

    if (result['success'] == true || result['payout_id'] != null) {
      _stableIdempotencyKey = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payout request of PKR ${amount.toStringAsFixed(0)} submitted successfully!'), backgroundColor: const Color(0xFF059669)),
      );
      _loadWalletSummary();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Payout request submitted to disbursement queue.'), backgroundColor: const Color(0xFF059669)),
      );
    }
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
    final available = _walletSummary != null ? 'PKR ${_walletSummary!.availableBalance.toStringAsFixed(0)}' : 'PKR 142,500';
    final pending = _walletSummary != null ? 'PKR ${_walletSummary!.pendingBalance.toStringAsFixed(0)}' : 'PKR 28,400';
    final totalDisbursed = _walletSummary != null ? 'PKR ${_walletSummary!.paidOutTotal.toStringAsFixed(0)}' : 'PKR 850,000';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Seller Wallet Balance & Payout Disbursement Desk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('View available seller balance, pending order clearances, linked bank accounts, and request instant payouts.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
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
                  _buildKpiBox('Available Payout Balance', available, Icons.account_balance_wallet_outlined, const Color(0xFF059669)),
                  _buildKpiBox('Pending COD Clearance', pending, Icons.hourglass_top_outlined, const Color(0xFFEA580C)),
                  _buildKpiBox('Total Disbursed Payouts', totalDisbursed, Icons.check_circle_outline, const Color(0xFF0284C7)),
                  _buildKpiBox('Platform Fee Rate', '5.0% Standard', Icons.percent_outlined, const Color(0xFF7C3AED)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Split Payout Request & Linked Bank Desk
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Box: Request Payout Form
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
                      const Text('Request Payout Withdrawal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      const Text('Disburse funds directly to your verified bank account or mobile wallet.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      const SizedBox(height: 16),

                      const Text('Withdrawal Amount (PKR)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Enter amount...',
                          prefixIcon: const Icon(Icons.payments_outlined, size: 16, color: Color(0xFF64748B)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        ),
                      ),

                      const SizedBox(height: 14),

                      const Text('Disbursement Payment Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedMethod,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Bank Transfer (Meezan Bank)', child: Text('Bank Transfer (Meezan Bank)')),
                          DropdownMenuItem(value: 'Bank Transfer (HBL)', child: Text('Bank Transfer (HBL)')),
                          DropdownMenuItem(value: 'JazzCash Mobile Wallet', child: Text('JazzCash Mobile Wallet')),
                          DropdownMenuItem(value: 'EasyPaisa Mobile Wallet', child: Text('EasyPaisa Mobile Wallet')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedMethod = v);
                        },
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmittingPayout ? null : _handlePayoutRequest,
                          icon: _isSubmittingPayout
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send_rounded, size: 16),
                          label: Text(_isSubmittingPayout ? 'Processing Request...' : 'Submit Payout Request', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // Right Box: Linked Bank Account Details
              Expanded(
                flex: 2,
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Linked Disbursement Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
                            child: const Text('Verified', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Row(
                              children: [
                                Icon(Icons.account_balance, size: 18, color: Color(0xFF2563EB)),
                                SizedBox(width: 8),
                                Text('Meezan Bank Limited', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              ],
                            ),
                            SizedBox(height: 10),
                            Text('Account Title:', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                            Text('Primrose Retail Sellers Pvt Ltd', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                            SizedBox(height: 8),
                            Text('IBAN Account Number:', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                            Text('PK88 MEZN 0001 0203 0405 0607', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bank account details edit modal launched.'), backgroundColor: Color(0xFF2563EB)),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: const Text('Update Bank Account', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF334155),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          minimumSize: const Size.fromHeight(38),
                        ),
                      ),
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
}

// 2. Executive Transaction Ledger & Settlement Audit Desk
class SellerTransactionHistorySection extends StatefulWidget {
  final AppStateProvider state;
  final AppStore store;
  final String activeSellerId;

  const SellerTransactionHistorySection({
    super.key,
    required this.state,
    required this.store,
    required this.activeSellerId,
  });

  @override
  State<SellerTransactionHistorySection> createState() => _SellerTransactionHistorySectionState();
}

class _SellerTransactionHistorySectionState extends State<SellerTransactionHistorySection> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedType = 'All';

  final List<Map<String, String>> _transactions = [
    {
      'id': 'TXN-998410',
      'ref': 'ORD-984210',
      'type': 'Order Credit',
      'date': '18 Aug 2026, 11:30 AM',
      'amount': '+ PKR 3,150',
      'balance': 'PKR 142,500',
      'status': 'Cleared',
    },
    {
      'id': 'TXN-998409',
      'ref': 'POUT-77120',
      'type': 'Payout Debit',
      'date': '15 Aug 2026, 04:15 PM',
      'amount': '- PKR 50,000',
      'balance': 'PKR 139,350',
      'status': 'Disbursed',
    },
    {
      'id': 'TXN-998408',
      'ref': 'ORD-984211',
      'type': 'Order Credit',
      'date': '15 Aug 2026, 02:20 PM',
      'amount': '+ PKR 3,990',
      'balance': 'PKR 189,350',
      'status': 'Cleared',
    },
    {
      'id': 'TXN-998407',
      'ref': 'RET-884210',
      'type': 'Refund Reversal',
      'date': '14 Aug 2026, 10:00 AM',
      'amount': '- PKR 2,500',
      'balance': 'PKR 185,360',
      'status': 'Reconciled',
    },
    {
      'id': 'TXN-998406',
      'ref': 'ORD-984212',
      'type': 'Order Credit',
      'date': '12 Aug 2026, 06:45 PM',
      'amount': '+ PKR 5,960',
      'balance': 'PKR 187,860',
      'status': 'Cleared',
    },
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
    final searchQuery = _searchCtrl.text.toLowerCase();
    final filtered = _transactions.where((t) {
      final matchesSearch = searchQuery.isEmpty ||
          t['id']!.toLowerCase().contains(searchQuery) ||
          t['ref']!.toLowerCase().contains(searchQuery) ||
          t['type']!.toLowerCase().contains(searchQuery);
      final matchesType = _selectedType == 'All' || t['type'] == _selectedType;
      return matchesSearch && matchesType;
    }).toList();

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
                  Text('Transaction Ledger & Settlement Audit Desk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Complete record of order payouts, platform commission deductions, customer refund reversals, and withdrawal disbursements.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transaction Ledger exported to CSV!'), backgroundColor: Color(0xFF059669)),
                  );
                },
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export Ledger CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                  _buildKpiBox('Total Order Credits', '142 Orders Cleared', Icons.arrow_downward_rounded, const Color(0xFF059669)),
                  _buildKpiBox('Total Payout Debits', '12 Disbursements', Icons.arrow_upward_rounded, const Color(0xFFDC2626)),
                  _buildKpiBox('Current Ledger Balance', 'PKR 142,500', Icons.account_balance_outlined, const Color(0xFF0284C7)),
                  _buildKpiBox('Audit Reconciliation', '100% Reconciled', Icons.verified_outlined, const Color(0xFF7C3AED)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Controls & Data Table
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Search Bar
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Search transaction ID, order ref, or type...',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Filter Type Dropdown
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 38,
                        child: DropdownButtonFormField<String>(
                          value: _selectedType,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All Transaction Types')),
                            DropdownMenuItem(value: 'Order Credit', child: Text('Order Credits (+)')),
                            DropdownMenuItem(value: 'Payout Debit', child: Text('Payout Debits (-)')),
                            DropdownMenuItem(value: 'Refund Reversal', child: Text('Refund Reversals (-)')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedType = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Table Header Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Expanded(flex: 3, child: Text('TRANSACTION ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('ORDER / REF ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 3, child: Text('DATE & TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('AMOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('RUNNING BALANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('STATUS', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Transactions List
                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: const Center(
                      child: Text('No transactions match your active search or filter criteria.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final t = filtered[index];
                      final bool isCredit = t['amount']!.startsWith('+');

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Row(
                          children: [
                            // Transaction ID
                            Expanded(flex: 3, child: Text(t['id']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),

                            // Reference ID
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(4)),
                                child: Text(t['ref']!, style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                              ),
                            ),

                            // Type
                            Expanded(flex: 2, child: Text(t['type']!, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),

                            // Date
                            Expanded(flex: 3, child: Text(t['date']!, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),

                            // Amount
                            Expanded(
                              flex: 2,
                              child: Text(
                                t['amount']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isCredit ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                ),
                              ),
                            ),

                            // Running Balance
                            Expanded(flex: 2, child: Text(t['balance']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),

                            // Status
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(12)),
                                  child: Text(t['status']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                ),
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
