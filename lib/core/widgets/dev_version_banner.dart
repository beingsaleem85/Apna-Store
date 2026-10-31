import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_version.dart';
import '../utils/web_helper.dart';

class DevVersionBanner extends StatefulWidget implements PreferredSizeWidget {
  const DevVersionBanner({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(34.0);

  @override
  State<DevVersionBanner> createState() => _DevVersionBannerState();
}

class _DevVersionBannerState extends State<DevVersionBanner> {
  bool _isVisible = true;
  bool _isAutoReloading = false;
  Timer? _pollerTimer;
  Timer? _scrollTimer;
  final ScrollController _scrollController = ScrollController();

  final List<String> _announcements = [
    '🚀 Welcome to Apna Store — Pakistan\'s Premier E-Commerce Marketplace!',
    '⚡ Flash Sale Live Now! Up to 50% OFF on Mobiles, Electronics & Fashion',
    '🚚 Free Shipping on Orders Above Rs. 1,999 | Cash on Delivery Nationwide',
    '🔒 100% Authentic Products Guaranteed | Easy 7-Day Return Policy',
    '🏪 Want to Sell on Apna Store? Register your store today & expand your business!',
  ];

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _startBuildPoller();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTickerScroll();
    });
  }

  void _startTickerScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 35), (_) {
      if (!mounted || !_scrollController.hasClients || !_scrollController.position.hasContentDimensions) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;
      final currentScroll = _scrollController.offset;
      if (currentScroll >= maxScroll - 1) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.jumpTo(currentScroll + 0.9);
      }
    });
  }

  void _startBuildPoller() {
    _pollerTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final isNewBuild = await WebHelper.checkForNewBuild(AppVersion.fullVersion);
      if (isNewBuild && mounted) {
        setState(() {
          _isAutoReloading = true;
        });
        Future.delayed(const Duration(milliseconds: 600), () {
          WebHelper.reloadWindow();
        });
      }
    });
  }

  @override
  void dispose() {
    _pollerTimer?.cancel();
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 32,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isAutoReloading
                ? [const Color(0xFFDC2626), const Color(0xFF991B1B)]
                : [const Color(0xFF0F172A), const Color(0xFF047857)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Scrolling Marquee Ticker (100% Full Opacity & Brightness)
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ..._buildAnnouncementItems(),
                    const SizedBox(width: 60),
                    ..._buildAnnouncementItems(), // Duplicated for smooth infinite scrolling loop
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAnnouncementItems() {
    final List<Widget> items = [];
    for (int i = 0; i < _announcements.length; i++) {
      items.add(
        Text(
          _announcements[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      );
      if (i < _announcements.length - 1) {
        items.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              '•',
              style: TextStyle(color: Color(0xFF34D399), fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    }
    return items;
  }
}
