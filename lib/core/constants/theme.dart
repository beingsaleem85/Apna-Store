import 'package:flutter/material.dart';

class AppTheme {
  // Premium light green & white theme colors
  static const Color background = Color(0xFFFFFFFF); // Pure White background
  static const Color cardBg = Color(0xFFFFFFFF); // Crisp White card containers
  static const Color primaryGreen = Color(0xFF004D40); // Deep Teal Green
  static const Color secondaryGold = Color(0xFFFDB913); // Gold accent
  static const Color darkText = Color(0xFF1E293B); // Deep Slate Black text
  static const Color lightText = Color(0xFF64748B); // Muted Slate Grey text

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryGreen,
      colorScheme: ColorScheme.light(
        primary: primaryGreen,
        secondary: secondaryGold,
        background: background,
        surface: cardBg,
      ),
      scaffoldBackgroundColor: background,
      cardColor: cardBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: primaryGreen),
        titleTextStyle: TextStyle(color: darkText, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: darkText),
        bodyMedium: TextStyle(color: lightText),
      ),
    );
  }
}
