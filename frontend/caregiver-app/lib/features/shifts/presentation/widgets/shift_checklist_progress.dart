import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftChecklistProgress extends StatelessWidget {
  const ShiftChecklistProgress(
      {super.key, required this.total, required this.completedCount});
  final int total;
  final int completedCount;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: LinearProgressIndicator(
                value: total > 0 ? completedCount / total : 0,
                backgroundColor: AppColors.border,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.control),
          Text('$completedCount/$total hoàn thành',
              style: const TextStyle(
                  fontSize: AppFontSizes.s12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ],
      );
}
