import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// v6.0 Design System — "Tactile Hardware Console" (Teenage Engineering Style)
/// 
/// Design philosophy:
/// - Metal Dark Chassis (Background: 0xFF0F0F11, Module surface: 0xFF16161A)
/// - VFD Glass Screens (Background: 0xFF070708)
/// - LED indicators (Cyan: 0xFF00D2FF, Green: 0xFF00FF87, Red: 0xFFFF3B30, Yellow: 0xFFFFCC00)
/// - Monospace readout fonts (Share Tech Mono, Space Mono)
class AppTheme {
  // ─── Chassis / Metal Panel Scale ───
  static const Color background = Color(0xFF0F0F11); // Dark aluminum chassis
  static const Color surface = Color(0xFF16161A);    // Module panel plate
  static const Color elevated = Color(0xFF1E1E24);   // Slightly elevated module
  static const Color hover = Color(0xFF23232A);      // Hover highlight
  static const Color displayBg = Color(0xFF070708);  // VFD / LCD Glass screen backdrop

  // ─── LED / Active Light Scale ───
  static const Color primary = Color(0xFF00D2FF);    // VFD Cyan
  static const Color success = Color(0xFF00FF87);    // LED Green (Mastered)
  static const Color error = Color(0xFFFF3B30);      // LED Red (Weak)
  static const Color warning = Color(0xFFFFCC00);    // LED Yellow (Favorite / Streak)
  static const Color info = Color(0xFF00D2FF);       // LED Cyan (Info)
  static const Color secondary = info;

  // ─── Text / Monospace Readout Scale ───
  static const Color textPrimary = Color(0xFFE2E2E7);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textMuted = Color(0xFF48484A);

  // ─── Engraved Dividers ───
  static const Color borderColor = Color(0xFF26262B); // Engraved groove line
  static const Color borderGlow = Color(0x1F00D2FF);  // VFD glow leakage
  static const double borderSubtleOpacity = 0.08;
  static const double borderMediumOpacity = 0.15;

  // ─── Tactile Sharpness Radius ───
  static const double radiusSm = 2.0;
  static const double radiusMd = 3.0;
  static const double radiusLg = 4.0;
  static const double radiusFull = 9999.0;

  // ─── Opacity Tokens ───
  static const double opSubtle = 0.04;
  static const double opLight = 0.08;
  static const double opMedium = 0.18;
  static const double opStrong = 0.35;
  static const double opBold = 0.60;

  // ─── Chassis Engraving Border ───
  static Border get slitBorder => Border.all(
    color: borderColor,
    width: 1.0,
  );

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
    );
  }

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
    );
  }

  static BoxDecoration displayDecoration({
    double radius = radiusMd,
    bool glow = false,
  }) {
    return BoxDecoration(
      color: displayBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: glow ? primary.withOpacity(0.3) : borderColor,
        width: 1.0,
      ),
      boxShadow: glow ? [
        BoxShadow(
          color: primary.withOpacity(0.08),
          blurRadius: 8,
          spreadRadius: 1,
        )
      ] : null,
    );
  }

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

  // ─── Theme Data (Tactile Monospace VFD Theme) ───
  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.shareTechMonoTextTheme(
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
          fontSize: 14, fontWeight: FontWeight.w400,
          color: textPrimary, height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontSize: 13, color: textSecondary, height: 1.3,
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
        titleTextStyle: GoogleFonts.shareTechMono(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: 0.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: displayBg,
        hintStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: primary, width: 1.0),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: primary.withOpacity(opMedium),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: const BorderSide(color: borderColor),
        ),
        labelStyle: GoogleFonts.shareTechMono(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      dividerColor: borderColor,
    );
  }
}

/// A custom widget representing a tactile mechanical flat key button.
/// Features physically offset depth changes on tap, and an optional LED dot indicator.
class TactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? ledColor;
  final bool isLedOn;
  final double height;
  final double? width;
  final bool isPressedExternal; // Trigger state externally (e.g. keyboard shortcuts)

  const TactileButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.color,
    this.ledColor,
    this.isLedOn = false,
    this.height = 42.0,
    this.width,
    this.isPressedExternal = false,
  }) : super(key: key);

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> {
  bool _isPressedInternal = false;

  bool get _isCurrentlyPressed => widget.isPressedExternal || _isPressedInternal;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null) {
      setState(() => _isPressedInternal = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null) {
      setState(() => _isPressedInternal = false);
      widget.onPressed!();
    }
  }

  void _handleTapCancel() {
    setState(() => _isPressedInternal = false);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = widget.color ?? AppTheme.surface;
    final isEnabled = widget.onPressed != null;

    return GestureDetector(
      onTapDown: isEnabled ? _handleTapDown : null,
      onTapUp: isEnabled ? _handleTapUp : null,
      onTapCancel: isEnabled ? _handleTapCancel : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        curve: Curves.easeOut,
        height: widget.height,
        width: widget.width,
        margin: EdgeInsets.only(
          top: _isCurrentlyPressed ? 2.0 : 0.0,
          bottom: _isCurrentlyPressed ? 0.0 : 2.0,
        ),
        decoration: BoxDecoration(
          color: isEnabled ? themeColor : themeColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: AppTheme.borderColor,
            width: 1.0,
          ),
          boxShadow: _isCurrentlyPressed
              ? null
              : [
                  // Flat physical bottom depth border
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    offset: const Offset(0, 2.0),
                    blurRadius: 0,
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: widget.child,
            ),
            if (widget.ledColor != null)
              PositionPointLed(
                color: widget.ledColor!,
                isOn: widget.isLedOn,
              ),
          ],
        ),
      ),
    );
  }
}

/// A tiny point LED indicator inside a TactileButton
class PositionPointLed extends StatelessWidget {
  final Color color;
  final bool isOn;

  const PositionPointLed({
    Key? key,
    required this.color,
    required this.isOn,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 6,
      left: 6,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 5,
        height: 5,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOn ? color : color.withOpacity(0.15),
          boxShadow: isOn
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 3,
                    spreadRadius: 0.5,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
