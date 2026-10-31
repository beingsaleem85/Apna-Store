import 'package:flutter/material.dart';

class CampaignBannerCardWidget extends StatelessWidget {
  final String title;
  final String tag;
  final String subtitle;
  final String ctaText;
  final String imageUrl;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const CampaignBannerCardWidget({
    super.key,
    required this.title,
    required this.tag,
    required this.subtitle,
    required this.ctaText,
    required this.imageUrl,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 148,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                bottom: -10,
                top: -10,
                width: 140,
                child: Opacity(
                  opacity: 0.35,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: Colors.white10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ctaText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BuyerCampaignBannersGrid extends StatelessWidget {
  const BuyerCampaignBannersGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final banners = [
      {
        'title': 'Trending\nProducts',
        'tag': 'TOP DEALS',
        'subtitle': 'Up to 50% Off',
        'ctaText': 'Shop Now',
        'imageUrl': 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=400',
        'colors': [const Color(0xFF0F172A), const Color(0xFF1E293B), const Color(0xFF334155)],
        'category': 'Fashion',
      },
      {
        'title': 'Featured\nProducts',
        'tag': 'CURATED',
        'subtitle': 'Best Sellers',
        'ctaText': 'Discover',
        'imageUrl': 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400',
        'colors': [const Color(0xFF064E3B), const Color(0xFF0F766E), const Color(0xFF14B8A6)],
        'category': 'Electronics',
      },
      {
        'title': 'Seasonal\nCampaign',
        'tag': 'LIMITED',
        'subtitle': 'New Arrivals',
        'ctaText': 'Explore',
        'imageUrl': 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400',
        'colors': [const Color(0xFF14532D), const Color(0xFF16A34A), const Color(0xFF22C55E)],
        'category': 'Home',
      },
      {
        'title': 'Special\nOffers',
        'tag': 'HOT DEAL',
        'subtitle': 'Flash Savings',
        'ctaText': 'Grab Deal',
        'imageUrl': 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400',
        'colors': [const Color(0xFF881337), const Color(0xFFBE123C), const Color(0xFFE11D48)],
        'category': 'Sports',
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            children: banners.asMap().entries.map((entry) {
              final idx = entry.key;
              final banner = entry.value;
              final isLast = idx == banners.length - 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 14.0),
                  child: CampaignBannerCardWidget(
                    title: banner['title'] as String,
                    tag: banner['tag'] as String,
                    subtitle: banner['subtitle'] as String,
                    ctaText: banner['ctaText'] as String,
                    imageUrl: banner['imageUrl'] as String,
                    gradientColors: banner['colors'] as List<Color>,
                    onTap: () => Navigator.pushNamed(context, '/category', arguments: banner['category']),
                  ),
                ),
              );
            }).toList(),
          );
        } else if (constraints.maxWidth > 550) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              mainAxisExtent: 148,
            ),
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final banner = banners[index];
              return CampaignBannerCardWidget(
                title: banner['title'] as String,
                tag: banner['tag'] as String,
                subtitle: banner['subtitle'] as String,
                ctaText: banner['ctaText'] as String,
                imageUrl: banner['imageUrl'] as String,
                gradientColors: banner['colors'] as List<Color>,
                onTap: () => Navigator.pushNamed(context, '/category', arguments: banner['category']),
              );
            },
          );
        } else {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: banners.map((banner) {
                return Container(
                  width: 240,
                  margin: const EdgeInsets.only(right: 14),
                  child: CampaignBannerCardWidget(
                    title: banner['title'] as String,
                    tag: banner['tag'] as String,
                    subtitle: banner['subtitle'] as String,
                    ctaText: banner['ctaText'] as String,
                    imageUrl: banner['imageUrl'] as String,
                    gradientColors: banner['colors'] as List<Color>,
                    onTap: () => Navigator.pushNamed(context, '/category', arguments: banner['category']),
                  ),
                );
              }).toList(),
            ),
          );
        }
      },
    );
  }
}
