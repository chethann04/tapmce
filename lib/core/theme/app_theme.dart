import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'theme_extensions.dart';

class AppTheme {
  AppTheme._();

  // ── Light Theme Tokens ──────────────────────────────────────────────────
  static final lightBrandTheme = AppBrandTheme(
    brassPrimary: AppColors.lightBrass,
    brassSoft: AppColors.lightBrassSoft,
    brassA: AppColors.lightBrassA,
    brassB: AppColors.lightBrassB,
    onBrass: AppColors.lightOnBrass,
    roleAccent: AppColors.lightBrass,
    statusApplied: AppColors.lightBrass,
    statusShortlisted: AppColors.lightSuccess,
    statusRejected: AppColors.lightAlert,
    statusPending: AppColors.lightInfo,
    cardBorder: AppColors.lightBorder,
    surfaceAlt: AppColors.lightSurface2,
    textMuted: AppColors.lightInkMuted,
    dividerColor: AppColors.lightDivider,
    brassGradient: AppColors.lightBrassGradient,
    shadow1: AppColors.lightShadow1,
    shadow2: AppColors.lightShadow2,
    shadow3: AppColors.lightShadow3,
  );

  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme;
    final textTheme = GoogleFonts.interTextTheme(baseTextTheme).copyWith(
      displayLarge: GoogleFonts.fraunces(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: AppColors.lightInk,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.fraunces(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: AppColors.lightInk,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.lightInk,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.lightInk,
      ),
      labelSmall: GoogleFonts.ibmPlexMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.lightInkMuted,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightBrass,
        onPrimary: AppColors.lightOnBrass,
        surface: AppColors.lightSurface1,
        onSurface: AppColors.lightInk,
        surfaceContainerHighest: AppColors.lightSurface2,
        outline: AppColors.lightBorder,
      ),
      dividerColor: AppColors.lightDivider,
      scaffoldBackgroundColor: AppColors.lightBg,
      textTheme: textTheme,
      extensions: [lightBrandTheme],
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightSurface1,
        foregroundColor: AppColors.lightInk,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: AppColors.lightInk,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface2,
        hintStyle: GoogleFonts.inter(color: AppColors.lightInkMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
          borderSide: const BorderSide(color: AppColors.lightBrass, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
          borderSide: const BorderSide(color: AppColors.lightAlert),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
      ),
    );
  }

  // ── Dark Theme Tokens (Pure OLED #000000) ────────────────────────────────
  static final darkBrandTheme = AppBrandTheme(
    brassPrimary: AppColors.darkBrass,
    brassSoft: AppColors.darkBrassSoft,
    brassA: AppColors.darkBrassA,
    brassB: AppColors.darkBrassB,
    onBrass: AppColors.darkOnBrass,
    roleAccent: AppColors.darkBrass,
    statusApplied: AppColors.darkBrass,
    statusShortlisted: AppColors.darkSuccess,
    statusRejected: AppColors.darkAlert,
    statusPending: AppColors.darkInfo,
    cardBorder: AppColors.darkBorder,
    surfaceAlt: AppColors.darkSurface2,
    textMuted: AppColors.darkInkMuted,
    dividerColor: AppColors.darkDivider,
    brassGradient: AppColors.darkBrassGradient,
    shadow1: AppColors.darkShadow1,
    shadow2: AppColors.darkShadow2,
    shadow3: AppColors.darkShadow3,
  );

  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData.dark().textTheme;
    final textTheme = GoogleFonts.interTextTheme(baseTextTheme).copyWith(
      displayLarge: GoogleFonts.fraunces(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: AppColors.darkInk,
        letterSpacing: -0.5,
      ),
      headlineMedium: GoogleFonts.fraunces(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: AppColors.darkInk,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.darkInk,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.darkInk,
      ),
      labelSmall: GoogleFonts.ibmPlexMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.darkInkMuted,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkBrass,
        onPrimary: AppColors.darkOnBrass,
        surface: AppColors.darkSurface1, // Elevation 1 (#121316)
        onSurface: AppColors.darkInk,
        surfaceContainerHighest: AppColors.darkSurface2, // Elevation 2 (#1E2024)
        outline: AppColors.darkBorder,
      ),
      dividerColor: AppColors.darkDivider,
      scaffoldBackgroundColor: AppColors.darkBg, // Pure OLED Black #000000
      textTheme: textTheme,
      extensions: [darkBrandTheme],
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBg,
        foregroundColor: AppColors.darkInk,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: AppColors.darkInk,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface2,
        hintStyle: GoogleFonts.inter(color: AppColors.darkInkMuted, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
          borderSide: const BorderSide(color: AppColors.darkBrass, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusSmall),
          borderSide: const BorderSide(color: AppColors.darkAlert),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppShapes.radiusStandard),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
    );
  }
}
