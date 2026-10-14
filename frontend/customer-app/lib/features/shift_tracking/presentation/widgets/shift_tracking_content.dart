import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/data/models/booking_model.dart';
import '../controllers/shift_tracking_state.dart';
import 'shift_tracking_app_bar.dart';
import 'shift_tracking_bottom_action_bar.dart';
import 'shift_tracking_screen_map_section.dart';
import 'shift_tracking_screen_en_route_banner.dart';
import 'shift_tracking_screen_caregiver_card.dart';
import 'shift_tracking_care_progress.dart';
import 'shift_tracking_screen_info_row.dart';
import 'shift_tracking_screen_trust_guarantee_card.dart';
import 'shift_tracking_extend_button.dart';

class ShiftTrackingContent extends StatelessWidget {
  const ShiftTrackingContent(
      {super.key,
      required this.bk,
      required this.location,
      required this.onViewTimeline,
      required this.onExtendShift});
  final BookingModel bk;
  final ShiftTrackingState location;
  final VoidCallback onViewTimeline, onExtendShift;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: const ShiftTrackingAppBar(),
        bottomNavigationBar:
            ShiftTrackingBottomActionBar(bk: bk, bookingId: bk.id),
        body: SingleChildScrollView(
            child: Column(children: [
          ShiftTrackingScreenMapSection(bk: bk, location: location),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
            child: Column(children: [
              if (bk.status == 'caregiver_en_route') ...[
                ShiftTrackingScreenEnRouteBanner(bk: bk, location: location),
                const SizedBox(height: AppSpacing.inset),
              ],
              ShiftTrackingScreenCaregiverCard(bk: bk),
              const SizedBox(height: AppSpacing.inset),
              if (bk.status != 'caregiver_en_route')
                ShiftTrackingCareProgress(bk: bk),
              ShiftTrackingScreenInfoRow(bk: bk),
              const SizedBox(height: AppSpacing.inset),
              OutlinedButton.icon(
                onPressed: onViewTimeline,
                icon: const Icon(Icons.history_edu_outlined, size: 18),
                label: const Text('Xem nhật ký chăm sóc'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                  backgroundColor:
                      AppColors.successLight.withValues(alpha: 0.5),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control)),
                ),
              ),
              const SizedBox(height: AppSpacing.control),
              const ShiftTrackingScreenTrustGuaranteeCard(),
              if (bk.status == 'in_progress')
                ShiftTrackingExtendButton(onExtendShift: onExtendShift),
            ]),
          ),
        ])),
      );
}
