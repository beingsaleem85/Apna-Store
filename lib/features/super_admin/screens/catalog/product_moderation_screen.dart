import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/admin_toast_dialog.dart';
import '../../services/super_admin_provider.dart';
import '../../../../core/services/app_state_provider.dart';

class ProductModerationScreen extends StatefulWidget {
  const ProductModerationScreen({super.key});

  @override
  State<ProductModerationScreen> createState() => _ProductModerationScreenState();
}

class _ProductModerationScreenState extends State<ProductModerationScreen> {
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Approved', 'Rejected'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppStateProvider>(context, listen: false);
      appState.fetchProductsFromSupabase();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final adminState = Provider.of<SuperAdminProvider>(context);

    // Filter Products based on Selected Filter & Search Query
    final filteredProducts = appState.products.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.sellerId.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (_selectedFilter == 'Pending') return p.approvalStatus == 'Pending';
      if (_selectedFilter == 'Approved') return p.approvalStatus == 'Approved';
      if (_selectedFilter == 'Rejected') return p.approvalStatus == 'Rejected';
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumbs & Header Title (Matching Panel 5)
          const Text('Breadcrumbs > Products > Product Moderation', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Product Moderation', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
                    child: const Text('Bulk moderation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                    child: const Text('Bulk Actions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Interactive Catalog Moderation Filter Tabs
          Row(
            children: [
              {'label': 'All Products', 'filter': 'All'},
              {'label': 'Pending Moderation Queue', 'filter': 'Pending'},
              {'label': 'Approved Products', 'filter': 'Approved'},
              {'label': 'Rejected / Prohibited', 'filter': 'Rejected'},
            ].map((tabObj) {
              final label = tabObj['label']!;
              final filterVal = tabObj['filter']!;
              final isSel = _selectedFilter == filterVal;
              return InkWell(
                onTap: () => setState(() => _selectedFilter = filterVal),
                child: Container(
                  margin: const EdgeInsets.only(right: 20),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    border: isSel ? const Border(bottom: BorderSide(color: Color(0xFF0F172A), width: 2.5)) : null,
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      color: isSel ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Search bar & Filter
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
                      hintText: 'Search by Product Name, Category, Seller ID...',
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

          // Master Product Table
          Card(
            color: SuperAdminTheme.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: SuperAdminTheme.borderDark)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: SuperAdminTheme.bgDark, borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Product Item & Image', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: SuperAdminTheme.textMuted))),
                        Expanded(child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: SuperAdminTheme.textMuted))),
                        Expanded(child: Text('Retail Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: SuperAdminTheme.textMuted))),
                        Expanded(child: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: SuperAdminTheme.textMuted))),
                        Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: SuperAdminTheme.textMuted))),
                        Expanded(flex: 2, child: Text('Moderation Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: SuperAdminTheme.textMuted))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (filteredProducts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: SuperAdminTheme.textMuted),
                          SizedBox(height: 12),
                          Text('No products found matching selected filter criteria.', style: TextStyle(color: SuperAdminTheme.textMuted, fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    ...filteredProducts.map((product) {
                      final isPending = product.approvalStatus == 'Pending';
                      final isApproved = product.approvalStatus == 'Approved';

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: SuperAdminTheme.cardDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: SuperAdminTheme.borderDark),
                        ),
                        child: Row(
                          children: [
                            // Image & Name
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: SuperAdminTheme.bgDark,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: SuperAdminTheme.borderDark),
                                    ),
                                    child: const Icon(Icons.image, color: SuperAdminTheme.textMuted, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text('Seller: ${product.sellerId}', style: const TextStyle(color: SuperAdminTheme.textMuted, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Category
                            Expanded(child: Text(product.category, style: const TextStyle(color: Colors.white70, fontSize: 12))),

                            // Price
                            Expanded(child: Text('Rs. ${product.price}', style: const TextStyle(fontWeight: FontWeight.bold, color: SuperAdminTheme.secondaryGold, fontSize: 13))),

                            // Stock
                            Expanded(child: Text('${product.stock} Units', style: const TextStyle(color: Colors.white70, fontSize: 12))),

                            // Status Badge
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isApproved
                                      ? Colors.green.withOpacity(0.2)
                                      : isPending
                                          ? Colors.amber.withOpacity(0.2)
                                          : Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  product.approvalStatus.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isApproved
                                        ? Colors.green
                                        : isPending
                                            ? Colors.amber
                                            : Colors.redAccent,
                                  ),
                                ),
                              ),
                            ),

                            // Action Buttons
                            Expanded(
                              flex: 2,
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.search, size: 14),
                                    label: const Text('Inspect', style: TextStyle(fontSize: 11)),
                                    style: OutlinedButton.styleFrom(foregroundColor: SuperAdminTheme.secondaryGold, side: const BorderSide(color: SuperAdminTheme.borderDark)),
                                    onPressed: () => _showProductInspectionModal(product),
                                  ),

                                   if (!isApproved)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                                      onPressed: () async {
                                        final confirmed = await SuperAdminDialogs.showConfirmation(
                                          context: context,
                                          title: 'Approve Product Listing',
                                          message: 'Are you sure you want to approve "${product.name}" for public customer search?',
                                          confirmColor: Colors.teal,
                                        );
                                        if (confirmed) {
                                          try {
                                            await appState.approveProduct(product.id);
                                            adminState.logAuditAction('PRODUCT_APPROVAL', product.name, 'Approved product listing into customer catalog.');
                                            if (mounted) SuperAdminDialogs.showToast(context, '${product.name} Approved!');
                                          } catch (e) {
                                            if (mounted) SuperAdminDialogs.showToast(context, 'Approval failed: $e', isError: true);
                                          }
                                        }
                                      },
                                      child: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),

                                  if (isApproved)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                      onPressed: () async {
                                        final reason = await SuperAdminDialogs.showReasonInput(
                                          context: context,
                                          title: 'Reject Product Listing',
                                          labelText: 'Rejection Reason',
                                          hintText: 'Enter reason for rejecting catalog item...',
                                        );
                                        if (reason != null && reason.isNotEmpty) {
                                          try {
                                            await appState.rejectProduct(product.id, reason);
                                            adminState.logAuditAction('PRODUCT_REJECTION', product.name, 'Rejected product. Reason: $reason');
                                            if (mounted) SuperAdminDialogs.showToast(context, '${product.name} Rejected.', isError: true);
                                          } catch (e) {
                                            if (mounted) SuperAdminDialogs.showToast(context, 'Rejection failed: $e', isError: true);
                                          }
                                        }
                                      },
                                      child: const Text('Reject', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
          const SizedBox(height: 16),
          // Catalog Summary Footer Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_outlined, size: 18, color: Color(0xFF10B981)),
                    SizedBox(width: 8),
                    Text('Catalog Moderation Status: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    Text('Active (32 items in queue)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                Text('Catalog Version v2.4 — Updated today', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showProductInspectionModal(AppProduct product) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: SuperAdminTheme.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: AppBreakpoints.getResponsiveDialogWidth(context, defaultDesktopWidth: 600),
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
                      const Icon(Icons.inventory_2, color: SuperAdminTheme.secondaryGold),
                      const SizedBox(width: 10),
                      Text('Product Inspection — ${product.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(color: SuperAdminTheme.borderDark),
              const SizedBox(height: 12),

              Text('Category: ${product.category}', style: const TextStyle(color: Colors.white70)),
              Text('Retail Price: Rs. ${product.price}', style: const TextStyle(color: SuperAdminTheme.secondaryGold, fontWeight: FontWeight.bold)),
              Text('Current Stock: ${product.stock} Units', style: const TextStyle(color: Colors.white70)),
              Text('Seller Store ID: ${product.sellerId}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),

              const Text('Product Description:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(product.description, style: const TextStyle(color: SuperAdminTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 16),

              // Prohibited Item Alerts inside Modal
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFEF4444)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Prohibited Item Alert: Duplicate listing or missing brand authorization detected.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF991B1B), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Moderation Actions inside Modal
              const Text('Super Admin Moderation Actions:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Product "${product.name}" approved!'), backgroundColor: const Color(0xFF10B981)),
                        );
                        Navigator.pop(ctx);
                      },
                      child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Product "${product.name}" rejected.'), backgroundColor: const Color(0xFFEF4444)),
                        );
                        Navigator.pop(ctx);
                      },
                      child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF93C5FD), side: const BorderSide(color: Color(0xFF60A5FA))),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Change request sent to seller for "${product.name}".'), backgroundColor: const Color(0xFF2563EB)),
                        );
                        Navigator.pop(ctx);
                      },
                      child: const Text('Request Changes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
