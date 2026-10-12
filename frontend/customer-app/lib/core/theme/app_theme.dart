import 'package:flutter/material.dart';

class AppColors {
  // Palette cũ được gom về đây để giữ nguyên màu khi refactor.
  static const Color legacyError = Color(0xFFE74C3C);
  static const Color legacyInfo = Color(0xFF2980B9);
  static const Color legacyInfoLight = Color(0xFFEBF5FB);
  static const Color purple = Color(0xFF8E44AD);
  static const Color purpleLight = Color(0xFFF4ECF7);
  static const Color blueDark = Color(0xFF0369A1);
  static const Color legacyErrorLight = Color(0xFFFDEDEC);
  static const Color softGreen = Color(0xFFE8F5F0);
  static const Color softOrange = Color(0xFFFFF3E8);
  static const Color brownOrange = Color(0xFFA85A16);
  static const Color softBlue = Color(0xFFE8F0FF);
  static const Color brightBlue = Color(0xFF2255CC);
  static const Color pinkLight = Color(0xFFFFF0F5);
  static const Color pinkDark = Color(0xFFB5226B);
  static const Color limeLight = Color(0xFFF0F8E8);
  static const Color limeDark = Color(0xFF4A7C1F);
  static const Color violetLight = Color(0xFFF5F0FF);
  static const Color violetDark = Color(0xFF6633BB);
  static const Color amberSurface = Color(0xFFFFF8E1);
  static const Color amberBorder = Color(0xFFFFCC80);
  static const Color amber = Color(0xFFFFB74D);
  static const Color amberText = Color(0xFF5D4037);
  static const Color amberLight = Color(0xFFFFE082);
  static const Color brown = Color(0xFF8D6E63);
  static const Color goldSurface = Color(0xFFFFFBF0);
  static const Color goldBorder = Color(0xFFFFE090);
  static const Color gold = Color(0xFFD4A012);
  static const Color goldDark = Color(0xFFB8860B);
  static const Color goldText = Color(0xFF7A5812);

  // Brand tokens shared with frontend/landing-page/src/app/globals.css.
  static const Color primary = Color(0xFF006B5B);
  static const Color primaryLight = Color(0xFF00806D);
  static const Color primaryDark = Color(0xFF004F43);
  static const Color accent = Color(0xFF00C896);
  static const Color primaryContainer = Color(0xFFE6F4F1);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = primary;

  static const Color secondary = Color(0xFFFF6B35);
  static const Color secondaryLight = Color(0xFFFFC4AE);
  static const Color secondaryContainer = Color(0xFFFFF0E8);
  static const Color secondaryStrong = Color(0xFFA43F16);
  static const Color onSecondary = Color(0xFF0D1117);

  static const Color background = Color(0xFFF5F3EE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = primaryContainer;
  static const Color cardBackground = surface;
  static const Color darkSurface = Color(0xFF0D1117);

  static const Color textPrimary = Color(0xFF0D1117);
  static const Color textSecondary = Color(0xFF536471);
  // Small labels and placeholders retain readable contrast on paper/mint.
  static const Color textHint = textSecondary;
  static const Color textOnDark = onPrimary;

  static const Color authBackground = background;
  static const Color authTextPrimary = textPrimary;
  static const Color authTextSecondary = textSecondary;
  static const Color authTextHint = textHint;
  static const Color authFieldBorder = border;
  static const Color authErrorSurface = Color(0xFFFEF2F2);
  static const Color authErrorBorder = Color(0xFFFCA5A5);

  // Semantic foregrounds remain dark enough to read on their light surfaces.
  static const Color success = primary;
  static const Color successLight = primaryContainer;
  static const Color warning = secondaryStrong;
  static const Color warningLight = secondaryContainer;
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF0284C7);
  static const Color infoLight = Color(0xFFE0F2FE);

  static const Color statusPending = warning;
  static const Color statusConfirmed = success;
  static const Color statusInProgress = primary;
  static const Color statusCompleted = success;
  static const Color statusCancelled = textSecondary;
  static const Color statusCrisis = error;
  static const Color statusDisputed = warning;

  static const Color border = Color(0xFFE2DDD5);
  static const Color borderFocus = primary;
  static const Color divider = border;
  static const Color shadow = Color(0x140D1117);
  static const Color scrim = Color(0x800D1117);

  // Existing gradient components use the shared teal family. The bright mint
  // accent is reserved for decoration, not backgrounds behind white text.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, primaryLight],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryContainer, background],
  );
}

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
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double hairline = 1;
  static const double micro = 2;
  static const double tiny = 3;
  static const double tight = 6;
  static const double control = 10;
  static const double compact = 12;
  static const double inset = 14;
  static const double comfortable = 18;
  static const double section = 20;
  static const double wide = 28;
  static const double hero = 64;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double control = 14;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double full = 100;
  static const double xs = 4;
  static const double tight = 6;
  static const double compact = 10;
}

class AppBreakpoints {
  static const double narrow = 340;
  static const double compact = 360;
  static const double medium = 600;
  static const double wideAuthLayout = 760;
  static const double wideAuthMinHeight = 600;
}

class AppLayout {
  static const double appContentMaxWidth = 720;
  static const double authFormMaxWidth = 520;
  static const double authHeroMinHeight = 220;
  static const double authPagePaddingCompact = AppSpacing.md;
  static const double authPagePadding = 20;
  static const double authPrimaryButtonMinHeight = 52;
  static const double authSecondaryButtonMinHeight = 50;
}

class AppShadows {
  static List<BoxShadow> get card => [
        const BoxShadow(
          color: AppColors.shadow,
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
        const BoxShadow(
          color: Color(0x08000000),
          blurRadius: 6,
          offset: Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get elevated => [
        const BoxShadow(
          color: Color(0x250D1117),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ];
}
