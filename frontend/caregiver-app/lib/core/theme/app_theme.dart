import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ── Primary Botanical Green Palette ─────────────────────
  static const Color primary = Color(0xFF2D9E6B);
  static const Color primaryLight = Color(0xFF4FBF8A);
  static const Color primaryDark = Color(0xFF1E7A52);
  static const Color primaryContainer = Color(0xFFE8F7F0);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF1E7A52);

  // ── Secondary / Teal Companion ──────────────────────────
  static const Color secondary = Color(0xFF00B4A0);
  static const Color secondaryLight = Color(0xFF4FDCC6);
  static const Color secondaryContainer = Color(0xFFE0F9F5);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // ── Tertiary / Amber Warning ────────────────────────────
  static const Color tertiary = Color(0xFFF5A623);
  static const Color tertiaryContainer = Color(0xFFFEF7EC);

  // ── Surfaces ───────────────────────────────────────────
  static const Color background = Color(0xFFF0F4F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE8F7F0);
  static const Color surfaceContainer = Color(0xFFF5FAF7);
  static const Color surfaceContainerLow = Color(0xFFF7FBF9);
  static const Color surfaceContainerHigh = Color(0xFFE8F0EB);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // ── Text ───────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A2E25);
  static const Color textSecondary = Color(0xFF5A7268);
  static const Color textHint = Color(0xFF9FB8AC);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // ── State Colors ───────────────────────────────────────
  static const Color success = Color(0xFF059669);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF0284C7);
  static const Color infoLight = Color(0xFFE0F2FE);

  // ── Booking Status Colors (Stitch Semantic) ────────────
  static const Color statusPending = Color(0xFFD97706);
  static const Color statusPendingBg = Color(0xFFFEF3C7);
  static const Color statusConfirmed = Color(0xFF16A34A);
  static const Color statusConfirmedBg = Color(0xFFDCFCE7);
  static const Color statusInProgress = Color(0xFF005F56);
  static const Color statusInProgressBg = Color(0xFFE6F4F2);
  static const Color statusCompleted = Color(0xFF059669);
  static const Color statusCompletedBg = Color(0xFFD1FAE5);
  static const Color statusCancelled = Color(0xFF64748B);
  static const Color statusCancelledBg = Color(0xFFF1F5F9);
  static const Color statusCrisis = Color(0xFFDC2626);
  static const Color statusCrisisBg = Color(0xFFFEE2E2);
  static const Color statusDisputed = Color(0xFFE67E22);

  // ── Border / Divider ───────────────────────────────────
  static const Color border = Color(0xFFDDE8E3);
  static const Color borderFocus = Color(0xFF2D9E6B);
  static const Color divider = Color(0xFFEDF5EF);

  // ── Gradient ───────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2D9E6B), Color(0xFF4FBF8A)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E7A52), Color(0xFF2D9E6B), Color(0xFF4FBF8A)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8F7F0), Color(0xFFF5FAF7)],
  );
}

class AppTheme {
  /// Tính 1 lần & cache — tránh dựng lại toàn bộ ThemeData mỗi lần MaterialApp rebuild.
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
        onSecondaryContainer: Color(0xFF005047),
        tertiary: AppColors.tertiary,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: Color(0xFF633F00),
        error: AppColors.error,
        onError: Colors.white,
        errorContainer: AppColors.errorLight,
        onErrorContainer: Color(0xFF8B0000),
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceContainerHigh,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.border,
        outlineVariant: AppColors.divider,
        shadow: Color(0x1A1A2E25),
        scrim: Color(0x801A2E25),
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

