import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_radius.dart';
export 'app_colors.dart';
export 'app_spacing.dart';
export 'app_radius.dart';
export 'app_breakpoints.dart';
export 'app_layout.dart';
export 'app_shadows.dart';

class AppTheme {
  /// Tính 1 lần & cache — tránh dựng lại toàn bộ ThemeData mỗi lần MaterialApp rebuild.
  static final ThemeData lightTheme = _buildLightTheme();

  /// Form xác thực dùng chung bảng màu, giữ cấu trúc input riêng của luồng auth.
  static final InputDecorationTheme authInputDecorationTheme =
      _buildAuthInputDecorationTheme();

  static ThemeData _buildLightTheme() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
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
      textTheme: _buildTextTheme(),
      appBarTheme: _buildAppBarTheme(),
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      outlinedButtonTheme: _buildOutlinedButtonTheme(),
      textButtonTheme: _buildTextButtonTheme(),
      inputDecorationTheme: _buildInputDecorationTheme(),
      cardTheme: _buildCardTheme(),
      chipTheme: _buildChipTheme(),
      bottomNavigationBarTheme: _buildBottomNavTheme(),
      navigationBarTheme: _buildNavigationBarTheme(),
      tabBarTheme: _buildTabBarTheme(),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: _textStyle(14, Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle:
            _textStyle(18, AppColors.textPrimary, weight: FontWeight.w700),
        contentTextStyle: _textStyle(14, AppColors.textSecondary),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ── Text Theme ─────────────────────────────────────────
  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge:
          _textStyle(57, AppColors.textPrimary, weight: FontWeight.w700),
      displayMedium:
          _textStyle(45, AppColors.textPrimary, weight: FontWeight.w700),
      displaySmall:
          _textStyle(36, AppColors.textPrimary, weight: FontWeight.w700),
      headlineLarge:
          _textStyle(32, AppColors.textPrimary, weight: FontWeight.w700),
      headlineMedium:
          _textStyle(28, AppColors.textPrimary, weight: FontWeight.w700),
      headlineSmall:
          _textStyle(24, AppColors.textPrimary, weight: FontWeight.w600),
      titleLarge:
          _textStyle(22, AppColors.textPrimary, weight: FontWeight.w600),
      titleMedium:
          _textStyle(16, AppColors.textPrimary, weight: FontWeight.w600),
      titleSmall:
          _textStyle(14, AppColors.textPrimary, weight: FontWeight.w600),
      bodyLarge: _textStyle(16, AppColors.textPrimary),
      bodyMedium: _textStyle(14, AppColors.textPrimary),
      bodySmall: _textStyle(12, AppColors.textSecondary),
      labelLarge:
          _textStyle(14, AppColors.textPrimary, weight: FontWeight.w600),
      labelMedium:
          _textStyle(12, AppColors.textSecondary, weight: FontWeight.w500),
      labelSmall: _textStyle(11, AppColors.textHint, weight: FontWeight.w500),
    );
  }

  static TextStyle _textStyle(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
    double? height,
  }) {
    // Inter được bundle cục bộ (variable font) — không tải qua mạng.
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height ?? 1.4,
    );
  }

  // ── AppBar ─────────────────────────────────────────────
  static AppBarTheme _buildAppBarTheme() {
    return AppBarTheme(
      backgroundColor: AppColors.cardBackground,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: AppColors.shadow,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle:
          _textStyle(18, AppColors.textPrimary, weight: FontWeight.w600),
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),
    );
  }

  // ── Buttons ─────────────────────────────────────────────
  static ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.border,
        disabledForegroundColor: AppColors.textHint,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        minimumSize: const Size(double.infinity, 54),
        textStyle: _textStyle(16, Colors.white, weight: FontWeight.w700),
      ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        minimumSize: const Size(double.infinity, 54),
        textStyle: _textStyle(16, AppColors.primary, weight: FontWeight.w700),
      ),
    );
  }

  static TextButtonThemeData _buildTextButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: _textStyle(14, AppColors.primary, weight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Input ─────────────────────────────────────────────
  static InputDecorationTheme _buildInputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: _textStyle(14, AppColors.textHint),
      labelStyle: _textStyle(14, AppColors.textSecondary),
      floatingLabelStyle:
          _textStyle(12, AppColors.primary, weight: FontWeight.w500),
      prefixIconColor: AppColors.textSecondary,
      suffixIconColor: AppColors.textSecondary,
      errorStyle: _textStyle(12, AppColors.error),
    );
  }

  static InputDecorationTheme _buildAuthInputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.authFieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.authFieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      hintStyle: _textStyle(14, AppColors.authTextHint),
      labelStyle: _textStyle(14, AppColors.authTextSecondary),
      floatingLabelStyle:
          _textStyle(12, AppColors.primary, weight: FontWeight.w500),
      prefixIconColor: AppColors.primary,
      suffixIconColor: AppColors.authTextHint,
      errorStyle: _textStyle(12, AppColors.error),
    );
  }

  // ── Card ─────────────────────────────────────────────
  static CardThemeData _buildCardTheme() {
    return CardThemeData(
      color: AppColors.cardBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      margin: EdgeInsets.zero,
    );
  }

  // ── Chip ─────────────────────────────────────────────
  static ChipThemeData _buildChipTheme() {
    return ChipThemeData(
      backgroundColor: AppColors.surfaceVariant,
      selectedColor: AppColors.primaryContainer,
      labelStyle:
          _textStyle(12, AppColors.textSecondary, weight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      side: const BorderSide(color: AppColors.border),
    );
  }

  // ── Bottom Nav ─────────────────────────────────────────
  static BottomNavigationBarThemeData _buildBottomNavTheme() {
    return BottomNavigationBarThemeData(
      backgroundColor: AppColors.cardBackground,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textHint,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle:
          _textStyle(11, AppColors.primary, weight: FontWeight.w600),
      unselectedLabelStyle: _textStyle(11, AppColors.textHint),
    );
  }

  static NavigationBarThemeData _buildNavigationBarTheme() {
    return NavigationBarThemeData(
      backgroundColor: AppColors.cardBackground,
      indicatorColor: AppColors.primaryContainer,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return _textStyle(11, AppColors.primary, weight: FontWeight.w600);
        }
        return _textStyle(11, AppColors.textHint);
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primary, size: 24);
        }
        return const IconThemeData(color: AppColors.textHint, size: 24);
      }),
    );
  }

  // ── Tab Bar ─────────────────────────────────────────────
  static TabBarThemeData _buildTabBarTheme() {
    return TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textSecondary,
      labelStyle: _textStyle(14, AppColors.primary, weight: FontWeight.w600),
      unselectedLabelStyle: _textStyle(14, AppColors.textSecondary),
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: AppColors.primary, width: 3),
        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: AppColors.divider,
    );
  }
}

// ── Spacing / Radius Constants ────────────────────────────
