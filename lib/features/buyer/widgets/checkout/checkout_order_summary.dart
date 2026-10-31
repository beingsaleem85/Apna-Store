import 'package:flutter/material.dart';
import '../../../../core/services/app_state_provider.dart';

class CheckoutOrderSummary extends StatelessWidget {
  final List<AppProduct> uniqueProducts;
  final Map<String, int> groupedQuantities;

  const CheckoutOrderSummary({
    super.key,
    required this.uniqueProducts,
    required this.groupedQuantities,
  });

  @override
  Widget build(BuildContext context) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('2. Order Review & Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              Text('${uniqueProducts.length} unique item(s)', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 16),

          uniqueProducts.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No items in cart', style: TextStyle(color: Color(0xFF64748B)))))
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: uniqueProducts.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 20),
                  itemBuilder: (context, idx) {
                    final p = uniqueProducts[idx];
                    final qty = groupedQuantities[p.id] ?? 1;
                    final priceNum = int.tryParse(p.price.replaceAll(',', '')) ?? 3455;
                    final itemTotal = priceNum * qty;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              p.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 20, color: Color(0xFFCBD5E1)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('Seller: ${p.sellerId}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              const SizedBox(height: 4),
                              Text('PKR ${p.price} x $qty', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        Text('PKR $itemTotal', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                      ],
                    );
                  },
                ),
        ],
      ),
    );
  }
}
