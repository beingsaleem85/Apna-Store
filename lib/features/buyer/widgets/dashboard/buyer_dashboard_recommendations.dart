import 'package:flutter/material.dart';

class OfficialStoreCardWidget extends StatelessWidget {
  final Map<String, dynamic> store;

  const OfficialStoreCardWidget({
    super.key,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    final brandName = store['brandName'] as String;
    final logoIcon = store['logoIcon'] as IconData;
    final brandColor = store['brandColor'] as Color;
    final bgColor = store['bgColor'] as Color;
    final subtitle = store['subtitle'] as String;
    final rating = store['rating'] as String;
    final reviews = store['reviews'] as String;

    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/category', arguments: brandName),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Icon(logoIcon, color: brandColor, size: 24),
                  ),
                ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.verified_rounded, size: 10, color: Color(0xFF0F766E)),
                          SizedBox(width: 2),
                          Text(
                            'Verified',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              brandName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: brandColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF64748B),
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                const SizedBox(width: 2),
                Text(
                  rating,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  reviews,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BuyerResponsiveOfficialStoresGrid extends StatelessWidget {
  const BuyerResponsiveOfficialStoresGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final stores = [
      {
        'brandName': 'Samsung',
        'logoText': 'SAMSUNG',
        'logoIcon': Icons.phone_android_rounded,
        'brandColor': const Color(0xFF1428A0),
        'bgColor': const Color(0xFFEEF2FF),
        'subtitle': 'Official Samsung Store - Mobile & Smart Devices',
        'rating': '4.9',
        'reviews': '(1.2k)',
      },
      {
        'brandName': 'Nike',
        'logoText': 'NIKE',
        'logoIcon': Icons.sports_kabaddi_rounded,
        'brandColor': const Color(0xFF1E293B),
        'bgColor': const Color(0xFFF8FAFC),
        'subtitle': 'Official Nike Flagship Store - Sportswear & Shoes',
        'rating': '4.8',
        'reviews': '(850)',
      },
      {
        'brandName': 'Sony',
        'logoText': 'SONY',
        'logoIcon': Icons.tv_rounded,
        'brandColor': const Color(0xFF0F172A),
        'bgColor': const Color(0xFFF1F5F9),
        'subtitle': 'Official Sony Store - Audio, TV & Gaming Accessories',
        'rating': '4.9',
        'reviews': '(960)',
      },
      {
        'brandName': 'Adidas',
        'logoText': 'adidas',
        'logoIcon': Icons.sports_rounded,
        'brandColor': const Color(0xFF047857),
        'bgColor': const Color(0xFFECFDF5),
        'subtitle': 'Official Adidas Performance Store - Athletic Wear',
        'rating': '4.7',
        'reviews': '(640)',
      },
      {
        'brandName': 'Xiaomi',
        'logoText': 'mi',
        'logoIcon': Icons.devices_other_rounded,
        'brandColor': const Color(0xFFFF6900),
        'bgColor': const Color(0xFFFFF7ED),
        'subtitle': 'Official Xiaomi Store - Smartphones & Ecosystem',
        'rating': '4.8',
        'reviews': '(1.1k)',
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            children: stores.asMap().entries.map((entry) {
              final idx = entry.key;
              final store = entry.value;
              final isLast = idx == stores.length - 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 12.0),
                  child: OfficialStoreCardWidget(store: store),
                ),
              );
            }).toList(),
          );
        } else {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: stores.map((store) {
                return SizedBox(
                  width: 180,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: OfficialStoreCardWidget(store: store),
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
