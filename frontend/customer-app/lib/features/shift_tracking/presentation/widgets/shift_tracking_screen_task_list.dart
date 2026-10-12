import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_task_list_content.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTrackingScreenTaskList extends StatelessWidget {
  const ShiftTrackingScreenTaskList(
      {super.key, required this.bk, required this.buildTaskRow});
  final BookingModel bk;
  final Widget Function(CareTaskModel, BookingModel, BuildContext) buildTaskRow;
  @override
  Widget build(BuildContext context) {
    final doneCount = bk.tasks.where((t) => t.isCompleted).length;
    final skippedCount = bk.tasks.where((t) => t.isSkipped).length;
    final allDone = bk.tasks.isNotEmpty && doneCount == bk.tasks.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: ShiftTrackingTaskListContent(
          skippedCount: skippedCount,
          allDone: allDone,
          doneCount: doneCount,
          bk: bk,
          buildTaskRow: buildTaskRow),
    );
  }
}
