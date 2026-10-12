import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_care_progress.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_extend_button.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/controllers/shift_tracking_state.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/shift_tracking_bottom_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ShiftTrackingContent extends StatelessWidget {
  const ShiftTrackingContent(
      {super.key,
      required this.buildFloatingAppBar,
      required this.bk,
      required this.bookingId,
      required this.buildMapSection,
      required this.location,
      required this.buildEnRouteBanner,
      required this.buildCaregiverCard,
      required this.buildNeedsReviewBanner,
      required this.buildProgressStrip,
      required this.doneCount,
      required this.totalCount,
      required this.progressPct,
      required this.skippedCount,
      required this.buildTaskList,
      required this.ref,
      required this.buildFamilyNote,
      required this.buildInfoRow,
      required this.buildTrustGuaranteeCard,
      required this.action1,
      required this.action2});
  final PreferredSizeWidget Function(BuildContext) buildFloatingAppBar;
  final BookingModel bk;
  final String bookingId;
  final Widget Function(BookingModel, ShiftTrackingState) buildMapSection;
  final ShiftTrackingState location;
  final Widget Function(BookingModel, ShiftTrackingState) buildEnRouteBanner;
  final Widget Function(BuildContext, BookingModel) buildCaregiverCard;
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
  final Widget Function(BookingModel) buildInfoRow;
  final Widget Function() buildTrustGuaranteeCard;
  final void Function() action1;
  final void Function() action2;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: buildFloatingAppBar(context),
        bottomNavigationBar:
            ShiftTrackingBottomActionBar(bk: bk, bookingId: bookingId),
        body: SingleChildScrollView(
          child: Column(
            children: [
              buildMapSection(bk, location),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
                child: Column(
                  children: [
                    if (bk.status == 'caregiver_en_route') ...[
                      buildEnRouteBanner(bk, location),
                      const SizedBox(height: AppSpacing.inset),
                    ],
                    buildCaregiverCard(context, bk),
                    const SizedBox(height: AppSpacing.inset),
                    if (bk.status != 'caregiver_en_route')
                      ShiftTrackingCareProgress(
                          bk: bk,
                          buildNeedsReviewBanner: buildNeedsReviewBanner,
                          buildProgressStrip: buildProgressStrip,
                          doneCount: doneCount,
                          totalCount: totalCount,
                          progressPct: progressPct,
                          skippedCount: skippedCount,
                          buildTaskList: buildTaskList,
                          ref: ref,
                          buildFamilyNote: buildFamilyNote),
                    buildInfoRow(bk),
                    const SizedBox(height: AppSpacing.inset),
                    OutlinedButton.icon(
                      onPressed: action1,
                      icon: const Icon(Icons.history_edu_outlined, size: 18),
                      label: const Text('Xem nhật ký chăm sóc'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                            color: AppColors.primary, width: 1.2),
                        backgroundColor:
                            AppColors.successLight.withValues(alpha: 0.5),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.control)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.control),
                    buildTrustGuaranteeCard(),
                    if (bk.status == 'in_progress')
                      ShiftTrackingExtendButton(action2: action2),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
