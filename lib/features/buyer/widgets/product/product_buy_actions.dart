import 'package:flutter/material.dart';
import '../../../../core/services/app_state_provider.dart';
import '../../../../core/widgets/add_to_cart_success_dialog.dart';
import '../../screens/auth/customer_auth_dialog.dart';

class ProductBuyActions extends StatelessWidget {
  final AppStateProvider state;
  final AppProduct product;
  final int selectedQuantity;

  const ProductBuyActions({
    super.key,
    required this.state,
    required this.product,
    required this.selectedQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOutOfStock = product.stock <= 0;

    return Row(
      children: [
        // Add to Cart Button
        Expanded(
          child: SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.shopping_cart_rounded, size: 18),
              label: Text(
                isOutOfStock ? 'Out of Stock' : 'Add to Cart ($selectedQuantity)',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isOutOfStock ? const Color(0xFF94A3B8) : const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: isOutOfStock ? 0 : 2,
                shadowColor: isOutOfStock ? Colors.transparent : const Color(0xFF059669).withOpacity(0.35),
              ),
              onPressed: isOutOfStock
                  ? null
                  : () {
                      state.addToCart(product, quantity: selectedQuantity);
                      showAddToCartSuccessDialog(
                        context,
                        product: product,
                        quantity: selectedQuantity,
                      );
                    },
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Buy Now Button
        Expanded(
          child: SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.flash_on_rounded, size: 18),
              label: const Text('Buy Now', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: isOutOfStock ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                side: BorderSide(color: isOutOfStock ? const Color(0xFFCBD5E1) : const Color(0xFF0F172A), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isOutOfStock
                  ? null
                  : () {
                      state.addToCart(product, quantity: selectedQuantity);
                      if (!state.isCustomerLoggedIn) {
                        showCustomerAuthDialog(
                          context,
                          targetAction: 'Buy Now',
                          onAuthSuccess: () {
                            Navigator.pushNamed(context, '/buyer/checkout');
                          },
                        );
                      } else {
                        Navigator.pushNamed(context, '/buyer/checkout');
                      }
                    },
            ),
          ),
        ),
      ],
    );
  }
}
