import 'package:flutter/material.dart';
import '../../../../core/services/app_state_provider.dart';

class ProductInfoSection extends StatelessWidget {
  final AppProduct product;
  final int selectedQuantity;
  final ValueChanged<int> onQuantityChanged;
  final String? selectedVariant;
  final ValueChanged<String>? onVariantChanged;

  const ProductInfoSection({
    super.key,
    required this.product,
    required this.selectedQuantity,
    required this.onQuantityChanged,
    this.selectedVariant,
    this.onVariantChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOutOfStock = product.stock <= 0;
    final String activeVariant = selectedVariant ??
        (product.variations.isNotEmpty && product.variations.first.values.isNotEmpty
            ? product.variations.first.values.first
            : 'Default');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOutOfStock ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isOutOfStock ? 'Out of Stock' : 'Verified',
                  style: TextStyle(color: isOutOfStock ? const Color(0xFFDC2626) : const Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('-31%', style: TextStyle(color: Color(0xFFC2410C), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Title & Subtitle
          Text(
            product.name.isNotEmpty ? product.name : 'Sitimars Pro Wireless Earbuds Active Noise Cancelling',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.3),
          ),
          const SizedBox(height: 6),
          const Text('Official Store Warranty Included', style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          // Price Tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('PKR ${product.price}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              const SizedBox(width: 8),
              const Text('PKR 5,750', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), decoration: TextDecoration.lineThrough)),
            ],
          ),
          const SizedBox(height: 8),

          // Rating Row
          Row(
            children: const [
              Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
              Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
              Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
              Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
              Icon(Icons.star, size: 14, color: Color(0xFFF59E0B)),
              SizedBox(width: 4),
              Text('(4.9)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Spacer(),
              Text('305 Reviews', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Variant Selection Matrix
          if (product.variations.isNotEmpty) ...[
            ...product.variations.map((varGroup) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(varGroup.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: varGroup.values.map((val) {
                      final isSelected = val == activeVariant;
                      return ChoiceChip(
                        label: Text(val, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : const Color(0xFF0F172A), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        selected: isSelected,
                        selectedColor: const Color(0xFF059669),
                        backgroundColor: const Color(0xFFF8FAFC),
                        onSelected: (selected) {
                          if (selected && onVariantChanged != null) {
                            onVariantChanged!(val);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],
              );
            }).toList(),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),
          ],

          // Quantity Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Quantity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: selectedQuantity > 1 ? () => onQuantityChanged(selectedQuantity - 1) : null,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.remove, size: 16, color: selectedQuantity > 1 ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Text('$selectedQuantity', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    ),
                    InkWell(
                      onTap: isOutOfStock ? null : () => onQuantityChanged(selectedQuantity + 1),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.add, size: 16, color: isOutOfStock ? const Color(0xFFCBD5E1) : const Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
