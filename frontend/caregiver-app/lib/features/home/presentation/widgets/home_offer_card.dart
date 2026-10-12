import 'package:caregiver_app/features/home/presentation/widgets/home_offer_details.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_offer_actions.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/home/presentation/widgets/pulse_card.dart';

class HomeOfferCard extends StatelessWidget {
  const HomeOfferCard(
      {super.key,
      required this.booking,
      required this.processingOfferId,
      required this.countdownLabel,
      required this.turnaroundWarning,
      required this.scheduledOrActiveShifts,
      required this.pendingCount,
      required this.offerLocationLabel,
      required this.formatPrice,
      required this.selectDeclineReason,
      required this.runOfferAction,
      required this.ref});
  final ShiftModel booking;
  final String? processingOfferId;
  final String? Function(Duration?) countdownLabel;
  final String? Function(ShiftModel, List<ShiftModel>) turnaroundWarning;
  final List<ShiftModel> scheduledOrActiveShifts;
  final int pendingCount;
  final String Function(ShiftModel) offerLocationLabel;
  final String Function(double) formatPrice;
  final Future<String?> Function(BuildContext) selectDeclineReason;
  final Future<void> Function(BuildContext, String,
      {required Future<void> Function() action,
      required String successMessage}) runOfferAction;
  final WidgetRef ref;
  @override
  Widget build(BuildContext context) {
    final note = booking.customerNote?.trim();
    final remaining = booking.offerExpiresAt?.difference(DateTime.now());
    final isExpired = remaining != null && remaining <= Duration.zero;
    final isProcessing = processingOfferId == booking.id;
    final countdownLabel = this.countdownLabel(remaining);
    final turnaroundWarning =
        this.turnaroundWarning(booking, scheduledOrActiveShifts);

    return PulseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Keep the informational InkWell separate from the action row below.
          // This prevents Reject/Accept taps from opening the booking detail.
          HomeOfferDetails(
              isExpired: isExpired,
              countdownLabel: countdownLabel,
              pendingCount: pendingCount,
              booking: booking,
              offerLocationLabel: offerLocationLabel,
              formatPrice: formatPrice,
              turnaroundWarning: turnaroundWarning,
              note: note,
              callbackAction2: () => context.push('/shifts/${booking.id}'),
              callbackAction3: () => context.go('/shifts')),

          // Buttons: Reject + Accept
          HomeOfferActions(
              isExpired: isExpired,
              isProcessing: isProcessing,
              runOfferAction: runOfferAction,
              booking: booking,
              callbackAction2: () async {
                final reason = await selectDeclineReason(context);
                if (reason == null || !context.mounted) return;
                await runOfferAction(
                  context,
                  booking.id,
                  successMessage:
                      'Đã từ chối ca. Hệ thống sẽ tìm người phù hợp khác.',
                  action: () => ref
                      .read(shiftsProvider.notifier)
                      .declineBooking(booking.id, reason: reason),
                );
              },
              callbackAction3: () =>
                  ref.read(shiftsProvider.notifier).acceptBooking(booking.id)),
        ],
      ),
    );
  }
}
