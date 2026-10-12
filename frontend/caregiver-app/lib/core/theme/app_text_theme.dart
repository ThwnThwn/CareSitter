import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_colors.dart';

/// Text theme dùng Be Vietnam Pro và helper tạo TextStyle.
abstract final class AppTextTheme {
  static TextTheme build() {
    return GoogleFonts.beVietnamProTextTheme(
      TextTheme(
        // display-lg: 32/700, -0.02em
        displayLarge: textStyle(32, AppColors.textPrimary,
            weight: FontWeight.w700, letterSpacing: -0.02 * 32),
        displayMedium: textStyle(28, AppColors.textPrimary,
            weight: FontWeight.w700, letterSpacing: -0.02 * 28),
        displaySmall: textStyle(24, AppColors.textPrimary,
            weight: FontWeight.w700, letterSpacing: -0.01 * 24),
        // headline-lg: 24/600, -0.01em
        headlineLarge: textStyle(24, AppColors.textPrimary,
            weight: FontWeight.w600, letterSpacing: -0.01 * 24),
        // headline-md: 20/600
        headlineMedium:
            textStyle(20, AppColors.textPrimary, weight: FontWeight.w600),
        // headline-sm: 18/600
        headlineSmall:
            textStyle(18, AppColors.textPrimary, weight: FontWeight.w600),
        // title-lg: 18/600
        titleLarge:
            textStyle(18, AppColors.textPrimary, weight: FontWeight.w600),
        // body-lg: 16/400
        titleMedium:
            textStyle(16, AppColors.textPrimary, weight: FontWeight.w600),
        titleSmall:
            textStyle(14, AppColors.textPrimary, weight: FontWeight.w600),
        bodyLarge: textStyle(16, AppColors.textPrimary),
        // body-md: 14/400
        bodyMedium: textStyle(14, AppColors.textPrimary),
        // body-sm: 12/400
        bodySmall: textStyle(12, AppColors.textSecondary),
        // label-lg: 15/600, 0.01em
        labelLarge: textStyle(15, AppColors.textPrimary,
            weight: FontWeight.w600, letterSpacing: 0.01 * 15),
        // label-md: 13/500
        labelMedium:
            textStyle(13, AppColors.textSecondary, weight: FontWeight.w500),
        // label-sm: 11/600, 0.02em
        labelSmall: textStyle(11, AppColors.textHint,
            weight: FontWeight.w600, letterSpacing: 0.02 * 11),
      ),
    );
  }

  /// Helper public — dùng được từ AppComponentThemes.input().
  static TextStyle textStyle(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height ?? 1.4,
      letterSpacing: letterSpacing,
    );
  }
}
