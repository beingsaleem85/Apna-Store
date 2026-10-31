import 'package:flutter/material.dart';

class InventoryItem {
  final String sku;
  final String title;
  int lahoreStock;
  int karachiStock;
  int islamabadStock;
  final String batchNo;
  final String expiryDate;
  final String velocityCategory; // 'Fast Moving', 'Slow Moving', 'Dead Stock'

  InventoryItem({
    required this.sku,
    required this.title,
    required this.lahoreStock,
    required this.karachiStock,
    required this.islamabadStock,
    required this.batchNo,
    required this.expiryDate,
    required this.velocityCategory,
  });

  int get totalStock => lahoreStock + karachiStock + islamabadStock;
}

class SellerInventoryManagementScreen extends StatefulWidget {
  const SellerInventoryManagementScreen({super.key});

  @override
  State<SellerInventoryManagementScreen> createState() => _SellerInventoryManagementScreenState();
}

class _SellerInventoryManagementScreenState extends State<SellerInventoryManagementScreen> {
  final List<InventoryItem> _inventory = [
    InventoryItem(
      sku: 'LAWN-2026-BLK',
      title: 'Embroidered Lawn 3-Piece Suit',
      lahoreStock: 120,
      karachiStock: 80,
      islamabadStock: 45,
      batchNo: 'BATCH-L2026',
      expiryDate: 'N/A (Apparel)',
      velocityCategory: 'Fast Moving',
    ),
    InventoryItem(
      sku: 'JKT-LTHR-BRN',
      title: 'Men Leather Jacket Winter Edition',
      lahoreStock: 15,
      karachiStock: 10,
      islamabadStock: 5,
      batchNo: 'BATCH-J2025',
      expiryDate: 'N/A (Apparel)',
      velocityCategory: 'Slow Moving',
    ),
    InventoryItem(
      sku: 'ORG-HONEY-500G',
      title: 'Organic Sidr Honey 500g Glass Jar',
      lahoreStock: 50,
      karachiStock: 30,
      islamabadStock: 20,
      batchNo: 'BATCH-H901',
      expiryDate: '15 Dec 2027',
      velocityCategory: 'Fast Moving',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Warehouse Inventory & Batch Tracker'),
        backgroundColor: const Color(0xFF004D40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warehouse Stock Summary Card
            Card(
              color: const Color(0xFF004D40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Padding(
                padding: EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('Lahore Main Hub', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('185 Units', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Karachi Hub', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('120 Units', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                      ],
                    ),
                    Column(
                      children: [
                        Text('Islamabad Hub', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('70 Units', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Inventory Stock List
            const Text('Product Stock Allocation & Batch Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _inventory.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _inventory[index];
                  final isFast = item.velocityCategory == 'Fast Moving';

                  return ListTile(
                    title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text(
                      'SKU: ${item.sku} | Batch: ${item.batchNo} | Expiry: ${item.expiryDate}\n'
                      'Stock: LHR ${item.lahoreStock} | KHI ${item.karachiStock} | ISB ${item.islamabadStock}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isFast ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.velocityCategory,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isFast ? Colors.green : Colors.orange),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Total: ${item.totalStock} Units', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                    onTap: () => _showStockAdjustmentModal(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStockAdjustmentModal(InventoryItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust Stock — ${item.title}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SKU: ${item.sku}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 12),
            Text('Lahore Stock: ${item.lahoreStock} units'),
            Text('Karachi Stock: ${item.karachiStock} units'),
            Text('Islamabad Stock: ${item.islamabadStock} units'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Transfer 10 Units to Karachi Hub'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
              onPressed: () {
                setState(() {
                  if (item.lahoreStock >= 10) {
                    item.lahoreStock -= 10;
                    item.karachiStock += 10;
                  }
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transferred 10 units from Lahore to Karachi Hub!')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
