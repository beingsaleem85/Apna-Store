import 'package:flutter/material.dart';

/// Centralized responsive breakpoint system for Apna Store.
/// Defines canonical viewport boundaries, justified exceptions, and layout helpers.
class AppBreakpoints {
  AppBreakpoints._();

  // Canonical Viewport Boundaries
  static const double mobileMax = 599.0;
  static const double tabletMin = 600.0;
  static const double tabletMax = 899.0;
  static const double desktopMin = 900.0;
  static const double desktopMax = 1199.0;
  static const double wideMin = 1200.0;

  // Justified Layout Exceptions
  /// Checkout desktop switch boundary (850px) to preserve distinct desktop checkout layout.
  static const double checkoutDesktopThreshold = 850.0;

  // Helper Methods
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < tabletMin;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tabletMin && width <= tabletMax;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopMin;

  static bool isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= wideMin;

  /// Returns safe, bounded dialog width for both mobile and desktop screens.
  static double getResponsiveDialogWidth(BuildContext context, {double defaultDesktopWidth = 580.0}) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < defaultDesktopWidth + 32.0) {
      return (screenWidth - 32.0).clamp(280.0, defaultDesktopWidth);
    }
    return defaultDesktopWidth;
  }

  /// Returns responsive product grid column count based on available width.
  static int getGridColumnCount(double width) {
    if (width >= wideMin) return 5;
    if (width >= desktopMin) return 4;
    if (width >= tabletMin) return 3;
    return 2;
  }
}
