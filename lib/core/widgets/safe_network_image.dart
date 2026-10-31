import 'package:flutter/material.dart';

/// A robust network image widget that gracefully handles failed image loads,
/// null or empty URLs, and provides loading states.
class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = imageUrl?.trim() ?? '';

    Widget fallback() {
      return errorWidget ??
          Container(
            width: width,
            height: height,
            color: const Color(0xFFF1F5F9),
            alignment: Alignment.center,
            child: const Icon(
              Icons.image_not_supported_outlined,
              color: Color(0xFF94A3B8),
              size: 24,
            ),
          );
    }

    if (effectiveUrl.isEmpty) {
      return borderRadius != null
          ? ClipRRect(borderRadius: borderRadius!, child: fallback())
          : fallback();
    }

    final imageWidget = Image.network(
      effectiveUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ??
            Container(
              width: width,
              height: height,
              color: const Color(0xFFF8FAFC),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF004D40)),
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) => fallback(),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }

    return imageWidget;
  }
}
