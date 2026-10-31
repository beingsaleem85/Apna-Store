import 'package:flutter/material.dart';

class BuyerDashboardPhaseNavChip extends StatelessWidget {
  final String label;
  final String route;
  final IconData icon;

  const BuyerDashboardPhaseNavChip({
    super.key,
    required this.label,
    required this.route,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: const Color(0xFF004D40)),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF004D40),
        ),
      ),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFFDB913)),
      elevation: 2,
      onPressed: () => Navigator.pushNamed(context, route),
    );
  }
}

class BuyerDashboardQuickNavChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const BuyerDashboardQuickNavChip({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        avatar: Icon(icon, size: 14, color: const Color(0xFF0F172A)),
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        onPressed: onTap,
      ),
    );
  }
}

class BuyerDashboardQuickBar extends StatelessWidget {
  final VoidCallback onHomeTap;
  final VoidCallback onAccountTap;

  const BuyerDashboardQuickBar({
    super.key,
    required this.onHomeTap,
    required this.onAccountTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1280),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                BuyerDashboardQuickNavChip(
                  label: '🏠 Home Portal',
                  icon: Icons.home_outlined,
                  onTap: onHomeTap,
                ),
                BuyerDashboardQuickNavChip(
                  label: '📦 Orders & Tracking',
                  icon: Icons.local_shipping_outlined,
                  onTap: () => Navigator.pushNamed(context, '/buyer/order-tracking'),
                ),
                BuyerDashboardQuickNavChip(
                  label: '🛒 Cart & Checkout',
                  icon: Icons.shopping_cart_outlined,
                  onTap: () => Navigator.pushNamed(context, '/buyer/cart'),
                ),
                BuyerDashboardQuickNavChip(
                  label: '💳 Wallet & BNPL',
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () => Navigator.pushNamed(context, '/buyer/wallet'),
                ),
                BuyerDashboardQuickNavChip(
                  label: '↩️ Returns & Claims',
                  icon: Icons.assignment_return_outlined,
                  onTap: () => Navigator.pushNamed(context, '/buyer/returns'),
                ),
                BuyerDashboardQuickNavChip(
                  label: '💬 Help & QA',
                  icon: Icons.help_outline,
                  onTap: () => Navigator.pushNamed(context, '/buyer/chat-qa'),
                ),
                BuyerDashboardQuickNavChip(
                  label: '⭐️ Reviews',
                  icon: Icons.star_outline,
                  onTap: () => Navigator.pushNamed(context, '/buyer/reviews'),
                ),
                BuyerDashboardQuickNavChip(
                  label: '🎟️ Vouchers',
                  icon: Icons.confirmation_number_outlined,
                  onTap: () => Navigator.pushNamed(context, '/buyer/campaigns'),
                ),
                BuyerDashboardQuickNavChip(
                  label: '👑 Rewards',
                  icon: Icons.card_membership,
                  onTap: () => Navigator.pushNamed(context, '/buyer/rewards'),
                ),
                BuyerDashboardQuickNavChip(
                  label: '💖 Wishlist',
                  icon: Icons.favorite_border,
                  onTap: () => Navigator.pushNamed(context, '/buyer/wishlist'),
                ),
                BuyerDashboardQuickNavChip(
                  label: '🏢 B2B Wholesale',
                  icon: Icons.business_outlined,
                  onTap: () => Navigator.pushNamed(context, '/buyer/b2b-digital'),
                ),
                BuyerDashboardQuickNavChip(
                  label: '🤖 AI Copilot',
                  icon: Icons.smart_toy_outlined,
                  onTap: () => Navigator.pushNamed(context, '/buyer/ai-copilot'),
                ),
                BuyerDashboardQuickNavChip(
                  label: '🏬 Seller Landing',
                  icon: Icons.storefront_outlined,
                  onTap: () => Navigator.pushNamed(context, '/seller/landing'),
                ),
                BuyerDashboardQuickNavChip(
                  label: '👤 My Account',
                  icon: Icons.person_outline,
                  onTap: onAccountTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
