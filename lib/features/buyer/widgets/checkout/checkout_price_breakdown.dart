import 'package:flutter/material.dart';

class CheckoutPriceBreakdown extends StatelessWidget {
  final int subtotal;
  final int shippingFee;
  final int couponDiscount;
  final int grandTotal;

  const CheckoutPriceBreakdown({
    super.key,
    required this.subtotal,
    required this.shippingFee,
    required this.couponDiscount,
    required this.grandTotal,
  });

  Widget _buildPriceRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: isBold ? const Color(0xFF0F172A) : const Color(0xFF64748B), fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: isBold ? 16 : 13, color: color ?? (isBold ? const Color(0xFF0F172A) : const Color(0xFF0F172A)), fontWeight: isBold ? FontWeight.w900 : FontWeight.bold)),
        ],
      ),
    );
  }

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
          const Text('Order Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 14),

          _buildPriceRow('Items Subtotal', 'PKR $subtotal'),
          _buildPriceRow('Shipping Fee', shippingFee == 0 ? 'FREE' : 'PKR $shippingFee', color: shippingFee == 0 ? const Color(0xFF059669) : null),
          if (couponDiscount > 0)
            _buildPriceRow('Voucher Discount', '- PKR $couponDiscount', color: const Color(0xFF059669)),

          const Divider(color: Color(0xFFE2E8F0), height: 24),
          _buildPriceRow('Grand Total (VAT Inc.)', 'PKR $grandTotal', isBold: true, color: const Color(0xFF059669)),
        ],
      ),
    );
  }
}
