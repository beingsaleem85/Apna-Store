import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/app_auth_provider.dart';
import '../../../../core/services/app_state_provider.dart';

class SellerDashboardHeader extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController searchController;
  final String activeSellerId;
  final ValueChanged<String> onSelectSeller;
  final ValueChanged<String> onSelectSection;
  final bool isWeb;

  const SellerDashboardHeader({
    super.key,
    required this.searchController,
    required this.activeSellerId,
    required this.onSelectSeller,
    required this.onSelectSection,
    required this.isWeb,
  });

  @override
  Size get preferredSize => const Size.fromHeight(65);

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateProvider>(context);

    return Container(
      height: 65,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
          if (!isWeb)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: Color(0xFF0F172A)),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          const SizedBox(width: 8),

          // Executive Compact Search Bar Box
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: searchController,
                style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'Search products, orders...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  prefixIcon: Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Right Action Tools
          IconButton(
            icon: const Badge(
              label: Text('2'),
              child: Icon(Icons.notifications_none_outlined, color: Color(0xFF475569)),
            ),
            tooltip: 'Notifications',
            onPressed: () => onSelectSection('customers_chat'),
          ),

          if (isWeb) ...[
            // Store Status Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Row(
                children: [
                  CircleAvatar(radius: 3, backgroundColor: Color(0xFF059669)),
                  SizedBox(width: 6),
                  Text('Store status ∨', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Language Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.language, size: 14, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Text('English / اردو', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                ],
              ),
            ),

            const SizedBox(width: 12),
          ],

          // Store Switcher & Profile Avatar
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: activeSellerId,
              dropdownColor: Colors.white,
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF475569)),
              items: state.stores.map((s) {
                return DropdownMenuItem(
                  value: s.id,
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFF2563EB),
                        child: Icon(Icons.person, size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(s.shopName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const Text('Seller ∨', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  onSelectSeller(val);
                }
              },
            ),
          ),

          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
            tooltip: 'Logout',
            onPressed: () {
              Provider.of<AppAuthProvider>(context, listen: false).signOut();
              Navigator.pushReplacementNamed(context, '/seller/login');
            },
          ),
        ],
      ),
    ),
  );
  }
}
