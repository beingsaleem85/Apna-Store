import 'package:flutter/material.dart';
import '../routes/app_routes.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  void _handleLinkTap(BuildContext context, String link) {
    switch (link) {
      case 'Home':
        Navigator.pushNamed(context, AppRoutes.home);
        break;
      case 'Categories':
        Navigator.pushNamed(context, AppRoutes.category);
        break;
      case 'My Account':
        Navigator.pushNamed(context, AppRoutes.buyerAccount);
        break;
      case 'My Orders':
        Navigator.pushNamed(context, AppRoutes.buyerOrders);
        break;
      case 'Wishlist':
        Navigator.pushNamed(context, AppRoutes.buyerWishlist);
        break;
      case 'Track Order':
        Navigator.pushNamed(context, AppRoutes.buyerOrderTracking);
        break;
      case 'Become a Seller':
      case 'Seller Dashboard':
        Navigator.pushNamed(context, AppRoutes.sellerDashboard);
        break;
      default:
        _showInfoDialog(context, link);
        break;
    }
  }

  void _showInfoDialog(BuildContext context, String title) {
    String description;
    switch (title) {
      case 'Privacy Policy':
        description = 'Apna Store respects your privacy. All customer data, KYC documents, and financial records are encrypted and protected under strict role-based access control and Pakistan data protection regulations.';
        break;
      case 'Terms & Conditions':
      case 'Terms':
        description = 'By using Apna Store, buyers and sellers agree to our marketplace fair trade terms, authentic product guidelines, and platform escrow policies.';
        break;
      case 'Return Policy':
        description = 'Enjoy a 7-day hassle-free return window for eligible products. Returns can be initiated directly from your My Orders dashboard.';
        break;
      case 'Refund Policy':
        description = 'Approved returns and cancellations are refunded back to your original payment method or wallet within 2-4 business days.';
        break;
      case 'Commission Policy':
        description = 'Apna Store charges standard commission take-rates per verified category, with automated ledger settlement upon delivery confirmation.';
        break;
      default:
        description = '$title is available and supported on Apna Store. Please contact our 24/7 support desk for specific inquiries.';
        break;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(description, style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF334155))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B5D50))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const footerBg = Color(0xFF0B5D50);
    const linkColor = Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      color: footerBg,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1440),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  if (screenWidth > 950) {
                    return Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildFooterLinksCol(context, 'Quick Links', [
                                'Home',
                                'Categories',
                                'Flash Sale',
                                'New Arrivals',
                                'Best Sellers',
                                'Contact Us'
                              ], linkColor),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildFooterLinksCol(context, 'Customer Service', [
                                'My Account',
                                'My Orders',
                                'Wishlist',
                                'Track Order',
                                'Return Policy',
                                'Refund Policy',
                                'FAQs'
                              ], linkColor),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildFooterLinksCol(context, 'Seller Center', [
                                'Become a Seller',
                                'Seller Dashboard',
                                'Seller Guidelines',
                                'Commission Policy',
                                'Seller Support'
                              ], linkColor),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _buildFooterLinksCol(context, 'Company', [
                                'About Us',
                                'Privacy Policy',
                                'Terms & Conditions',
                                'Careers',
                                'Blog'
                              ], linkColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        Divider(color: Colors.white.withOpacity(0.15), height: 1),
                        const SizedBox(height: 36),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Follow Us',
                                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildFollowUsWrap(context),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'We Accept',
                                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildPaymentsWrap(),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Download App',
                                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildDownloadAppSec(context),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Trusted & Secure',
                                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildSecurityBadgesWrap(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Follow Us', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildFollowUsWrap(context),
                        const Divider(color: Colors.white12, height: 36),
                        
                        _buildFooterLinksCol(context, 'Quick Links', ['Home', 'Categories', 'Flash Sale', 'New Arrivals', 'Contact Us'], linkColor),
                        const SizedBox(height: 20),
                        _buildFooterLinksCol(context, 'Customer Service', ['My Account', 'My Orders', 'Wishlist', 'Return Policy', 'FAQs'], linkColor),
                        const SizedBox(height: 20),
                        _buildFooterLinksCol(context, 'Seller Center', ['Become a Seller', 'Seller Dashboard', 'Seller Support'], linkColor),
                        const SizedBox(height: 20),
                        _buildFooterLinksCol(context, 'Company', ['About Us', 'Privacy Policy', 'Terms & Conditions', 'Careers', 'Blog'], linkColor),

                        const Divider(color: Colors.white12, height: 36),
                        const Text('We Accept', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildPaymentsWrap(),
                        
                        const Divider(color: Colors.white12, height: 36),
                        const Text('Download App', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildDownloadAppSec(context),

                        const Divider(color: Colors.white12, height: 36),
                        const Text('Trusted & Secure', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildSecurityBadgesWrap(),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 36),
              Divider(color: Colors.white.withOpacity(0.15), height: 1),
              const SizedBox(height: 24),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '© 2026 Apna Store. All Rights Reserved.',
                        style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                      ),
                      const SizedBox(width: 24),
                      const Text(
                        'Made with ❤️ in Pakistan',
                        style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 24),
                      Row(
                        children: ['Privacy Policy', 'Terms', 'Cookies'].map((term) => Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: InkWell(
                            onTap: () => _showInfoDialog(context, term),
                            child: Text(
                              term,
                              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, decoration: TextDecoration.underline),
                            ),
                          ),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLinksCol(BuildContext context, String title, List<String> links, Color linkColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        ...links.map((link) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: InkWell(
                onTap: () => _handleLinkTap(context, link),
                hoverColor: Colors.transparent,
                child: Text(
                  link,
                  style: TextStyle(color: linkColor, fontSize: 12, height: 1.4),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildFollowUsWrap(BuildContext context) {
    final List<Map<String, String>> socialIcons = [
      {'name': 'Facebook', 'url': 'https://img.icons8.com/color/48/facebook-new.png'},
      {'name': 'Instagram', 'url': 'https://img.icons8.com/color/48/instagram-new.png'},
      {'name': 'YouTube', 'url': 'https://img.icons8.com/color/48/youtube-play.png'},
      {'name': 'TikTok', 'url': 'https://img.icons8.com/color/48/tiktok.png'},
      {'name': 'WhatsApp', 'url': 'https://img.icons8.com/color/48/whatsapp.png'},
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: socialIcons.map((social) {
        bool isHovered = false;
        return StatefulBuilder(
          builder: (context, setStateHover) {
            return InkWell(
              onTap: () => _showInfoDialog(context, 'Apna Store ${social['name']}'),
              onHover: (hover) {
                setStateHover(() {
                  isHovered = hover;
                });
              },
              child: AnimatedScale(
                scale: isHovered ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isHovered ? Colors.white : Colors.white12,
                    shape: BoxShape.circle,
                  ),
                  child: Image.network(
                    social['url']!,
                    width: 16,
                    height: 16,
                    errorBuilder: (_, __, ___) => const Icon(Icons.share, color: Colors.white, size: 14),
                  ),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildPaymentsWrap() {
    final List<String> logoPaths = [
      'https://img.icons8.com/color/48/visa.png',
      'https://img.icons8.com/color/48/mastercard.png',
      'assets/images/paypak.png',
      'assets/images/jazzcash.png',
      'assets/images/easypaisa.png',
      'https://img.icons8.com/color/48/cash-on-delivery.png',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: logoPaths.map((path) {
        final isAsset = path.startsWith('assets/');
        return Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(5),
          child: ClipOval(
            child: isAsset
                ? Image.asset(
                    path,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.payment, color: Color(0xFF0F172A), size: 14),
                  )
                : Image.network(
                    path,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.credit_card, color: Color(0xFF0F172A), size: 14),
                  ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDownloadAppSec(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(4),
          child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF0F172A), size: 44),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => _showInfoDialog(context, 'Apna Store Google Play App'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('Google Play', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            InkWell(
              onTap: () => _showInfoDialog(context, 'Apna Store iOS App Store'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.apple_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('App Store', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityBadgesWrap() {
    final List<Map<String, dynamic>> badges = [
      {'name': 'SSL Lock', 'icon': Icons.lock_outline},
      {'name': 'Verified Shield', 'icon': Icons.verified_user_outlined},
      {'name': 'Money Back Guarantee', 'icon': Icons.shield_outlined},
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: badges.map((badge) {
        return Tooltip(
          message: badge['name'] as String,
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(6),
            child: Center(
              child: Icon(
                badge['icon'] as IconData,
                color: const Color(0xFF0B5D50),
                size: 18,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
