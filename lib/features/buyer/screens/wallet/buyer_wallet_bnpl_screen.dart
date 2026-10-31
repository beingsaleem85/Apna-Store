import 'package:flutter/material.dart';

class BuyerWalletBnplScreen extends StatefulWidget {
  const BuyerWalletBnplScreen({super.key});

  @override
  State<BuyerWalletBnplScreen> createState() => _BuyerWalletBnplScreenState();
}

class _BuyerWalletBnplScreenState extends State<BuyerWalletBnplScreen> {
  final int _availableCash = 4250;
  final int _promoCredit = 1000;
  final TextEditingController _giftCardController = TextEditingController();

  final List<Map<String, dynamic>> _ledgerHistory = [
    {
      'title': 'Instant Refund for Order #PK-8841',
      'date': '18 July 2026',
      'amount': '+ Rs. 3,500',
      'type': 'credit',
      'icon': Icons.replay,
    },
    {
      'title': 'Eid Shopping Promo Cashback',
      'date': '15 July 2026',
      'amount': '+ Rs. 750',
      'type': 'credit',
      'icon': Icons.card_giftcard,
    },
    {
      'title': 'Used at Checkout for Order #PK-7210',
      'date': '10 July 2026',
      'amount': '- Rs. 2,000',
      'type': 'debit',
      'icon': Icons.shopping_bag,
    },
  ];

  @override
  void dispose() {
    _giftCardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int totalBalance = _availableCash + _promoCredit;
    final brandGreen = const Color(0xFF004D40);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer E-Wallet & Refunds Hub'),
        backgroundColor: brandGreen,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // E-Wallet Balance Hero Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [brandGreen, const Color(0xFF00796B)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('ApnaStore Customer Wallet', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Top-Up', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFDB913),
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () => _showTopUpModal(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Rs. $totalBalance', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Text('Refundable Cash: Rs. $_availableCash', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(width: 16),
                          Text('Promo Credits: Rs. $_promoCredit', style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Gift Card Redemption Box
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Redeem Gift Card Voucher', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _giftCardController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter 16-Digit Gift Code',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brandGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                              ),
                              onPressed: () {
                                if (_giftCardController.text.isNotEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Gift Voucher of Rs. 1,000 Redeemed Successfully!')),
                                  );
                                  _giftCardController.clear();
                                }
                              },
                              child: const Text('Claim Code'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Wallet Transaction History Ledger
                const Text('Recent Wallet Activity:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _ledgerHistory.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _ledgerHistory[index];
                    final isCredit = item['type'] == 'credit';

                    return Card(
                      elevation: 1,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCredit ? Colors.green.shade50 : Colors.red.shade50,
                          child: Icon(item['icon'] as IconData, color: isCredit ? Colors.green : Colors.red, size: 20),
                        ),
                        title: Text(item['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        subtitle: Text(item['date'] as String, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        trailing: Text(
                          item['amount'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isCredit ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTopUpModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Top-Up Wallet via JazzCash / EasyPaisa', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Enter Top-Up Amount (Rs.)', border: OutlineInputBorder()),
            ),
            SizedBox(height: 10),
            TextField(
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: 'Mobile Account Number (03XX)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Wallet Top-Up Request Authorized!')),
              );
            },
            child: const Text('Authorize Top-Up'),
          ),
        ],
      ),
    );
  }
}
