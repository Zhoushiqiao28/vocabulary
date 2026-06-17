import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color Palette
  static const Color background = Color(0xFF0F0F12); // 超ディープチャコール
  static const Color surface = Color(0xFF1A1A22);    // 少し明るいダークグレー
  static const Color primary = Color(0xFF8A2BE2);    // ネオンバイオレット
  static const Color secondary = Color(0xFF00F5D4);  // ネオンティール（エメラルド）
  static const Color accent = Color(0xFFFF007F);     // ネオンピンク（AI解説などのアクセント）
  static const Color textPrimary = Color(0xFFF8F9FA);  // ほぼ白
  static const Color textSecondary = Color(0xFF9E9EAF); // グレー
  static const Color cardBg = Color(0xFF1F1F2E);       // カード背景

  // Glassmorphic / Premium Border Decorator
  static BoxDecoration glassBoxDecoration({
    required Color color,
    double borderRadius = 16.0,
    double borderWidth = 1.0,
  }) {
    return BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: color.withOpacity(0.2),
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.05),
          blurRadius: 10,
          spreadRadius: 2,
        ),
      ],
    );
  }

  // Dark Theme Definition
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: Colors.redAccent,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary),
          displayMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
          bodyLarge: TextStyle(fontSize: 16, color: textPrimary, height: 1.5),
          bodyMedium: TextStyle(fontSize: 14, color: textSecondary, height: 1.4),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
      ),
    );
  }
}
