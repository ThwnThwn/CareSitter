import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_skipped_badge.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'shift_tracking_screen_task_row.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTrackingTaskListContent extends StatelessWidget {
  const ShiftTrackingTaskListContent(
      {super.key,
      required this.skippedCount,
      required this.allDone,
      required this.doneCount,
      required this.bk});
  final int skippedCount;
  final bool allDone;
  final int doneCount;
  final BookingModel bk;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Tiến độ chăm sóc',
                style: TextStyle(
                  fontSize: AppFontSizes.s14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (skippedCount > 0)
                ShiftTrackingSkippedBadge(skippedCount: skippedCount),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.control, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: allDone
                      ? AppColors.successLight
                      : AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '$doneCount/${bk.tasks.length}',
                  style: TextStyle(
                    color: allDone ? AppColors.success : AppColors.primary,
                    fontSize: AppFontSizes.s12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.compact),
          if (bk.tasks.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.lg, horizontal: AppSpacing.md),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.checklist_outlined,
                    size: 36,
                    color: AppColors.textHint.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Gói dịch vụ này chưa có checklist',
                    style: TextStyle(
                      color: AppColors.textHint,
                      fontSize: AppFontSizes.s13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            ...bk.tasks.map((task) => ShiftTrackingScreenTaskRow(task: task)),
        ],
      );
}
