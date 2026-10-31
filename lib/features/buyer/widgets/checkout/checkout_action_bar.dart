import 'package:flutter/material.dart';

class CheckoutActionBar extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onPlaceOrder;

  const CheckoutActionBar({
    super.key,
    required this.isProcessing,
    required this.onPlaceOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
            onPressed: isProcessing ? null : onPlaceOrder,
            child: isProcessing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: 8),
                      Text('PLACE CONFIRMED ORDER NOW', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'By placing this order, you agree to Apna Store Terms of Service & Return Policy.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }
}
