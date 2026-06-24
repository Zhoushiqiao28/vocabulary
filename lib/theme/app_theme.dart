import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// v5.0 Design System — "Swiss Minimalist Workspace"
/// 
/// Design philosophy: Stripe × Vercel.
/// Focuses on structural grids, Inter typography, slate grays, and crisp accents.
class AppTheme {
  // ─── Background Scale ───
  static const Color background = Color(0xFF121214);
  static const Color surface = Color(0xFF1C1C1F);
  static const Color elevated = Color(0xFF26262B);
  static const Color hover = Color(0xFF2E2E35);

  // ─── Primary (Intelligent Blue) ───
  static const Color primary = Color(0xFF3569FD);

  // ─── Semantic Colors (Muted, professional) ───
  static const Color success = Color(0xFF10B981);   // Mastered
  static const Color error = Color(0xFFEF4444);     // Weak
  static const Color warning = Color(0xFFF59E0B);   // Favorite / Streak
  static const Color info = Color(0xFF3B82F6);      // Info

  // ─── Accent ───
  static const Color accent = Color(0xFF3569FD);

  // ─── Text Scale ───
  static const Color textPrimary = Color(0xFFECECED);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textMuted = Color(0xFF4A4A4F);

  // ─── Border ───
  static const double borderSubtleOpacity = 0.06;
  static const double borderMediumOpacity = 0.12;
  static const Color borderColor = Color(0xFF2E2E33);

  // ─── Backwards compatibility aliases ───
  static const Color secondary = info;
  static const Color cardBg = surface;

  // ─── Border Radius Tokens (Rigid, professional) ───
  static const double radiusSm = 4.0;
  static const double radiusMd = 6.0;
  static const double radiusLg = 8.0;
  static const double radiusFull = 9999.0;

  // ─── Opacity Tokens ───
  static const double opSubtle = 0.04;
  static const double opLight = 0.08;
  static const double opMedium = 0.15;
  static const double opStrong = 0.30;
  static const double opBold = 0.50;

  // ─── Shadow Presets (Soft, professional) ───
  static List<BoxShadow> get shadowCard => [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get shadowElevated => [
    BoxShadow(
      color: Colors.black.withOpacity(0.30),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // ─── Decoration Factories ───

  /// Standard panel decoration
  static BoxDecoration cardDecoration({
    Color? color,
    double radius = radiusMd,
    bool withShadow = false,
  }) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor,
        width: 1.0,
      ),
      boxShadow: withShadow ? shadowCard : null,
    );
  }

  /// Elevated panel decoration
  static BoxDecoration elevatedDecoration({
    double radius = radiusLg,
  }) {
    return BoxDecoration(
      color: elevated,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor,
        width: 1.0,
      ),
      boxShadow: shadowElevated,
    );
  }

  /// Chip / Badge decoration
  static BoxDecoration chipDecoration({
    required Color color,
    bool selected = false,
  }) {
    return BoxDecoration(
      color: color.withOpacity(selected ? opMedium : opLight),
      borderRadius: BorderRadius.circular(radiusSm),
      border: Border.all(
        color: color.withOpacity(selected ? opStrong : opMedium),
        width: 1.0,
      ),
    );
  }

  // ─── Theme Data ───
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32, fontWeight: FontWeight.bold,
          color: textPrimary, letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600,
          color: textPrimary, letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w400,
          color: textPrimary, height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 13, color: textSecondary, height: 1.4,
        ),
        labelSmall: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: textSecondary, letterSpacing: 0.8,
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
          side: const BorderSide(
            color: borderColor,
            width: 1.0,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimary, size: 20),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderColor),
          minimumSize: const Size(double.infinity, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        selectedColor: primary.withOpacity(opMedium),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: const BorderSide(color: borderColor),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      dividerColor: borderColor,
    );
  }
}
