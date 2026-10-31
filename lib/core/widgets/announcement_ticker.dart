import 'dart:async';
import 'package:flutter/material.dart';

class AnnouncementTicker extends StatefulWidget implements PreferredSizeWidget {
  final List<String>? announcements;

  const AnnouncementTicker({super.key, this.announcements});

  @override
  Size get preferredSize => const Size.fromHeight(34.0);

  @override
  State<AnnouncementTicker> createState() => _AnnouncementTickerState();
}

class _AnnouncementTickerState extends State<AnnouncementTicker> {
  Timer? _scrollTimer;
  final ScrollController _scrollController = ScrollController();

  final List<String> _defaultAnnouncements = [
    '🚀 Welcome to Apna Store — Pakistan\'s Premier E-Commerce Marketplace!',
    '⚡ Flash Sale Live Now! Up to 50% OFF on Mobiles, Electronics & Fashion',
    '🚚 Free Shipping on Orders Above Rs. 1,999 | Cash on Delivery Nationwide',
    '🔒 100% Authentic Products Guaranteed | Easy 7-Day Return Policy',
    '🏪 Want to Sell on Apna Store? Register your store today & expand your business!',
  ];

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.announcements ?? _defaultAnnouncements;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: 32,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF047857)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final text = items[index % items.length];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Center(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
