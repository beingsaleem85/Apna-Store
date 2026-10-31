import 'package:flutter/material.dart';
import 'package:apna_store/core/widgets/app_footer.dart';

class BuyerOrderSuccessScreen extends StatelessWidget {
  const BuyerOrderSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String orderId = args?['orderId'] ?? '#APN-20260801001';
    final String buyerName = args?['buyerName'] ?? 'Customer';
    final int itemCount = args?['itemCount'] ?? 1;

    final String estimatedDelivery = '3-5 Days';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Utility Bar Header with Back Navigation
            Container(
              width: double.infinity,
              color: Colors.white,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 22),
                            tooltip: 'Return to Home',
                            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => Navigator.pushReplacementNamed(context, '/'),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Apna Store',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.home_outlined, size: 16, color: Color(0xFF059669)),
                            label: const Text('Home Marketplace', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Color(0xFF059669), size: 16),
                                SizedBox(width: 6),
                                Text('Order Confirmed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 40),

            // Success Content Container
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 680),
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    // Green Animated Success Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, size: 64, color: Color(0xFF059669)),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      '✅ Order Placed Successfully!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Thank you for your purchase, $buyerName! We have received your order and sent a confirmation to your phone.',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Order Details Box
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Order Number:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                              SelectableText(
                                orderId,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          const Divider(height: 20, color: Color(0xFFE2E8F0)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Items Ordered:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                              Text('$itemCount Item(s)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            ],
                          ),
                          const Divider(height: 20, color: Color(0xFFE2E8F0)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Estimated Delivery:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                              Text(estimatedDelivery, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Navigation Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.arrow_back_rounded, size: 16),
                            label: const Text('Continue Shopping', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.receipt_long_rounded, size: 16),
                            label: const Text('Go to My Orders', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 2,
                            ),
                            onPressed: () => Navigator.pushNamed(context, '/buyer/orders'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 60),

            // Footer
            const AppFooter(),
          ],
        ),
      ),
    );
  }
}
