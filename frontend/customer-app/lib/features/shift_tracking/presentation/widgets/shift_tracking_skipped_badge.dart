import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ShiftTrackingSkippedBadge extends StatelessWidget {
  const ShiftTrackingSkippedBadge({super.key, required this.skippedCount});
  final int skippedCount;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.only(right: AppSpacing.tight),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.tiny),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.amber, width: 0.6),
              ),
              child: Text(
                '$skippedCount bỏ qua',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: AppFontSizes.s11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ]);
}
