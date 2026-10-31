import 'package:flutter/material.dart';

class SuperAdminTheme {
  static const Color bgDark = Color(0xFFF1F5F9); // Light Gray Canvas (Matching Screenshots)
  static const Color cardDark = Color(0xFFFFFFFF); // Clean White Card Surface
  static const Color sidebarDark = Color(0xFF0B132B); // Deep Dark Navy Sidebar
  static const Color primaryTeal = Color(0xFF0F172A); // Primary Dark Accent
  static const Color secondaryGold = Color(0xFF10B981); // Vibrant Emerald Green Accent
  static const Color textLight = Color(0xFF0F172A); // Main Dark Text
  static const Color textMuted = Color(0xFF64748B); // Muted Secondary Gray Text
  static const Color borderDark = Color(0xFFE2E8F0); // Light Crisp Border Color

  static ThemeData get themeData {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: bgDark,
      cardColor: cardDark,
      primaryColor: primaryTeal,
      colorScheme: const ColorScheme.light(
        primary: primaryTeal,
        secondary: secondaryGold,
        surface: cardDark,
        background: bgDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        titleTextStyle: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold),
      ),
      dividerColor: borderDark,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textLight),
        bodyMedium: TextStyle(color: textLight),
        titleMedium: TextStyle(color: textLight, fontWeight: FontWeight.bold),
      ),
    );
  }
}
