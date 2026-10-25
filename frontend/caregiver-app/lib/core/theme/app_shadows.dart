import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_colors.dart';

/// Shadow presets dùng chung toàn app.
class AppShadows {
  /// Low elevation used by dense list cards.
  static List<BoxShadow> get subtle => [
        const BoxShadow(
          color: AppColors.shadow,
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ];

  /// Level 1: Resting cards
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

  /// Level 2: Interactive floating items - elevated
  static List<BoxShadow> get elevated => [
        const BoxShadow(
          color: Color(0x250D1117),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ];

  /// Level 3: Bottom bar - upward shadow
  static List<BoxShadow> get bottomBar => [
        const BoxShadow(
          color: AppColors.shadow,
          blurRadius: 16,
          offset: Offset(0, -4),
        ),
      ];
}
