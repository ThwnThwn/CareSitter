import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class CaregiverProfileScheduleSection extends StatelessWidget {
  const CaregiverProfileScheduleSection({super.key});

  @override
  Widget build(BuildContext context) {
    final days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final available = [true, true, true, true, true, true, false];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        return Column(
          children: [
            Text(days[i],
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AppFontSizes.s11)),
            const SizedBox(height: AppSpacing.tight),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: available[i]
                    ? AppColors.successLight
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                available[i] ? Icons.check : Icons.close,
                size: 16,
                color: available[i] ? AppColors.success : AppColors.textHint,
              ),
            ),
          ],
        );
      }),
    );
  }
}
