import '../models/payment_result_presentation.dart';
import 'package:caresitter_customer/features/booking/presentation/widgets/payment_result_payment_result_content_details_booking_id_fields.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/booking/domain/payment_outcome.dart';

class PaymentResultPaymentResultContent extends StatelessWidget {
  const PaymentResultPaymentResultContent(
      {super.key,
      required this.state,
      required this.bookingId,
      required this.onOpenBooking,
      required this.onOpenBookings,
      required this.onRetry,
      required this.refreshing});

  final PaymentOutcome state;
  final String? bookingId;
  final VoidCallback? onOpenBooking;
  final VoidCallback onOpenBookings;
  final VoidCallback? onRetry;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final details = PaymentResultPresentation.details(state);
    final isFailure = state == PaymentOutcome.failure;
    final isSyncing = state == PaymentOutcome.syncing;

    return Semantics(
      liveRegion: true,
      child: PaymentResultPaymentResultContentDetailsBookingIdFields(
          details: details,
          bookingId: bookingId,
          isSyncing: isSyncing,
          onOpenBooking: onOpenBooking,
          isFailure: isFailure,
          refreshing: refreshing,
          onRetry: onRetry,
          onOpenBookings: onOpenBookings),
    );
  }
}
