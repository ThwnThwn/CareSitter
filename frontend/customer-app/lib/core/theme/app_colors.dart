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
