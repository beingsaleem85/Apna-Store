import 'package:flutter/material.dart';

class DigitalProduct {
  final String title;
  final String category;
  final int price;
  final IconData icon;
  final String key;
  bool isRevealed;

  DigitalProduct({
    required this.title,
    required this.category,
    required this.price,
    required this.icon,
    required this.key,
    this.isRevealed = false,
  });
}

class BuyerB2bDigitalScreen extends StatefulWidget {
  const BuyerB2bDigitalScreen({super.key});

  @override
  State<BuyerB2bDigitalScreen> createState() => _BuyerB2bDigitalScreenState();
}

class _BuyerB2bDigitalScreenState extends State<BuyerB2bDigitalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _ntnController = TextEditingController();
  final TextEditingController _strnController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '100');

  final List<DigitalProduct> _myDigitalVault = [
    DigitalProduct(
      title: 'Microsoft Office 365 Pro Key',
      category: 'Software License',
      price: 4999,
      icon: Icons.computer,
      key: 'MS365-PK-8849-XXXX-9921',
    ),
    DigitalProduct(
      title: 'Google Play Rs. 2,000 Gift Voucher',
      category: 'Digital Voucher',
      price: 2000,
      icon: Icons.card_giftcard,
      key: 'GPLAY-2000-PK-7741',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyNameController.dispose();
    _ntnController.dispose();
    _strnController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('B2B Corporate & Digital Store'),
        backgroundColor: const Color(0xFF004D40),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFDB913),
          labelColor: Colors.white,
          tabs: const [
            Tab(text: 'B2B Bulk Procurement'),
            Tab(text: 'Digital Products Vault'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: B2B Corporate Bulk Procurement & NTN Tax Desk
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wholesale Volume Tier Calculator Card
                Card(
                  color: Colors.teal.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF004D40))),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.inventory, color: Color(0xFF004D40)),
                            SizedBox(width: 8),
                            Text('Wholesale Volume Tier Pricing Calculator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004D40))),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            _buildTierBox('1 - 10 Units', 'Rs. 3,500 / ea', Colors.grey),
                            const SizedBox(width: 8),
                            _buildTierBox('11 - 50 Units', 'Rs. 3,000 / ea', Colors.blue),
                            const SizedBox(width: 8),
                            _buildTierBox('50+ Units', 'Rs. 2,500 / ea', Colors.green),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Corporate Quote Request Form
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Request Official Corporate Bulk Quote & Tax Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        const Text('Get official FBR tax-compliant Sales Tax Invoice (NTN/STRN).', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const Divider(height: 24),

                        const Text('Company Registered Name:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _companyNameController,
                          decoration: const InputDecoration(hintText: 'e.g. Systems Limited / Packages Corp', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('NTN Number:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _ntnController,
                                    decoration: const InputDecoration(hintText: '7-Digit NTN', border: OutlineInputBorder()),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('STRN Number:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _strnController,
                                    decoration: const InputDecoration(hintText: 'STRN Number', border: OutlineInputBorder()),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        const Text('Bulk Quantity Required:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: 'e.g. 100 Units', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.send),
                            label: const Text('Submit B2B Bulk Quote Request'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF004D40),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('B2B Quote Request Submitted! Corporate Account Manager will contact within 2 hours.')),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab 2: Digital Products Vault & Serial Keys
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Purchased Digital License Keys & Vouchers:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _myDigitalVault.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final d = _myDigitalVault[index];

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFF004D40).withOpacity(0.1),
                                  child: Icon(d.icon, color: const Color(0xFF004D40)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(d.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('${d.category} | Rs. ${d.price}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),

                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    d.isRevealed ? d.key : '••••-••••-••••-••••',
                                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004D40)),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(d.isRevealed ? Icons.visibility_off : Icons.visibility, size: 20),
                                        onPressed: () => setState(() => d.isRevealed = !d.isRevealed),
                                        tooltip: 'Reveal Key',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.copy, size: 20),
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('License Key copied to clipboard!')),
                                          );
                                        },
                                        tooltip: 'Copy Key',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildTierBox(String qty, String price, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(qty, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(price, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
