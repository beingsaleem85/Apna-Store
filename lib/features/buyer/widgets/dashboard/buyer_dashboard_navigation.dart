import 'package:flutter/material.dart';

class BuyerDashboardFooterLinksCol extends StatelessWidget {
  final String title;
  final List<String> links;
  final Color linkColor;

  const BuyerDashboardFooterLinksCol({
    super.key,
    required this.title,
    required this.links,
    required this.linkColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...links.map((link) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {},
                child: Text(
                  link,
                  style: TextStyle(
                    color: linkColor,
                    fontSize: 14,
                    height: 1.2,
                  ),
                ),
              ),
            )),
      ],
    );
  }
}

class BuyerDashboardPremiumFooter extends StatelessWidget {
  final double screenWidth;

  const BuyerDashboardPremiumFooter({
    super.key,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    const footerBg = Color(0xFF0B5D50);
    const linkColor = Color(0xFFD1D5DB);

    return Container(
      color: footerBg,
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1680),
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
                          children: const [
                            Expanded(
                              child: BuyerDashboardFooterLinksCol(
                                title: 'Quick Links',
                                links: ['Home', 'Categories', 'Flash Sale', 'New Arrivals', 'Best Sellers', 'Contact Us'],
                                linkColor: linkColor,
                              ),
                            ),
                            SizedBox(width: 24),
                            Expanded(
                              child: BuyerDashboardFooterLinksCol(
                                title: 'Customer Service',
                                links: ['My Account', 'My Orders', 'Wishlist', 'Track Order', 'Return Policy', 'Refund Policy', 'FAQs'],
                                linkColor: linkColor,
                              ),
                            ),
                            SizedBox(width: 24),
                            Expanded(
                              child: BuyerDashboardFooterLinksCol(
                                title: 'Seller Center',
                                links: ['Become a Seller', 'Seller Dashboard', 'Seller Guidelines', 'Commission Policy', 'Seller Support'],
                                linkColor: linkColor,
                              ),
                            ),
                            SizedBox(width: 24),
                            Expanded(
                              child: BuyerDashboardFooterLinksCol(
                                title: 'Company',
                                links: ['About Us', 'Privacy Policy', 'Terms & Conditions', 'Careers', 'Blog'],
                                linkColor: linkColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        Divider(color: Colors.white.withOpacity(0.1), height: 1),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        BuyerDashboardFooterLinksCol(
                          title: 'Quick Links',
                          links: ['Home', 'Categories', 'Flash Sale', 'New Arrivals', 'Best Sellers', 'Contact Us'],
                          linkColor: linkColor,
                        ),
                        SizedBox(height: 32),
                        BuyerDashboardFooterLinksCol(
                          title: 'Customer Service',
                          links: ['My Account', 'My Orders', 'Wishlist', 'Track Order', 'Return Policy', 'Refund Policy', 'FAQs'],
                          linkColor: linkColor,
                        ),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 40),
              Center(
                child: Text(
                  '© 2026 Elegant Marketplace Multivendor. All rights reserved.',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
