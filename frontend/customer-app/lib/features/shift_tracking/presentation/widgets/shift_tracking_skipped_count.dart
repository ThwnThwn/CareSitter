import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ShiftTrackingSkippedCount extends StatelessWidget {
  const ShiftTrackingSkippedCount({super.key, required this.skippedCount});
  final int skippedCount;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.tiny),
            Text(
              '• $skippedCount việc không thực hiện được',
              style: const TextStyle(
                color: AppColors.amberLight,
                fontSize: AppFontSizes.s11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ]);
}