  // ── Text Theme (Be Vietnam Pro via google_fonts) ────────
  static TextTheme _buildTextTheme() {
    return GoogleFonts.beVietnamProTextTheme(
      TextTheme(
        // display-lg: 32/700, -0.02em
        displayLarge:
            _textStyle(32, AppColors.textPrimary, weight: FontWeight.w700, letterSpacing: -0.02 * 32),
        displayMedium:
            _textStyle(28, AppColors.textPrimary, weight: FontWeight.w700, letterSpacing: -0.02 * 28),
        displaySmall:
            _textStyle(24, AppColors.textPrimary, weight: FontWeight.w700, letterSpacing: -0.01 * 24),
        // headline-lg: 24/600, -0.01em
        headlineLarge:
            _textStyle(24, AppColors.textPrimary, weight: FontWeight.w600, letterSpacing: -0.01 * 24),
        // headline-md: 20/600
        headlineMedium:
            _textStyle(20, AppColors.textPrimary, weight: FontWeight.w600),
        // headline-sm: 18/600
        headlineSmall:
            _textStyle(18, AppColors.textPrimary, weight: FontWeight.w600),
        // title-lg: 18/600
        titleLarge:
            _textStyle(18, AppColors.textPrimary, weight: FontWeight.w600),
        // body-lg: 16/400
        titleMedium:
            _textStyle(16, AppColors.textPrimary, weight: FontWeight.w600),
        titleSmall:
            _textStyle(14, AppColors.textPrimary, weight: FontWeight.w600),
        bodyLarge: _textStyle(16, AppColors.textPrimary),
        // body-md: 14/400
        bodyMedium: _textStyle(14, AppColors.textPrimary),
        // body-sm: 12/400
        bodySmall: _textStyle(12, AppColors.textSecondary),
        // label-lg: 15/600, 0.01em
        labelLarge:
            _textStyle(15, AppColors.textPrimary, weight: FontWeight.w600, letterSpacing: 0.01 * 15),
        // label-md: 13/500
        labelMedium:
            _textStyle(13, AppColors.textSecondary, weight: FontWeight.w500),
        // label-sm: 11/600, 0.02em
        labelSmall:
            _textStyle(11, AppColors.textHint, weight: FontWeight.w600, letterSpacing: 0.02 * 11),
      ),
    );
  }

  static TextStyle _textStyle(
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

  // ── AppBar ─────────────────────────────────────────────
  static AppBarTheme _buildAppBarTheme() {
    return AppBarTheme(
      backgroundColor: AppColors.cardBackground,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: const Color(0x0A1A2E25),
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: GoogleFonts.beVietnamPro(
        fontSize: 18,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        minimumSize: const Size(double.infinity, 52),
        textStyle: GoogleFonts.beVietnamPro(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        minimumSize: const Size(double.infinity, 52),
        textStyle: GoogleFonts.beVietnamPro(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static TextButtonThemeData _buildTextButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: GoogleFonts.beVietnamPro(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Input ─────────────────────────────────────────────
  static InputDecorationTheme _buildInputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
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

  // ── Card ─────────────────────────────────────────────
  static CardThemeData _buildCardTheme() {
    return CardThemeData(
      color: AppColors.cardBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      margin: EdgeInsets.zero,
    );
  }

  // ── Chip ─────────────────────────────────────────────
  static ChipThemeData _buildChipTheme() {
    return ChipThemeData(
      backgroundColor: AppColors.primaryContainer,
      selectedColor: AppColors.primaryContainer,
      labelStyle: GoogleFonts.beVietnamPro(
        fontSize: 12,
        color: AppColors.onPrimaryContainer,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide.none,
      ),
      side: BorderSide.none,
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
      selectedLabelStyle: GoogleFonts.beVietnamPro(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      unselectedLabelStyle: GoogleFonts.beVietnamPro(
        fontSize: 11,
        color: AppColors.textHint,
      ),
    );
  }

  static NavigationBarThemeData _buildNavigationBarTheme() {
    return NavigationBarThemeData(
      backgroundColor: AppColors.cardBackground,
      indicatorColor: AppColors.primaryContainer,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.beVietnamPro(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          );
        }
        return GoogleFonts.beVietnamPro(
          fontSize: 11,
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

  // ── Tab Bar ─────────────────────────────────────────────
  static TabBarThemeData _buildTabBarTheme() {
    return TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textSecondary,
      labelStyle: GoogleFonts.beVietnamPro(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      unselectedLabelStyle: GoogleFonts.beVietnamPro(
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
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
class AppSpacing {
  static const double xxs = 4;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double full = 100;
}

class AppShadows {
  /// Level 1: Resting cards — green-tinted ambient shadow
  static List<BoxShadow> get card => [
        BoxShadow(
          color: const Color(0xFF1A2E25).withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
          spreadRadius: -2,
        ),
      ];

  /// Level 2: Interactive floating items — elevated green-tinted
  static List<BoxShadow> get elevated => [
        BoxShadow(
          color: const Color(0xFF1A2E25).withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
      ];

  /// Level 3: Bottom bar — upward shadow
  static List<BoxShadow> get bottomBar => [
        BoxShadow(
          color: const Color(0xFF1A2E25).withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, -4),
        ),
      ];
}
