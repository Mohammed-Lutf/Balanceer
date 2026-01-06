import 'package:flutter/material.dart';
// Local font defined in pubspec.yaml: Cairo

/// App Theme Configuration - Modern & Premium Design
class AppTheme {
  // Primary Colors
  static const Color primaryColor = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF8B85FF);
  static const Color primaryDark = Color(0xFF5046E5);

  // Secondary Colors
  static const Color secondaryColor = Color(0xFF00D9A5);
  static const Color secondaryLight = Color(0xFF5EEAD4);

  // Accent Colors
  static const Color accentRed = Color(0xFFFF6B6B);
  static const Color accentOrange = Color(0xFFF59E0B);
  static const Color accentBlue = Color(0xFF3B82F6);

  // Background & Surface Colors (Dark Mode)
  static const Color scaffoldBackground = Color(0xFF0F0F23);
  static const Color cardBackground = Color(0xFF1A1A2E);
  static const Color surfaceColor = Color(0xFF16213E);
  static const Color glassBg = Color(0x1AFFFFFF);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB4B4C4);
  static const Color textMuted = Color(0xFF6B7280);

  // Category Colors
  static const Map<String, Color> categoryColors = {
    'food': Color(0xFFFF6B6B),
    'transport': Color(0xFF4ECDC4),
    'entertainment': Color(0xFFA78BFA),
    'shopping': Color(0xFFF59E0B),
    'bills': Color(0xFF10B981),
    'health': Color(0xFFEC4899),
    'education': Color(0xFF3B82F6),
    'other': Color(0xFF6B7280),
  };

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF00D9A5), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;
  static const double radiusXL = 32.0;

  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> glowShadow = [
    BoxShadow(
      color: primaryColor.withValues(alpha: 0.3),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  // Theme Data
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scaffoldBackground,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: accentRed,
      ),
      fontFamily: 'Cairo',
      textTheme: const TextTheme(
        // Display - Cairo Bold
        displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 57),
        displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 45),
        displaySmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 36),
        // Headlines - Cairo Bold
        headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 32),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 28),
        headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 24),
        // Titles - Cairo SemiBold
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 22),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        titleSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
        // Body - Cairo Regular
        bodyLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w400, fontSize: 16),
        bodyMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w400, fontSize: 14),
        bodySmall: TextStyle(color: textSecondary, fontWeight: FontWeight.w400, fontSize: 12),
        // Labels - Cairo Medium
        labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
        labelMedium: TextStyle(color: textSecondary, fontWeight: FontWeight.w500, fontSize: 12),
        labelSmall: TextStyle(color: textMuted, fontWeight: FontWeight.w500, fontSize: 11),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: textSecondary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardBackground,
        selectedItemColor: primaryColor,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  // Glass Effect Decoration
  static BoxDecoration get glassDecoration => BoxDecoration(
    color: glassBg,
    borderRadius: BorderRadius.circular(radiusMedium),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.1),
    ),
    boxShadow: cardShadow,
  );
}
