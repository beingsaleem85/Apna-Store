import 'package:flutter/material.dart';

class BuyerTimerBadge extends StatelessWidget {
  final String val;

  const BuyerTimerBadge({super.key, required this.val});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(val, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class MarketplaceProductCardWidget extends StatelessWidget {
  final Map<String, dynamic> product;

  const MarketplaceProductCardWidget({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    final title = (product['title'] ?? product['name']) as String? ?? 'Marketplace Product';
    final price = (product['currentPrice'] ?? product['price']) as String? ?? 'PKR 3,455';
    final origPrice = (product['originalPrice'] ?? product['origPrice']) as String? ?? '';
    final imageUrl = (product['imgUrl'] ?? product['imageUrl'] ?? product['image']) as String? ?? 'https://images.unsplash.com/photo-1592899677977-9c10ca588bbd?w=300';
    final rating = (product['rating'] as num?)?.toDouble() ?? 4.8;
    final reviewsCount = (product['reviews'] ?? product['reviewsCount']) as int? ?? 120;
    final isOfficial = product['isOfficialStore'] as bool? ?? false;
    final isHotDeal = product['isHotDeal'] as bool? ?? false;

    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/product', arguments: product),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Image.network(
                      imageUrl.isNotEmpty ? imageUrl : 'https://images.unsplash.com/photo-1592899677977-9c10ca588bbd?w=300',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFFF1F5F9),
                        child: Image.network(
                          'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=300',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8), size: 28),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (isHotDeal)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('HOT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isOfficial)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2.0),
                      child: Row(
                        children: const [
                          Icon(Icons.verified, size: 12, color: Color(0xFF0F766E)),
                          SizedBox(width: 2),
                          Text('Official Store', style: TextStyle(fontSize: 9, color: Color(0xFF0F766E), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), height: 1.2),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 2),
                      Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(width: 2),
                      Text('($reviewsCount)', style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Rs. $price',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (origPrice.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Rs. $origPrice',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), decoration: TextDecoration.lineThrough),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BuyerResponsiveProductGrid extends StatelessWidget {
  final List<Map<String, dynamic>> products;

  const BuyerResponsiveProductGrid({
    super.key,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: products.asMap().entries.map((entry) {
              final idx = entry.key;
              final prod = entry.value;
              final isLast = idx == products.length - 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 14.0),
                  child: MarketplaceProductCardWidget(product: prod),
                ),
              );
            }).toList(),
          );
        } else if (constraints.maxWidth > 600) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.65,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return MarketplaceProductCardWidget(product: products[index]);
            },
          );
        } else {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.62,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return MarketplaceProductCardWidget(product: products[index]);
            },
          );
        }
      },
    );
  }
}
