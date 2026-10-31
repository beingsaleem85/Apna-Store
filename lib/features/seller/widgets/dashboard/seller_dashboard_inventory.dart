import 'package:flutter/material.dart';
import '../../../../core/services/app_state_provider.dart';

// 1. Executive Stock Level & Low Inventory Alerts Section
class SellerStockAlertsSection extends StatefulWidget {
  final AppStateProvider state;
  final String activeSellerId;

  const SellerStockAlertsSection({
    super.key,
    required this.state,
    required this.activeSellerId,
  });

  @override
  State<SellerStockAlertsSection> createState() => _SellerStockAlertsSectionState();
}

class _SellerStockAlertsSectionState extends State<SellerStockAlertsSection> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedFilter = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showRestockDialog(AppProduct product) {
    final qtyCtrl = TextEditingController(text: '50');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Restock Stock: ${product.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Stock: ${product.stock} Units', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            const Text('Add Units Quantity:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
            onPressed: () {
              final added = int.tryParse(qtyCtrl.text) ?? 0;
              setState(() {
                product.stock += added;
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Added $added units to ${product.name}!'), backgroundColor: const Color(0xFF059669)),
              );
            },
            child: const Text('Confirm Restock'),
          ),
        ],
      ),
    );
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
    final allProducts = widget.state.products;
    final sellerProds = allProducts.where((p) => p.sellerId == widget.activeSellerId || p.sellerId.startsWith('seller_')).toList();
    final displayProds = sellerProds.isNotEmpty ? sellerProds : allProducts;

    final searchQuery = _searchCtrl.text.toLowerCase();
    final filtered = displayProds.where((p) {
      final matchesSearch = searchQuery.isEmpty || p.name.toLowerCase().contains(searchQuery) || p.category.toLowerCase().contains(searchQuery);
      bool matchesFilter = true;
      if (_selectedFilter == 'Critical Stockout') matchesFilter = p.stock == 0;
      if (_selectedFilter == 'Low Stock Warning') matchesFilter = p.stock > 0 && p.stock <= 10;
      if (_selectedFilter == 'Healthy Stock') matchesFilter = p.stock > 10;
      return matchesSearch && matchesFilter;
    }).toList();

    final criticalCount = displayProds.where((p) => p.stock == 0).length;
    final lowCount = displayProds.where((p) => p.stock > 0 && p.stock <= 10).length;
    final healthyCount = displayProds.where((p) => p.stock > 10).length;
    final totalUnits = displayProds.fold<int>(0, (sum, p) => sum + p.stock);

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
                  Text('Inventory Stock Level & Low-Stock Alerts Desk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Monitor low inventory items, critical stockouts, reorder points, and automated stock replenishment.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    for (var p in displayProds) {
                      if (p.stock <= 10) p.stock += 50;
                    }
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All low stock items replenished with +50 units!'), backgroundColor: Color(0xFF059669)),
                  );
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Auto-Restock All Low Items', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                  _buildKpiBox('Critical Stockouts', '$criticalCount Items (0 Units)', Icons.error_outline, const Color(0xFFDC2626)),
                  _buildKpiBox('Low Stock Warnings', '$lowCount Items (<10)', Icons.warning_amber_rounded, const Color(0xFFEA580C)),
                  _buildKpiBox('Healthy Inventory', '$healthyCount Items In Stock', Icons.check_circle_outline, const Color(0xFF059669)),
                  _buildKpiBox('Total Stock Units', '$totalUnits Units On Hand', Icons.inventory_2_outlined, const Color(0xFF0284C7)),
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
                    // Search Input
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Search product title or category...',
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

                    // Filter Dropdown
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 38,
                        child: DropdownButtonFormField<String>(
                          value: _selectedFilter,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All Stock Levels')),
                            DropdownMenuItem(value: 'Critical Stockout', child: Text('Critical Stockouts (0)')),
                            DropdownMenuItem(value: 'Low Stock Warning', child: Text('Low Stock Warning (1-10)')),
                            DropdownMenuItem(value: 'Healthy Stock', child: Text('Healthy Stock (>10)')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedFilter = v);
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
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Expanded(flex: 4, child: Text('PRODUCT DETAILS & ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)))),
                      Expanded(flex: 2, child: Text('CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)))),
                      Expanded(flex: 2, child: Text('CURRENT STOCK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)))),
                      Expanded(flex: 2, child: Text('REORDER THRESHOLD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)))),
                      Expanded(flex: 2, child: Text('ALERT STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)))),
                      Expanded(flex: 3, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)))),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Stock Alerts List
                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    child: const Center(
                      child: Text('No inventory items match your active search or filter criteria.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final bool isOut = item.stock == 0;
                      final bool isLow = item.stock > 0 && item.stock <= 10;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Row(
                          children: [
                            // Product Info
                            Expanded(
                              flex: 4,
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      item.imageUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(width: 40, height: 40, color: const Color(0xFFE2E8F0), child: const Icon(Icons.image, size: 18)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 2),
                                        Text('ID: ${item.id} | Price: PKR ${item.price}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Category
                            Expanded(flex: 2, child: Text(item.category, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),

                            // Current Stock
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${item.stock} Units',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isOut ? const Color(0xFFDC2626) : (isLow ? const Color(0xFFEA580C) : const Color(0xFF059669)),
                                ),
                              ),
                            ),

                            // Reorder Threshold
                            Expanded(flex: 2, child: const Text('10 Units', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))),

                            // Alert Status Badge
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOut ? const Color(0xFFFEF2F2) : (isLow ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isOut ? 'Critical Stockout' : (isLow ? 'Low Warning' : 'Healthy'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isOut ? const Color(0xFFDC2626) : (isLow ? const Color(0xFFEA580C) : const Color(0xFF059669)),
                                  ),
                                ),
                              ),
                            ),

                            // Actions
                            Expanded(
                              flex: 3,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _showRestockDialog(item),
                                    icon: const Icon(Icons.add, size: 14),
                                    label: const Text('Restock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                  ),
                                ],
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

// 2. Executive Multi-Fulfillment Warehouse & Depot Hub Section
class SellerWarehouseManagementSection extends StatefulWidget {
  final AppStateProvider state;
  final String activeSellerId;

  const SellerWarehouseManagementSection({
    super.key,
    required this.state,
    required this.activeSellerId,
  });

  @override
  State<SellerWarehouseManagementSection> createState() => _SellerWarehouseManagementSectionState();
}

class _SellerWarehouseManagementSectionState extends State<SellerWarehouseManagementSection> {
  final List<Map<String, String>> _warehouses = [
    {
      'name': 'Lahore Central Fulfillment Hub',
      'code': 'WH-LHR-01',
      'address': 'Plot 14, Industrial Estate, Kot Lakhpat, Lahore',
      'capacity': '750 / 1,000 Units',
      'percentage': '75%',
      'courier': 'Apna Express Hub',
      'status': 'Operational',
    },
    {
      'name': 'Karachi South Logistics Depot',
      'code': 'WH-KHI-02',
      'address': 'Warehouse 8, SITE Area, Korangi, Karachi',
      'capacity': '420 / 500 Units',
      'percentage': '84%',
      'courier': 'TCS Express Center',
      'status': 'Operational',
    },
    {
      'name': 'Islamabad Capital Dispatch Center',
      'code': 'WH-ISB-03',
      'address': 'Street 19, I-9/3 Industrial Area, Islamabad',
      'capacity': '280 / 300 Units',
      'percentage': '93%',
      'courier': 'Leopard Courier Desk',
      'status': 'Near Capacity',
    },
  ];

  void _showAddWarehouseModal() {
    final nameCtrl = TextEditingController(text: 'Multan Regional Depot');
    final codeCtrl = TextEditingController(text: 'WH-MUX-04');
    final addrCtrl = TextEditingController(text: 'Industrial Estate, Phase 2, Multan');
    final capCtrl = TextEditingController(text: '500');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Register New Warehouse Depot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Warehouse Name', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Depot Code', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Physical Address', isDense: true)),
            const SizedBox(height: 8),
            TextField(controller: capCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max Capacity Units', isDense: true)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _warehouses.add({
                  'name': nameCtrl.text,
                  'code': codeCtrl.text,
                  'address': addrCtrl.text,
                  'capacity': '0 / ${capCtrl.text} Units',
                  'percentage': '0%',
                  'courier': 'Apna Express Hub',
                  'status': 'Operational',
                });
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('New Warehouse Depot registered!'), backgroundColor: Color(0xFF059669)),
              );
            },
            child: const Text('Save Warehouse'),
          ),
        ],
      ),
    );
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
                  Text('Multi-Fulfillment Warehouse & Depot Hub', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text('Manage fulfillment warehouses, storage rack capacity, stock transfers, and depot dispatch centers.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAddWarehouseModal,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Warehouse Depot', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
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
                  _buildKpiBox('Active Depots', '${_warehouses.length} Regional Depots', Icons.warehouse_outlined, const Color(0xFF0284C7)),
                  _buildKpiBox('Storage Capacity', '82% Overall Occupied', Icons.pie_chart_outline, const Color(0xFFEA580C)),
                  _buildKpiBox('Inter-Depot Transfers', '2 Active Transfers', Icons.swap_horiz_outlined, const Color(0xFF7C3AED)),
                  _buildKpiBox('Fulfillment SLA', '99.2% Same-Day Dispatch', Icons.speed_outlined, const Color(0xFF059669)),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Warehouse Depots Cards List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _warehouses.length,
            itemBuilder: (context, index) {
              final wh = _warehouses[index];
              final bool isNear = wh['status'] == 'Near Capacity';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.store_mall_directory_outlined, color: Color(0xFF2563EB), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(wh['name']!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                                child: Text(wh['code']!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isNear ? const Color(0xFFFFF7ED) : const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  wh['status']!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isNear ? const Color(0xFFEA580C) : const Color(0xFF059669),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Address: ${wh['address']} | Dispatch Courier: ${wh['courier']}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('Storage Units Occupied: ${wh['capacity']} (${wh['percentage']})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Opening stock transfer order for ${wh['name']}...'), backgroundColor: const Color(0xFF2563EB)),
                        );
                      },
                      icon: const Icon(Icons.swap_horiz, size: 14),
                      label: const Text('Transfer Stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
