import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftMapDistanceSummary extends StatelessWidget {
  const ShiftMapDistanceSummary({super.key, required this.distanceLabel});
  final String? distanceLabel;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(
            Icons.directions_car_rounded,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'Thông tin di chuyển',
              style: TextStyle(
                fontSize: AppFontSizes.s16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (distanceLabel != null)
            Flexible(
              child: Text(
                distanceLabel!,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: AppFontSizes.s12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      );
}
