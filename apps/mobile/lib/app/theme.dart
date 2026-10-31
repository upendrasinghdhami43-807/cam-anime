import 'package:flutter/material.dart';

/// Design tokens from docs/design/DESIGN.md §2.
abstract final class AppColors {
  static const bgBase = Color(0xFF0B0B10);
  static const bgSurface = Color(0xFF16161F);
  static const bgSurfaceRaised = Color(0xFF20202C);
  static const textPrimary = Color(0xFFF4F4F8);
  static const textSecondary = Color(0xFFB4B4C4);
  static const brandPrimary = Color(0xFFFF5C8A);
  static const brandSecondary = Color(0xFF7B5CFF);
  static const brandTertiary = Color(0xFF26D6C2);
  static const stateRecording = Color(0xFFFF3B30);
  static const stateWarning = Color(0xFFFFB020);
  static const stateError = Color(0xFFFF6B6B);
  static const onBrand = Color(0xFF0B0B10);
  static const outline = Color(0xFF34344A);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.brandPrimary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.brandPrimary,
        onPrimary: AppColors.onBrand,
        secondary: AppColors.brandSecondary,
        tertiary: AppColors.brandTertiary,
        surface: AppColors.bgSurface,
        onSurface: AppColors.textPrimary,
        error: AppColors.stateError,
        outline: AppColors.outline,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bgBase,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
      ),
    ),
  );
}
