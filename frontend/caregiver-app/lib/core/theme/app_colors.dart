import 'package:flutter/material.dart';

/// Bảng màu chủ đạo của caregiver-app.
/// Shared brand tokens khớp với customer-app, admin-web, landing-page.
class AppColors {
  // ── Brand tokens shared with customer-app, admin-web, and landing-page ──
  static const Color primary = Color(0xFF006B5B);
  static const Color primaryLight = Color(0xFF00806D);
  static const Color primaryDark = Color(0xFF004F43);
  static const Color accent = Color(0xFF00C896);
  static const Color primaryContainer = Color(0xFFE6F4F1);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = primary;

  // ── Secondary / Warm Coral Companion ──
  static const Color secondary = Color(0xFFFF6B35);
  static const Color secondaryLight = Color(0xFFFFC4AE);
  static const Color secondaryContainer = Color(0xFFFFF0E8);
  static const Color secondaryStrong = Color(0xFFA43F16);
  static const Color onSecondary = Color(0xFF0D1117);

  // ── Tertiary (compatible with caregiver components) ──
  static const Color tertiary = secondary;
  static const Color tertiaryContainer = secondaryContainer;

  // ── Surfaces ──
  /// Shared cool off-white canvas used by customer-app.
  static const Color background = Color(0xFFF6F9F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = primaryContainer;
  static const Color surfaceContainer = Color(0xFFFAF8F5);
  static const Color surfaceContainerLow = Color(0xFFFFFFFF);
  static const Color surfaceContainerHigh = Color(0xFFEDE8E1);
  static const Color cardBackground = surface;
  static const Color darkSurface = Color(0xFF0D1117);

  // ── Text ──
  static const Color textPrimary = Color(0xFF0D1117);
  static const Color textSecondary = Color(0xFF536471);
  static const Color textHint = textSecondary;
  static const Color textOnDark = onPrimary;

  // ── Auth Specific tokens ──
  static const Color authBackground = background;
  static const Color authTextPrimary = textPrimary;
  static const Color authTextSecondary = textSecondary;
  static const Color authTextHint = textHint;
  static const Color authFieldBorder = border;
  static const Color authErrorSurface = Color(0xFFFEF2F2);
  static const Color authErrorBorder = Color(0xFFFCA5A5);

  // ── Semantic & State Colors ──
  static const Color success = primary;
  static const Color successLight = primaryContainer;
  static const Color warning = secondaryStrong;
  static const Color warningLight = secondaryContainer;
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF0284C7);
  static const Color infoLight = Color(0xFFE0F2FE);

  // ── Shift / Booking Status Colors (Stitch Semantic aligned with Customer app) ──
  static const Color statusPending = warning;
  static const Color statusPendingBg = warningLight;
  static const Color statusConfirmed = success;
  static const Color statusConfirmedBg = successLight;
  static const Color statusInProgress = primary;
  static const Color statusInProgressBg = primaryContainer;
  static const Color statusCompleted = success;
  static const Color statusCompletedBg = successLight;
  static const Color statusCancelled = textSecondary;
  static const Color statusCancelledBg = Color(0xFFEDE8E1);
  static const Color statusCrisis = error;
  static const Color statusCrisisBg = errorLight;
  static const Color statusDisputed = warning;

  // ── Border / Divider ──
  static const Color border = Color(0xFFE2DDD5);
  static const Color borderFocus = primary;
  static const Color divider = border;
  static const Color shadow = Color(0x140D1117);
  static const Color scrim = Color(0x800D1117);

  // ── Gradient (Shared teal family) ──
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
