import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors defined from Figma Plan
  static const Color background = Color(0xFFF8FAFC); // Slate 50 (cleaner white)
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLight = surface;

  static const Color primaryBlue = Color(0xFF5A49F8); // Vibrant Purple/Indigo from new design
  static const Color householdBlue = Color(0xFF6B7280); // Softer blue/grey for household
  static const Color towingOrange = Color(0xFFF59E0B); // Amber/Orange


  static const Color textSlateDark = Color(0xFF0F172A); // Slate 900
  static const Color textSlateMedium = Color(0xFF475569); // Slate 600
  static const Color textSlateLight = Color(0xFF64748B); // Slate 500

  // Status Colors
  static const Color statusPendingBg = Color(0xFFFEF3C7); // Amber 100
  static const Color statusPendingText = Color(0xFFD97706); // Amber 600
  static const Color statusAcceptedBg = Color(0xFFDBEAFE); // Blue 100
  static const Color statusAcceptedText = Color(0xFF2563EB); // Blue 600
  static const Color statusCompletedBg = Color(0xFFD1FAE5); // Emerald 100
  static const Color statusCompletedText = Color(0xFF059669); // Emerald 600
  static const Color statusInProgressBg = Color(0xFFE0E7FF); // Indigo 100
  static const Color statusInProgressText = Color(0xFF4338CA); // Indigo 700
  static const Color statusCancelledBg = Color(0xFFFEE2E2); // Red 100
  static const Color statusCancelledText = Color(0xFFDC2626); // Red 600

  // Dark Mode Colors
  static const Color backgroundDark = Color(0xFF0F172A); // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800
  static const Color textDarkPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color textDarkSecondary = Color(0xFF94A3B8); // Slate 400
  static const Color cardDark = surfaceDark;

  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.light,
        background: background,
        surface: surface,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: textSlateMedium,
        displayColor: textSlateDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textSlateDark),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: Brightness.dark,
        background: backgroundDark,
        surface: surfaceDark,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundDark,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: textDarkSecondary,
        displayColor: textDarkPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textDarkPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  // Common styles
  static InputDecoration textFieldDecoration({
    required String label,
    required IconData prefixIcon,
    required bool isDark,
    String? hint,
  }) {
    final baseColor = isDark ? Colors.white : textSlateDark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(prefixIcon, size: 20, color: baseColor.withValues(alpha: 0.5)),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: primaryBlue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: baseColor.withValues(alpha: 0.7), fontSize: 14),
    );
  }

  static BoxDecoration cardDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? surfaceDark : surface,
      borderRadius: BorderRadius.circular(24),
      border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.05)) : null,
      boxShadow: isDark
          ? []
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
    );
  }
}
