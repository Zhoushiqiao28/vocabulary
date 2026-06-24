import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// v3.0 Design System — "Restrained Luxury"
/// 
/// Design philosophy: McLaren hospitality suite × Swiss watchmaking.
/// Consistency and restraint over decoration.
class AppTheme {
  // ─── Background Scale ───
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF141414);
  static const Color elevated = Color(0xFF1C1C1C);
  static const Color hover = Color(0xFF242424);

  // ─── Primary ───
  static const Color primary = Color(0xFFE10600);

  // ─── Semantic Colors ───
  static const Color success = Color(0xFF34D399);   // 正解・習得済み
  static const Color error = Color(0xFFF87171);      // 不正解・苦手
  static const Color warning = Color(0xFFFBBF24);    // ストリーク・お気に入り
  static const Color info = Color(0xFFA78BFA);       // AI・レベル

  // ─── Accent (use sparingly) ───
  static const Color accent = Color(0xFFCCFF00);

  // ─── Text Scale ───
  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFF3D3D3D);

  // ─── Border ───
  static const double borderSubtleOpacity = 0.05;
  static const double borderMediumOpacity = 0.10;

  // ─── Backwards compatibility aliases ───
  static const Color secondary = info;
  static const Color cardBg = surface;

  // ─── Border Radius Tokens (4 only) ───
  static const double radiusSm = 6.0;
  static const double radiusMd = 10.0;
  static const double radiusLg = 14.0;
  static const double radiusFull = 9999.0;

  // ─── Opacity Tokens (5 only) ───
  static const double opSubtle = 0.04;
  static const double opLight = 0.08;
  static const double opMedium = 0.15;
  static const double opStrong = 0.30;
  static const double opBold = 0.50;

  // ─── Shadow Presets ───
  static List<BoxShadow> get shadowCard => [
    BoxShadow(
      color: Colors.black.withOpacity(0.20),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get shadowElevated => [
    BoxShadow(
      color: Colors.black.withOpacity(0.40),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  // ─── Decoration Factories ───

  /// Standard card: flat surface, subtle border, light shadow.
  static BoxDecoration cardDecoration({
    Color? color,
    double radius = radiusMd,
    bool withShadow = true,
  }) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withOpacity(borderSubtleOpacity),
        width: 1,
      ),
      boxShadow: withShadow ? shadowCard : null,
    );
  }

  /// Accent-striped card: 3px left border accent for emphasis.
  /// Use with ClipRRect + Row([ accentStripe, content ]).
  static BoxDecoration accentCardDecoration({
    Color accentColor = primary,
    double radius = radiusMd,
  }) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withOpacity(borderSubtleOpacity),
        width: 1,
      ),
      boxShadow: shadowCard,
    );
  }

  /// Elevated surface: for dialogs, bottom sheets.
  static BoxDecoration elevatedDecoration({
    double radius = radiusLg,
  }) {
    return BoxDecoration(
      color: elevated,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withOpacity(borderSubtleOpacity),
        width: 1,
      ),
      boxShadow: shadowElevated,
    );
  }

  /// Chip / Badge decoration.
  static BoxDecoration chipDecoration({
    required Color color,
    bool selected = false,
  }) {
    return BoxDecoration(
      color: color.withOpacity(selected ? opMedium : opLight),
      borderRadius: BorderRadius.circular(radiusSm),
      border: Border.all(
        color: color.withOpacity(selected ? opStrong : opMedium),
        width: 1,
      ),
    );
  }

  // ─── Backwards compat: glassBoxDecoration ───
  static BoxDecoration glassBoxDecoration({
    required Color color,
    double borderRadius = radiusMd,
    double borderWidth = 1.0,
  }) {
    return cardDecoration(
      color: color.withOpacity(opLight),
      radius: borderRadius,
    );
  }

  // ─── Theme Data ───
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.outfitTextTheme(
      const TextTheme(
        // Display — large numbers
        displayLarge: TextStyle(
          fontSize: 36, fontWeight: FontWeight.w800,
          color: textPrimary, letterSpacing: -0.5,
        ),
        // Headline — section headers
        displayMedium: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700,
          color: textPrimary, letterSpacing: -0.3,
        ),
        // Title
        titleLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        // Body
        bodyLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w400,
          color: textPrimary, height: 1.5,
        ),
        // Caption
        bodyMedium: TextStyle(
          fontSize: 14, color: textSecondary, height: 1.4,
        ),
        // Small caption / labels
        labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500,
          color: textSecondary, letterSpacing: 0.5,
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
          side: BorderSide(
            color: Colors.white.withOpacity(borderSubtleOpacity),
            width: 1,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: Colors.white.withOpacity(borderMediumOpacity)),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: Colors.white.withOpacity(borderSubtleOpacity)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: Colors.white.withOpacity(borderSubtleOpacity)),
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
          side: BorderSide(color: Colors.white.withOpacity(borderSubtleOpacity)),
        ),
        labelStyle: GoogleFonts.outfit(fontSize: 12),
      ),
      dividerColor: Colors.white.withOpacity(borderSubtleOpacity),
    );
  }
}
