import 'package:flutter/material.dart';

class AppTheme {
  // Apple-inspired color palette
  static const Color background = Color(0xFF000000);
  static const Color secondaryBg = Color(0xFF1C1C1E);
  static const Color tertiaryBg = Color(0xFF2C2C2E);
  static const Color groupedBg = Color(0xFF1C1C1E);

  static const Color accent = Color(0xFF0A84FF);      // iOS Blue
  static const Color accentGreen = Color(0xFF30D158);  // iOS Green
  static const Color accentOrange = Color(0xFFFF9F0A); // iOS Orange
  static const Color accentRed = Color(0xFFFF453A);    // iOS Red
  static const Color accentPurple = Color(0xFFBF5AF2); // iOS Purple
  static const Color accentTeal = Color(0xFF64D2FF);   // iOS Teal
  static const Color accentPink = Color(0xFFFF375F);   // iOS Pink

  static const Color label = Color(0xFFFFFFFF);
  static const Color secondaryLabel = Color(0xFF8E8E93);
  static const Color tertiaryLabel = Color(0xFF48484A);
  static const Color separator = Color(0xFF38383A);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentTeal,
        surface: secondaryBg,
        error: accentRed,
      ),
      cardTheme: CardThemeData(
        color: secondaryBg,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tertiaryBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerColor: separator,
      useMaterial3: true,
    );
  }
}
