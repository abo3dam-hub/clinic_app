// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // ── Primary palette ──────────────────────────────────────────
  static const primary = Color(0xFF1A6B8A); // deep teal
  static const primaryLight = Color(0xFF2E8FAD);
  static const primaryDark = Color(0xFF0D4F68);
  static const primarySurface = Color(0xFFE8F4F8);

  // ── Secondary ────────────────────────────────────────────────
  static const secondary = Color(0xFF2CB67D); // emerald green
  static const secondaryLight = Color(0xFF3DD68C);
  static const secondarySurface = Color(0xFFE6F9F1);

  // ── Semantic ─────────────────────────────────────────────────
  static const error = Color(0xFFE53935);
  static const errorSurface = Color(0xFFFFEBEE);
  static const warning = Color(0xFFFB8C00);
  static const warningSurface = Color(0xFFFFF3E0);
  static const success = Color(0xFF2CB67D);
  static const successSurface = Color(0xFFE6F9F1);
  static const info = Color(0xFF1A6B8A);
  static const infoSurface = Color(0xFFE8F4F8);

  // ── Neutrals ─────────────────────────────────────────────────
  static const surface = Color(0xFFF7F9FC);
  static const surfaceCard = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const borderLight = Color(0xFFF1F5F9);
  static const textPrimary = Color(0xFF1A202C);
  static const textSecondary = Color(0xFF4A5568);
  static const textHint = Color(0xFFA0AEC0);
  static const divider = Color(0xFFEDF2F7);

  // ── Status chip colors ───────────────────────────────────────
  static const unpaid = Color(0xFFE53935);
  static const partial = Color(0xFFFB8C00);
  static const paid = Color(0xFF2CB67D);
  static const cancelled = Color(0xFFA0AEC0);
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static final BorderRadius card = BorderRadius.circular(md);
  static final BorderRadius button = BorderRadius.circular(sm);
  static final BorderRadius chip = BorderRadius.circular(xl);
  static final BorderRadius dialog = BorderRadius.circular(lg);
}

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x06000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> sidebar = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 20,
      offset: Offset(4, 0),
    ),
  ];
}

// ═══════════════════════════════════════════════════════════════
// Theme Definition
// ═══════════════════════════════════════════════════════════════

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: _appBarTheme,
      cardTheme: _cardTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      chipTheme: _chipTheme,
      dialogTheme: _dialogTheme,
      tooltipTheme: _tooltipTheme,
      snackBarTheme: _snackBarTheme,
      tabBarTheme: _tabBarTheme,
    );
  }

  // ── Text Theme ───────────────────────────────────────────────

  static TextTheme _buildTextTheme(TextTheme base) {
    final cairo = GoogleFonts.cairoTextTheme(base);
    return cairo.copyWith(
      displayLarge: cairo.displayLarge
          ?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      displayMedium: cairo.displayMedium
          ?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      displaySmall: cairo.displaySmall
          ?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      headlineLarge: cairo.headlineLarge
          ?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
      headlineMedium: cairo.headlineMedium
          ?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      headlineSmall: cairo.headlineSmall
          ?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      titleLarge: cairo.titleLarge
          ?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      titleMedium: cairo.titleMedium
          ?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
      titleSmall: cairo.titleSmall?.copyWith(
          color: AppColors.textSecondary, fontWeight: FontWeight.w500),
      bodyLarge: cairo.bodyLarge?.copyWith(color: AppColors.textPrimary),
      bodyMedium: cairo.bodyMedium?.copyWith(color: AppColors.textSecondary),
      bodySmall: cairo.bodySmall?.copyWith(color: AppColors.textHint),
      labelLarge: cairo.labelLarge
          ?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────

  static const AppBarTheme _appBarTheme = AppBarTheme(
    backgroundColor: AppColors.surfaceCard,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 1,
    shadowColor: Color(0x14000000),
    iconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
    titleTextStyle: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
  );

  // ── Card ─────────────────────────────────────────────────────

  static final CardThemeData _cardTheme = CardThemeData(
    color: AppColors.surfaceCard,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.card,
      side: const BorderSide(color: AppColors.border, width: 1),
    ),
    margin: EdgeInsets.zero,
  );

  // ── Buttons ──────────────────────────────────────────────────

  static final ElevatedButtonThemeData _elevatedButtonTheme =
      ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
  );

  static final OutlinedButtonThemeData _outlinedButtonTheme =
      OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary,
      side: const BorderSide(color: AppColors.primary, width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  );

  static final TextButtonThemeData _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  );

  // ── Input ────────────────────────────────────────────────────

  static final InputDecorationTheme _inputDecorationTheme =
      InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceCard,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: AppRadius.card,
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.card,
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.card,
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: AppRadius.card,
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: AppRadius.card,
      borderSide: const BorderSide(color: AppColors.error, width: 2),
    ),
    labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
    errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
  );

  // ── Chip ─────────────────────────────────────────────────────

  static final ChipThemeData _chipTheme = ChipThemeData(
    backgroundColor: AppColors.borderLight,
    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
    side: BorderSide.none,
  );

  // ── Dialog ───────────────────────────────────────────────────

  static final DialogThemeData _dialogTheme = DialogThemeData(
    backgroundColor: AppColors.surfaceCard,
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
    titleTextStyle: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
  );

  // ── Tooltip ──────────────────────────────────────────────────

  static const TooltipThemeData _tooltipTheme = TooltipThemeData(
    decoration: BoxDecoration(
      color: AppColors.textPrimary,
      borderRadius: BorderRadius.all(Radius.circular(6)),
    ),
    textStyle: TextStyle(color: Colors.white, fontSize: 12),
  );

  // ── SnackBar ─────────────────────────────────────────────────

  static final SnackBarThemeData _snackBarTheme = SnackBarThemeData(
    backgroundColor: AppColors.textPrimary,
    contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    behavior: SnackBarBehavior.floating,
  );

  // ── Tab Bar ──────────────────────────────────────────────────

  static const TabBarThemeData _tabBarTheme = TabBarThemeData(
    labelColor: AppColors.primary,
    unselectedLabelColor: AppColors.textSecondary,
    indicatorColor: AppColors.primary,
    labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    unselectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  );
}
