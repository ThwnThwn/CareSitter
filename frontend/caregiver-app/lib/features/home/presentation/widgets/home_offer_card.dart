import 'package:caregiver_app/features/home/presentation/widgets/home_offer_details.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_offer_actions.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/home/presentation/widgets/pulse_card.dart';
import '../models/home_offer_display_model.dart';

class HomeOfferCard extends ConsumerWidget {
  const HomeOfferCard(
      {super.key,
      required this.booking,
      required this.processingOfferId,
      required this.turnaroundWarning,
      required this.pendingCount,
      required this.selectDeclineReason,
      required this.runOfferAction});
  final ShiftModel booking;
  final String? processingOfferId;
  final String? turnaroundWarning;
  final int pendingCount;
  final Future<String?> Function(BuildContext) selectDeclineReason;
  final Future<void> Function(BuildContext, String,
      {required Future<void> Function() action,
      required String successMessage}) runOfferAction;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = booking.offerExpiresAt?.difference(DateTime.now());
    final isExpired = remaining != null && remaining <= Duration.zero;
    final isProcessing = processingOfferId == booking.id;
    final countdownLabel = HomeOfferDisplayModel.countdownLabel(remaining);

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
              turnaroundWarning: turnaroundWarning,
              onOpen: () => context.push('/shifts/${booking.id}'),
              onOpenQueue: () => context.go('/shifts')),

          // Buttons: Reject + Accept
          HomeOfferActions(
              isExpired: isExpired,
              isProcessing: isProcessing,
              onDecline: () async {
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
              onAccept: () => runOfferAction(context, booking.id,
                  successMessage: 'Đã nhận ca. Ca nằm trong lịch sắp tới.',
                  action: () => ref
                      .read(shiftsProvider.notifier)
                      .acceptBooking(booking.id))),
        ],
      ),
    );
  }
}
