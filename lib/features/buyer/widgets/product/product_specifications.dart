import 'package:flutter/material.dart';
import '../../../../core/services/app_state_provider.dart';

class ProductSpecificationsSection extends StatelessWidget {
  final AppProduct product;

  const ProductSpecificationsSection({
    super.key,
    required this.product,
  });

  Widget _buildSpecPair(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading
          Text(
            'Product details of ${product.name}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),

          // Highlights Bullet Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: const Text(
              '- 6.75" 120Hz Dot Notch display (720x1600) - 5000mAh battery with 15W fast charging & Type-C - 128GB/64GB storage + 8GB RAM (4GB extended RAM) - 13MP rear camera with dual flash, 8MP front camera - T7250 processor, Android 15 - Side fingerprint sensor, infrared remote control',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF334155),
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Paragraph Description
          Text(
            product.description.isNotEmpty
                ? product.description
                : 'Enjoy smooth scrolling on the 6.75" 120Hz Dot Notch screen. Power through your day with a 5000mAh battery and 15W fast charging. Choose between 128GB or 64GB storage, both paired with 8GB RAM (expandable to 12GB). Capture memories with the 13MP rear camera (dual flash) and 8MP front camera. Powered by the T7250 processor and Android 15, it also features a side fingerprint sensor, infrared remote control, and OTG support.',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 20),

          // Specifications Heading
          Text(
            'Specifications of ${product.name}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),

          // Two-column Spec Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              return Wrap(
                runSpacing: 16,
                spacing: constraints.maxWidth > 600 ? constraints.maxWidth * 0.1 : 16,
                children: [
                  SizedBox(
                    width: isMobile ? constraints.maxWidth : constraints.maxWidth * 0.42,
                    child: Column(
                      children: [
                        _buildSpecPair('Brand', 'TECNO'),
                        const SizedBox(height: 14),
                        _buildSpecPair('Protection', 'Not Specified'),
                        const SizedBox(height: 14),
                        _buildSpecPair('Year', '2026'),
                        const SizedBox(height: 14),
                        _buildSpecPair('Number Of Cameras', 'Not Specified'),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? constraints.maxWidth : constraints.maxWidth * 0.42,
                    child: Column(
                      children: [
                        _buildSpecPair('SKU', '1948224278_PK-14011801477'),
                        const SizedBox(height: 14),
                        _buildSpecPair('Camera Back (Megapixels)', 'Not Specified'),
                        const SizedBox(height: 14),
                        _buildSpecPair('Condition', 'Brand New'),
                        const SizedBox(height: 14),
                        _buildSpecPair('Warranty', '1 Year Official Brand Warranty'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('What’s in the box', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
              SizedBox(width: 32),
              Expanded(
                child: Text('1x Phone, 1x Charging Cable, 1x User Manual', style: TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
