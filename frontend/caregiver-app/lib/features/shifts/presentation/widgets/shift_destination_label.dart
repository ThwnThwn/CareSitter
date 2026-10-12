import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftDestinationLabel extends StatelessWidget {
  const ShiftDestinationLabel({super.key});

  @override
  Widget build(BuildContext context) => Positioned(
        top: 10,
        right: 10,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.control, vertical: AppSpacing.s5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_rounded,
                  size: 14, color: AppColors.primary),
              SizedBox(width: AppSpacing.xs),
              Text(
                'Địa điểm khách hàng',
                style: TextStyle(
                  fontSize: AppFontSizes.s11,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}
