import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'shift_tracking_screen_needs_review_banner.dart';
import 'shift_tracking_screen_progress_strip.dart';
import 'shift_tracking_screen_task_list.dart';
import 'shift_tracking_screen_family_note.dart';

class ShiftTrackingCareProgress extends StatelessWidget {
  const ShiftTrackingCareProgress({super.key, required this.bk});
  final BookingModel bk;

  @override
  Widget build(BuildContext context) {
    final done = bk.tasks.where((task) => task.isCompleted).length;
    final skipped = bk.tasks.where((task) => task.isSkipped).length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bk.needsReview ||
            bk.tasks.any((task) => task.isRequired && task.isSkipped)) ...[
          ShiftTrackingScreenNeedsReviewBanner(bk: bk),
          const SizedBox(height: AppSpacing.inset),
        ],
        ShiftTrackingScreenProgressStrip(
            bk: bk,
            done: done,
            total: bk.tasks.length,
            skippedCount: skipped,
            pct: bk.tasks.isEmpty ? 0 : done / bk.tasks.length),
        const SizedBox(height: AppSpacing.inset),
        ShiftTrackingScreenTaskList(bk: bk),
        const SizedBox(height: AppSpacing.inset),
        if (bk.beneficiaryNotes?.trim().isNotEmpty == true) ...[
          ShiftTrackingScreenFamilyNote(note: bk.beneficiaryNotes!.trim()),
          const SizedBox(height: AppSpacing.inset),
        ],
      ],
    );
  }
}
