import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTrackingCareProgress extends StatelessWidget {
  const ShiftTrackingCareProgress(
      {super.key,
      required this.bk,
      required this.buildNeedsReviewBanner,
      required this.buildProgressStrip,
      required this.doneCount,
      required this.totalCount,
      required this.progressPct,
      required this.skippedCount,
      required this.buildTaskList,
      required this.ref,
      required this.buildFamilyNote});
  final BookingModel bk;
  final Widget Function(BuildContext, BookingModel) buildNeedsReviewBanner;
  final Widget Function(BookingModel, int, int, double, {int skippedCount})
      buildProgressStrip;
  final int doneCount;
  final int totalCount;
  final double progressPct;
  final int skippedCount;
  final Widget Function(BuildContext, WidgetRef, BookingModel) buildTaskList;
  final WidgetRef ref;
  final Widget Function(String) buildFamilyNote;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (bk.needsReview ||
                bk.tasks.any((t) => t.isRequired && t.isSkipped)) ...[
              buildNeedsReviewBanner(context, bk),
              const SizedBox(height: AppSpacing.inset),
            ],
            buildProgressStrip(bk, doneCount, totalCount, progressPct,
                skippedCount: skippedCount),
            const SizedBox(height: AppSpacing.inset),
            buildTaskList(context, ref, bk),
            const SizedBox(height: AppSpacing.inset),
            if (bk.beneficiaryNotes?.trim().isNotEmpty == true) ...[
              buildFamilyNote(bk.beneficiaryNotes!.trim()),
              const SizedBox(height: AppSpacing.inset),
            ],
          ]);
}
