import 'package:flutter/material.dart';

class BuyerCategoryCardItem extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const BuyerCategoryCardItem({
    super.key,
    required this.name,
    required this.icon,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isSelected ? const Color(0xFFFDB913) : const Color(0xFFF1F5F9);
    final textColor = isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: activeColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFDB913) : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFFFDB913).withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 4))]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF0F172A)),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class BuyerResponsiveCategoryGrid extends StatelessWidget {
  final String selectedCategory;
  final ValueChanged<String> onSelectCategory;

  const BuyerResponsiveCategoryGrid({
    super.key,
    required this.selectedCategory,
    required this.onSelectCategory,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      {'name': 'Mobiles', 'icon': Icons.phone_iphone_outlined},
      {'name': 'Electronics', 'icon': Icons.laptop_mac_outlined},
      {'name': 'Fashion', 'icon': Icons.checkroom_outlined},
      {'name': 'Home', 'icon': Icons.chair_outlined},
      {'name': 'Beauty', 'icon': Icons.sanitizer_outlined},
      {'name': 'Grocery', 'icon': Icons.shopping_bag_outlined},
      {'name': 'Sports', 'icon': Icons.sports_basketball_outlined},
      {'name': 'Automotive', 'icon': Icons.directions_car_outlined},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            children: categories.asMap().entries.map((entry) {
              final idx = entry.key;
              final cat = entry.value;
              final isLast = idx == categories.length - 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 12.0),
                  child: BuyerCategoryCardItem(
                    name: cat['name'] as String,
                    icon: cat['icon'] as IconData,
                    isSelected: selectedCategory == cat['name'],
                    onTap: () => onSelectCategory(cat['name'] as String),
                  ),
                ),
              );
            }).toList(),
          );
        } else if (constraints.maxWidth > 600) {
          final firstHalf = categories.sublist(0, 4);
          final secondHalf = categories.sublist(4, 8);
          return Column(
            children: [
              Row(
                children: firstHalf.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final cat = entry.value;
                  final isLast = idx == firstHalf.length - 1;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: isLast ? 0 : 12.0),
                      child: BuyerCategoryCardItem(
                        name: cat['name'] as String,
                        icon: cat['icon'] as IconData,
                        isSelected: selectedCategory == cat['name'],
                        onTap: () => onSelectCategory(cat['name'] as String),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: secondHalf.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final cat = entry.value;
                  final isLast = idx == secondHalf.length - 1;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: isLast ? 0 : 12.0),
                      child: BuyerCategoryCardItem(
                        name: cat['name'] as String,
                        icon: cat['icon'] as IconData,
                        isSelected: selectedCategory == cat['name'],
                        onTap: () => onSelectCategory(cat['name'] as String),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        } else {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: SizedBox(
                    width: 96,
                    child: BuyerCategoryCardItem(
                      name: cat['name'] as String,
                      icon: cat['icon'] as IconData,
                      isSelected: selectedCategory == cat['name'],
                      onTap: () => onSelectCategory(cat['name'] as String),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }
      },
    );
  }
}
