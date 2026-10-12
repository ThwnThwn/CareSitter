import 'package:caregiver_app/features/home/presentation/widgets/home_offer_heading.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_offer_service_time.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_offer_turnaround_warning.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_offer_queue_link.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_offer_note.dart';
import 'package:flutter/material.dart';
import 'home_offer_recipient_summary.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class HomeOfferDetails extends StatelessWidget {
  const HomeOfferDetails(
      {super.key,
      required this.isExpired,
      required this.countdownLabel,
      required this.pendingCount,
      required this.booking,
      required this.offerLocationLabel,
      required this.formatPrice,
      required this.turnaroundWarning,
      required this.note,
      required this.callbackAction2,
      required this.callbackAction3});
  final bool isExpired;
  final String? countdownLabel;
  final int pendingCount;
  final ShiftModel booking;
  final String Function(ShiftModel) offerLocationLabel;
  final String Function(double) formatPrice;
  final String? turnaroundWarning;
  final String? note;
  final void Function() callbackAction2;
  final void Function() callbackAction3;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: callbackAction2,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: notification + countdown
                HomeOfferHeading(
                    isExpired: isExpired, countdownLabel: countdownLabel),
                if (pendingCount > 1)
                  HomeOfferQueueLink(
                      pendingCount: pendingCount,
                      callbackAction1: callbackAction3),
                const SizedBox(height: AppSpacing.compact),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: AppSpacing.compact),

                // Service + Duration
                HomeOfferServiceTime(booking: booking),
                const SizedBox(height: AppSpacing.compact),

                // Recipient & Location
                HomeOfferRecipientSummary(
                    booking: booking,
                    offerLocationLabel: offerLocationLabel,
                    formatPrice: formatPrice),
                const SizedBox(height: AppSpacing.sm),

                if (turnaroundWarning != null) ...[
                  HomeOfferTurnaroundWarning(
                      turnaroundWarning: turnaroundWarning!),
                  const SizedBox(height: AppSpacing.compact),
                ],

                // Note
                HomeOfferNote(note: note),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      );
}
