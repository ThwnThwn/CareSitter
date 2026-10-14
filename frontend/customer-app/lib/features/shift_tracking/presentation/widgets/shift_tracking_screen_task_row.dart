import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_task_row_content.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTrackingScreenTaskRow extends StatelessWidget {
  const ShiftTrackingScreenTaskRow({super.key, required this.task});
  final CareTaskModel task;
  @override
  Widget build(BuildContext context) {
    final isDone = task.isCompleted;
    final isSkipped = task.isSkipped;

    Color itemBg = AppColors.surfaceVariant.withValues(alpha: 0.3);
    Color borderColor = AppColors.border.withValues(alpha: 0.6);
    if (isDone) {
      itemBg = AppColors.successLight.withValues(alpha: 0.4);
      borderColor = AppColors.success.withValues(alpha: 0.25);
    } else if (isSkipped) {
      itemBg = AppColors.amberSurface.withValues(alpha: 0.7);
      borderColor = AppColors.amberBorder.withValues(alpha: 0.5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.control),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.compact, vertical: AppSpacing.control),
      decoration: BoxDecoration(
        color: itemBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child:
          ShiftTaskRowContent(isDone: isDone, isSkipped: isSkipped, task: task),
    );
  }
}
