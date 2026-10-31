import 'package:flutter/material.dart';
import 'package:apna_store/core/services/app_state_provider.dart';

void showAddToCartSuccessDialog(
  BuildContext context, {
  required AppProduct product,
  int quantity = 1,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      // Auto-close dialog after 2.5 seconds if user hasn't closed it manually
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (dialogContext.mounted && Navigator.canPop(dialogContext)) {
          Navigator.pop(dialogContext);
        }
      });

      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 10,
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          width: 380,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF059669),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Added to cart successfully!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () {
                  if (dialogContext.mounted && Navigator.canPop(dialogContext)) {
                    Navigator.pop(dialogContext);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.close_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
