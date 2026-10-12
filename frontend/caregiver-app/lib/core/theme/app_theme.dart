import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_radius.dart';
import 'package:flutter/material.dart';

// Re-export tokens để các file đang import app_theme.dart không phải sửa.
// Phase E sẽ gỡ dần các export này khi import được chuyển trực tiếp.
export 'package:caregiver_app/core/theme/app_colors.dart';
export 'package:caregiver_app/core/theme/app_spacing.dart';
export 'package:caregiver_app/core/theme/app_radius.dart';
export 'package:caregiver_app/core/theme/app_shadows.dart';

import 'package:caregiver_app/core/theme/app_colors.dart';
import 'package:caregiver_app/core/theme/app_text_theme.dart';
import 'package:caregiver_app/core/theme/app_component_themes.dart';

/// Theme chính của caregiver-app.
/// Tính 1 lần & cache — tránh dựng lại toàn bộ ThemeData mỗi lần rebuild.
class AppTheme {
  static final ThemeData lightTheme = _buildLightTheme();

  static ThemeData _buildLightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.secondaryStrong,
        tertiary: AppColors.primaryLight,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.primaryContainer,
        onTertiaryContainer: AppColors.primaryDark,
        error: AppColors.error,
        onError: Colors.white,
        errorContainer: AppColors.errorLight,
        onErrorContainer: Color(0xFF680000),
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceVariant,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.border,
        outlineVariant: AppColors.divider,
        shadow: AppColors.shadow,
        scrim: AppColors.scrim,
        inverseSurface: AppColors.textPrimary,
        onInverseSurface: Colors.white,
        inversePrimary: AppColors.primaryLight,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTextTheme.build(),
      appBarTheme: AppComponentThemes.appBar(),
      elevatedButtonTheme: AppComponentThemes.elevatedButton(),
      outlinedButtonTheme: AppComponentThemes.outlinedButton(),
      textButtonTheme: AppComponentThemes.textButton(),
      inputDecorationTheme: AppComponentThemes.input(),
      cardTheme: AppComponentThemes.card(),
      chipTheme: AppComponentThemes.chip(),
      bottomNavigationBarTheme: AppComponentThemes.bottomNav(),
      navigationBarTheme: AppComponentThemes.navigationBar(),
      tabBarTheme: AppComponentThemes.tabBar(),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
            fontSize: AppFontSizes.s14, color: Colors.white, height: 1.4),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        titleTextStyle: const TextStyle(
            fontSize: AppFontSizes.s18,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            height: 1.4),
        contentTextStyle: const TextStyle(
            fontSize: AppFontSizes.s14,
            color: AppColors.textSecondary,
            height: 1.4),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
    );
  }
}
