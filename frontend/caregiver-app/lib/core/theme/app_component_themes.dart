import 'package:caregiver_app/core/theme/app_spacing.dart';
import 'package:caregiver_app/core/theme/app_radius.dart';
import 'package:caregiver_app/core/theme/app_input_style.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_colors.dart';
import 'package:caregiver_app/core/theme/app_text_theme.dart';

/// Theme data của từng component (button, input, appbar, card, ...).
abstract final class AppComponentThemes {
  // ── AppBar ──
  static AppBarTheme appBar() {
    return const AppBarTheme(
      backgroundColor: AppColors.cardBackground,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.shadow,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: 'Inter',
        fontSize: AppFontSizes.s18,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary, size: 24),
    );
  }

  // ── Elevated Button ──
  static ElevatedButtonThemeData elevatedButton() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.border,
        disabledForegroundColor: AppColors.textHint,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control)),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        minimumSize: const Size(double.infinity, 52),
        textStyle: const TextStyle(fontFamily: 'Inter',
          fontSize: AppFontSizes.s16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Outlined Button ──
  static OutlinedButtonThemeData outlinedButton() {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control)),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        minimumSize: const Size(double.infinity, 52),
        textStyle: const TextStyle(fontFamily: 'Inter',
          fontSize: AppFontSizes.s16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Text Button ──
  static TextButtonThemeData textButton() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontFamily: 'Inter',
          fontSize: AppFontSizes.s14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    );
  }

  // ── Input ──
  static InputDecorationTheme input() {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppInputStyle.fillColor,
      border: AppInputStyle.enabledBorder,
      enabledBorder: AppInputStyle.enabledBorder,
      disabledBorder: AppInputStyle.enabledBorder,
      focusedBorder: AppInputStyle.focusedBorder,
      errorBorder: AppInputStyle.errorBorder,
      focusedErrorBorder: AppInputStyle.errorBorder,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.inset),
      hintStyle: AppTextTheme.textStyle(14, AppColors.textHint),
      labelStyle: AppTextTheme.textStyle(14, AppColors.textSecondary),
      floatingLabelStyle: AppTextTheme.textStyle(12, AppColors.primary,
          weight: FontWeight.w500),
      prefixIconColor: AppColors.textSecondary,
      suffixIconColor: AppColors.textSecondary,
      errorStyle: AppTextTheme.textStyle(12, AppColors.error),
    );
  }

  // ── Card ──
  static CardThemeData card() {
    return CardThemeData(
      color: AppColors.cardBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      margin: EdgeInsets.zero,
    );
  }

  // ── Chip ──
  static ChipThemeData chip() {
    return ChipThemeData(
      backgroundColor: AppColors.primaryContainer,
      selectedColor: AppColors.primaryContainer,
      labelStyle: const TextStyle(fontFamily: 'Inter',
        fontSize: AppFontSizes.s12,
        color: AppColors.onPrimaryContainer,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.compact, vertical: AppSpacing.tight),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        side: BorderSide.none,
      ),
      side: BorderSide.none,
    );
  }

  // ── Bottom Nav ──
  static BottomNavigationBarThemeData bottomNav() {
    return const BottomNavigationBarThemeData(
      backgroundColor: AppColors.cardBackground,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textHint,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: TextStyle(fontFamily: 'Inter',
        fontSize: AppFontSizes.s11,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      unselectedLabelStyle: TextStyle(fontFamily: 'Inter',
        fontSize: AppFontSizes.s11,
        color: AppColors.textHint,
      ),
    );
  }

  // ── Navigation Bar ──
  static NavigationBarThemeData navigationBar() {
    return NavigationBarThemeData(
      backgroundColor: AppColors.cardBackground,
      indicatorColor: AppColors.primaryContainer,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(fontFamily: 'Inter',
            fontSize: AppFontSizes.s11,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          );
        }
        return const TextStyle(fontFamily: 'Inter',
          fontSize: AppFontSizes.s11,
          color: AppColors.textHint,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primary, size: 24);
        }
        return const IconThemeData(color: AppColors.textHint, size: 24);
      }),
    );
  }

  // ── Tab Bar ──
  static TabBarThemeData tabBar() {
    return const TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textSecondary,
      labelStyle: TextStyle(fontFamily: 'Inter',
        fontSize: AppFontSizes.s14,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      unselectedLabelStyle: TextStyle(fontFamily: 'Inter',
        fontSize: AppFontSizes.s14,
        color: AppColors.textSecondary,
      ),
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: AppColors.primary, width: 3),
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.s2)),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: AppColors.divider,
    );
  }
}
