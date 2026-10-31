import 'package:flutter/material.dart';
import '../../../../core/config/feature_flags.dart';

class CheckoutPaymentSelector extends StatelessWidget {
  final String selectedPaymentMethod;
  final ValueChanged<String> onPaymentMethodChanged;

  const CheckoutPaymentSelector({
    super.key,
    required this.selectedPaymentMethod,
    required this.onPaymentMethodChanged,
  });

  Widget _buildPaymentTile({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    bool isEnabled = true,
  }) {
    final isSelected = selectedPaymentMethod == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isEnabled ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: isEnabled ? () => onPaymentMethodChanged(id) : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Radio<String>(
                value: id,
                groupValue: selectedPaymentMethod,
                onChanged: isEnabled ? (val) => val != null ? onPaymentMethodChanged(val) : null : null,
                activeColor: const Color(0xFF059669),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 18, color: isEnabled ? (isSelected ? const Color(0xFF059669) : const Color(0xFF0F172A)) : const Color(0xFF94A3B8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isEnabled ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        if (!isEnabled) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                            child: const Text('Coming Soon', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: isEnabled ? const Color(0xFF64748B) : const Color(0xFFCBD5E1))),
                  ],
                ),
              ),
            ],
          ),
        ),
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
          const Text('3. Payment Method Boundary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 14),

          _buildPaymentTile(
            id: 'COD',
            title: 'Cash on Delivery (COD)',
            subtitle: 'Pay with physical cash upon receiving your order parcel at doorstep.',
            icon: Icons.payments_outlined,
            isEnabled: true,
          ),

          _buildPaymentTile(
            id: 'JazzCash',
            title: 'JazzCash Mobile Wallet',
            subtitle: 'Instant digital checkout with your JazzCash mobile account.',
            icon: Icons.account_balance_wallet_outlined,
            isEnabled: FeatureFlags.onlinePaymentsEnabled,
          ),

          _buildPaymentTile(
            id: 'Easypaisa',
            title: 'Easypaisa Mobile Account',
            subtitle: 'Pay securely using your verified Easypaisa wallet balance.',
            icon: Icons.mobile_friendly_outlined,
            isEnabled: FeatureFlags.onlinePaymentsEnabled,
          ),

          _buildPaymentTile(
            id: 'Debit/Credit Card',
            title: 'Credit / Debit Card (Visa / MasterCard / PayPak)',
            subtitle: 'Secure 3D Card gateway adhering to PCI-DSS payment standards.',
            icon: Icons.credit_card_outlined,
            isEnabled: FeatureFlags.onlinePaymentsEnabled,
          ),
        ],
      ),
    );
  }
}
