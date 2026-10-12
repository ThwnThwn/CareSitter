import 'package:flutter/material.dart';
import 'app_colors.dart';

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
