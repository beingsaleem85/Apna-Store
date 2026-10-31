import 'package:flutter/material.dart';
import '../../../../core/services/supabase_finance_service.dart';

class WalletTransaction {
  final String orderId;
  final String date;
  final double grossAmount;
  final double commissionFee;
  final double netPayout;
  final String status;

  WalletTransaction({
    required this.orderId,
    required this.date,
    required this.grossAmount,
    required this.commissionFee,
    required this.netPayout,
    required this.status,
  });
}

class SellerWalletPayoutScreen extends StatefulWidget {
  const SellerWalletPayoutScreen({super.key});

  @override
  State<SellerWalletPayoutScreen> createState() => _SellerWalletPayoutScreenState();
}

class _SellerWalletPayoutScreenState extends State<SellerWalletPayoutScreen> {
  final SupabaseFinanceService _financeService = SupabaseFinanceService();
  bool _isLoading = true;
  SellerWalletSummary? _summary;
  List<WalletTxnRecord> _ledgerTxns = [];
  bool _isSubmittingPayout = false;

  @override
  void initState() {
    super.initState();
    _loadFinanceData();
  }

  Future<void> _loadFinanceData() async {
    setState(() => _isLoading = true);
    final summary = await _financeService.fetchSellerWalletSummary();
    final txns = await _financeService.fetchWalletTransactions();

    if (mounted) {
      setState(() {
        _summary = summary;
        _ledgerTxns = txns;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double available = _summary?.availableBalance ?? 0.0;
    final double pending = _summary?.pendingBalance ?? 0.0;
    final double paidOut = _summary?.paidOutTotal ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchant Wallet & Tax Invoicing'),
        backgroundColor: const Color(0xFF004D40),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFinanceData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF004D40)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wallet Summary Card Row (Derived from Append-Only Ledger)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 600;
                      if (isNarrow) {
                        return Column(
                          children: [
                            _buildWalletCard('Available Payable Balance', 'Rs. ${available.toStringAsFixed(0)}', 'Ready for Instant Transfer', const Color(0xFF004D40)),
                            const SizedBox(height: 12),
                            _buildWalletCard('Pending Escrow Reserve', 'Rs. ${pending.toStringAsFixed(0)}', '7-Day Return Lock Period', Colors.amber.shade800),
                            const SizedBox(height: 12),
                            _buildWalletCard('Lifetime Earnings Paid', 'Rs. ${paidOut.toStringAsFixed(0)}', 'Verified Settlements', Colors.indigo),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          _buildWalletCard('Available Payable Balance', 'Rs. ${available.toStringAsFixed(0)}', 'Ready for Instant Transfer', const Color(0xFF004D40)),
                          const SizedBox(width: 12),
                          _buildWalletCard('Pending Escrow Reserve', 'Rs. ${pending.toStringAsFixed(0)}', '7-Day Return Lock Period', Colors.amber.shade800),
                          const SizedBox(width: 12),
                          _buildWalletCard('Lifetime Earnings Paid', 'Rs. ${paidOut.toStringAsFixed(0)}', 'Verified Settlements', Colors.indigo),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Payout Actions & Tax Downloads
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.account_balance_wallet),
                        label: const Text('Request Instant Payout to Bank Account'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004D40),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                        onPressed: available > 0 ? () => _showWithdrawalModal(available) : null,
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Download FBR Tax NTN Withholding Certificate'),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Downloading FBR Tax NTN Certificate PDF...')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Transactions History Table
                  const Text('Recent Order Settlements & Commission Ledger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: _ledgerTxns.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(child: Text('No wallet transactions recorded yet.', style: TextStyle(color: Colors.grey))),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _ledgerTxns.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final t = _ledgerTxns[index];
                              final isCredit = t.transactionType == 'CREDIT';

                              return ListTile(
                                leading: Icon(
                                  isCredit ? Icons.check_circle : Icons.hourglass_top,
                                  color: isCredit ? Colors.green : Colors.orange,
                                ),
                                title: Text('${t.sourceType} — Rs. ${t.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('${t.description} | ${t.createdAt.toString().split('.')[0]}', style: const TextStyle(fontSize: 11)),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${isCredit ? "+" : "-"} Rs. ${t.amount.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: isCredit ? Colors.green : Colors.red, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text(t.transactionType, style: TextStyle(fontSize: 10, color: isCredit ? Colors.green : Colors.orange)),
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

  Widget _buildWalletCard(String title, String val, String sub, Color color) {
    return Expanded(
      child: Card(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text(sub, style: const TextStyle(fontSize: 10, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  void _showWithdrawalModal(double maxAvailable) async {
    final amountController = TextEditingController(text: maxAvailable.toStringAsFixed(0));

    try {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Instant Bank Payout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bank Name: Meezan Bank Ltd', style: TextStyle(fontWeight: FontWeight.bold)),
              const Text('Account IBAN: PK36 MEZN 0001 0203 0405 0607'),
              const SizedBox(height: 12),
              Text('Available Amount: Rs. ${maxAvailable.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF004D40), fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Payout Amount (PKR)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
              onPressed: _isSubmittingPayout
                  ? null
                  : () async {
                      final reqAmt = double.tryParse(amountController.text.trim()) ?? 0.0;
                      if (reqAmt <= 0 || reqAmt > maxAvailable) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid payout amount.')));
                        return;
                      }

                      Navigator.pop(ctx);
                      if (mounted) setState(() => _isSubmittingPayout = true);

                      final key = 'PAYOUT-REQ-${DateTime.now().millisecondsSinceEpoch}';
                      final res = await _financeService.requestPayout(amount: reqAmt, idempotencyKey: key);

                      if (mounted) {
                        setState(() => _isSubmittingPayout = false);
                        if (res['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Payout Request Submitted! ID: ${res['payout_id']}')),
                          );
                          _loadFinanceData();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Payout Error: ${res['message']}')),
                          );
                        }
                      }
                    },
              child: const Text('Submit Payout Request'),
            ),
          ],
        ),
      );
    } finally {
      amountController.dispose();
    }
  }
}
