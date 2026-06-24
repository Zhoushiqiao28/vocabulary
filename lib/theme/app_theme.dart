import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// v7.0 Design System — "Subtractive Premium"
///
/// Design principles:
/// - Memorization efficiency first, aesthetics serve function
/// - Single typeface (Outfit), hierarchy through weight/size only
/// - Indigo accent for primary actions, muted semantic colors
/// - Generous whitespace, 8px grid, modern radius (8-12px)
/// - No gimmicks: no VFD glow, no LED indicators, no hardware metaphors
class AppTheme {
  // ─── Background Scale ───
  static const Color background = Color(0xFF0C0C0E);
  static const Color surface = Color(0xFF161618);
  static const Color elevated = Color(0xFF1E1E22);
  static const Color hover = Color(0xFF242428);

  // ─── Accent ───
  static const Color primary = Color(0xFF6366F1);     // Indigo
  static const Color primaryMuted = Color(0xFF4F46E5); // Darker indigo for hover

  // ─── Semantic Status Colors ───
  static const Color success = Color(0xFF22C55E);  // Mastered
  static const Color error = Color(0xFFEF4444);    // Weak
  static const Color warning = Color(0xFFF59E0B);  // Due / Attention
  static const Color info = Color(0xFF3B82F6);     // Neutral info

  // ─── Text Scale ───
  static const Color textPrimary = Color(0xFFECECED);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textMuted = Color(0xFF48484A);

  // ─── Borders ───
  static const Color borderColor = Color(0xFF2A2A2E);

  // ─── Radius Tokens ───
  static const double radiusSm = 6.0;
  static const double radiusMd = 10.0;
  static const double radiusLg = 14.0;
  static const double radiusFull = 9999.0;

  // ─── Spacing (8px grid) ───
  static const double sp4 = 4.0;
  static const double sp8 = 8.0;
  static const double sp12 = 12.0;
  static const double sp16 = 16.0;
  static const double sp20 = 20.0;
  static const double sp24 = 24.0;
  static const double sp32 = 32.0;
  static const double sp48 = 48.0;

  // ─── Card Decoration ───
  static BoxDecoration cardDecoration({
    Color? color,
    double radius = radiusMd,
  }) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1.0),
    );
  }

  // ─── Elevated Decoration (modals, dropdowns) ───
  static BoxDecoration elevatedDecoration({
    double radius = radiusLg,
  }) {
    return BoxDecoration(
      color: elevated,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor, width: 1.0),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // ─── Status chip decoration ───
  static BoxDecoration statusChipDecoration({
    required Color color,
    bool filled = false,
  }) {
    return BoxDecoration(
      color: filled ? color.withOpacity(0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(radiusSm),
      border: Border.all(
        color: color.withOpacity(0.3),
        width: 1.0,
      ),
    );
  }

  // ─── Helper: status color from word status int ───
  static Color statusColor(int status) {
    switch (status) {
      case 1: return success;
      case 2: return error;
      default: return textSecondary;
    }
  }

  // ─── Helper: status label from word status int ───
  static String statusLabel(int status) {
    switch (status) {
      case 1: return '習得';
      case 2: return '苦手';
      default: return '未学習';
    }
  }

  // ─── Theme Data ───
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.outfitTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          fontSize: 42, fontWeight: FontWeight.w700,
          color: textPrimary, letterSpacing: -1.0, height: 1.1,
        ),
        displayMedium: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w600,
          color: textPrimary, letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w400,
          color: textPrimary, height: 1.6,
        ),
        bodyMedium: TextStyle(
          fontSize: 14, color: textSecondary, height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 13, color: textSecondary, height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: textPrimary, letterSpacing: 0.3,
        ),
        labelMedium: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500,
          color: textMuted,
        ),
      ),
    );

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: info,
        surface: surface,
        error: error,
      ),
      textTheme: baseTextTheme,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimary, size: 20),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: primary.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: const BorderSide(color: borderColor),
        ),
        labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      dividerColor: borderColor,
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: Color(0xFF1E1E22),
        linearMinHeight: 4,
      ),
    );
  }
}
