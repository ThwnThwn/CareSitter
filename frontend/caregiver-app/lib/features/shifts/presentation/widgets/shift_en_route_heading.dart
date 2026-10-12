import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftEnRouteHeading extends StatelessWidget {
  const ShiftEnRouteHeading({super.key});

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Icon(Icons.navigation_rounded, color: AppColors.warning, size: 20),
          SizedBox(width: AppSpacing.sm),
          Text('Đang trên đường đến',
              style: TextStyle(
                  fontSize: AppFontSizes.s15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warning)),
        ],
      );
}
