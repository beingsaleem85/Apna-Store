import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/app_state_provider.dart';

class InventoryProductItem {
  final String id;
  final String sku;
  final String title;
  int stockQuantity;
  final double price;
  final bool isActive;

  InventoryProductItem({
    required this.id,
    required this.sku,
    required this.title,
    required this.stockQuantity,
    required this.price,
    required this.isActive,
  });

  String get velocityCategory {
    if (stockQuantity <= 5) return 'Low Stock';
    if (stockQuantity > 50) return 'In Stock';
    return 'Moderate';
  }
}

class SellerInventoryManagementScreen extends StatefulWidget {
  const SellerInventoryManagementScreen({super.key});

  @override
  State<SellerInventoryManagementScreen> createState() => _SellerInventoryManagementScreenState();
}

class _SellerInventoryManagementScreenState extends State<SellerInventoryManagementScreen> {
  final List<InventoryProductItem> _inventory = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      String? storeId = appState.loggedInSellerId;

      if (storeId == null || storeId.isEmpty) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final res = await Supabase.instance.client
              .from('seller_stores')
              .select('id')
              .eq('owner_id', user.id)
              .maybeSingle();
          if (res != null) {
            storeId = res['id']?.toString();
          }
        }
      }

      if (storeId == null || storeId.isEmpty) {
        // Fallback to active products in AppStateProvider if present
        final providerProducts = appState.products;
        if (providerProducts.isNotEmpty) {
          setState(() {
            _inventory.clear();
            for (final p in providerProducts) {
              _inventory.add(InventoryProductItem(
                id: p.id,
                sku: 'SKU-${p.id.length >= 6 ? p.id.substring(0, 6).toUpperCase() : p.id}',
                title: p.name,
                stockQuantity: p.stock,
                price: double.tryParse(p.price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0,
                isActive: p.approvalStatus == 'Approved',
              ));
            }
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _inventory.clear();
          _isLoading = false;
        });
        return;
      }

      final data = await Supabase.instance.client
          .from('products')
          .select('id, title, sku, stock_quantity, price, is_active')
          .eq('seller_store_id', storeId)
          .order('title', ascending: true);

      if (mounted) {
        setState(() {
          _inventory.clear();
          for (final row in (data as List)) {
            _inventory.add(InventoryProductItem(
              id: row['id'].toString(),
              sku: (row['sku'] ?? 'SKU-${row['id'].toString().substring(0, 6)}').toString(),
              title: (row['title'] ?? 'Untitled Product').toString(),
              stockQuantity: (row['stock_quantity'] as num?)?.toInt() ?? 0,
              price: (row['price'] as num?)?.toDouble() ?? 0.0,
              isActive: row['is_active'] == true,
            ));
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load inventory: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStockOnServer(InventoryProductItem item, int newStock) async {
    if (newStock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock quantity cannot be negative.')),
      );
      return;
    }

    try {
      await Supabase.instance.client.rpc(
        'seller_update_product_stock',
        params: {
          'p_product_id': item.id,
          'p_new_stock': newStock,
        },
      );

      setState(() {
        item.stockQuantity = newStock;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stock for "${item.title}" updated to $newStock units.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update stock: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showStockAdjustmentModal(InventoryProductItem item) {
    final controller = TextEditingController(text: item.stockQuantity.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust Stock — ${item.title}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SKU: ${item.sku}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text('Current Stock: ${item.stockQuantity} units', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New Stock Quantity',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004D40), foregroundColor: Colors.white),
            onPressed: () {
              final val = int.tryParse(controller.text.trim());
              if (val == null || val < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid non-negative integer.')),
                );
                return;
              }
              Navigator.pop(ctx);
              _updateStockOnServer(item, val);
            },
            child: const Text('Save Stock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalUnits = _inventory.fold<int>(0, (sum, item) => sum + item.stockQuantity);
    final lowStockCount = _inventory.where((i) => i.stockQuantity <= 5).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seller Inventory & Stock Tracker'),
        backgroundColor: const Color(0xFF004D40),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchInventory,
            tooltip: 'Refresh Inventory',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _fetchInventory, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stock Summary Banner
                      Card(
                        color: const Color(0xFF004D40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text('Total SKUs', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text('${_inventory.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text('Total Units in Stock', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text('$totalUnits', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text('Low Stock Alerts', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text('$lowStockCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Inventory List Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Product Stock Management', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('${_inventory.length} items', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_inventory.isEmpty)
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: const Padding(
                            padding: EdgeInsets.all(40.0),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey),
                                  SizedBox(height: 12),
                                  Text(
                                    'No products in inventory.',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Add products in the Seller Product Catalog to manage their stock levels.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
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
                              final isLow = item.stockQuantity <= 5;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isLow ? Colors.red.shade100 : const Color(0xFFE0F2F1),
                                  child: Icon(
                                    Icons.inventory,
                                    color: isLow ? Colors.red : const Color(0xFF004D40),
                                  ),
                                ),
                                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text(
                                  'SKU: ${item.sku} | Price: Rs. ${item.price.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isLow ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item.velocityCategory,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isLow ? Colors.red : Colors.green,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('${item.stockQuantity} Units', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20, color: Color(0xFF004D40)),
                                      onPressed: () => _showStockAdjustmentModal(item),
                                      tooltip: 'Update Stock',
                                    ),
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
}
