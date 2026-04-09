import 'package:flutter/material.dart';

class StarpathColors {
  StarpathColors._();

  // Brand Gradient
  static const Color brandPurple = Color(0xFF6C63FF);
  static const Color brandBlue = Color(0xFF00D2FF);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [brandPurple, brandBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Emotion Spectrum
  static const LinearGradient joyGradient = LinearGradient(
    colors: [Color(0xFFFFD93D), Color(0xFFFF6B6B)],
  );
  static const LinearGradient calmGradient = LinearGradient(
    colors: [Color(0xFF6BCB77), Color(0xFF4D96FF)],
  );
  static const LinearGradient thinkingGradient = LinearGradient(
    colors: [Color(0xFF9B59B6), Color(0xFF6C63FF)],
  );
  static const LinearGradient excitedGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFF85A2)],
  );
  static const LinearGradient focusedGradient = LinearGradient(
    colors: [Color(0xFF4D96FF), Color(0xFF00D2FF)],
  );

  // Neutrals
  static const Color background = Color(0xFFFAFBFF);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1D26);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFFF1F3F9);

  // Functional
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Currency
  static const LinearGradient currencyGradient = LinearGradient(
    colors: [Color(0xFFFFD93D), Color(0xFFFF8C00)],
  );

  // Predefined companion color palettes
  static const List<List<Color>> companionPalettes = [
    [Color(0xFFFF6B6B), Color(0xFFFF8E53)], // Warm Coral
    [Color(0xFF6C63FF), Color(0xFF00D2FF)], // Brand Purple-Blue
    [Color(0xFF6BCB77), Color(0xFF4D96FF)], // Nature Green-Blue
    [Color(0xFFFF85A2), Color(0xFFFFAA85)], // Sakura
    [Color(0xFF9B59B6), Color(0xFFE74C8F)], // Mystic Purple-Pink
    [Color(0xFF00B4D8), Color(0xFF0077B6)], // Ocean Blue
    [Color(0xFFFFD93D), Color(0xFFFF6B6B)], // Sunshine
    [Color(0xFF48C9B0), Color(0xFF1ABC9C)], // Mint
    [Color(0xFFF39C12), Color(0xFFE74C3C)], // Autumn
    [Color(0xFF8E44AD), Color(0xFF3498DB)], // Galaxy
    [Color(0xFFE91E63), Color(0xFF9C27B0)], // Rose-Violet
    [Color(0xFF00BCD4), Color(0xFF4CAF50)], // Teal-Green
  ];
}

class StarpathTheme {
  StarpathTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: StarpathColors.background,
      colorScheme: ColorScheme.light(
        primary: StarpathColors.brandPurple,
        secondary: StarpathColors.brandBlue,
        surface: StarpathColors.cardWhite,
        error: StarpathColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: StarpathColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: StarpathColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: StarpathColors.cardWhite.withValues(alpha: 0.85),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: StarpathColors.cardWhite.withValues(alpha: 0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 0,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          height: 36 / 28,
          color: StarpathColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 30 / 22,
          color: StarpathColors.textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 24 / 17,
          color: StarpathColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.normal,
          height: 22 / 15,
          color: StarpathColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.normal,
          height: 18 / 13,
          color: StarpathColors.textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 14 / 11,
          color: StarpathColors.textTertiary,
        ),
      ),
    );
  }
}
