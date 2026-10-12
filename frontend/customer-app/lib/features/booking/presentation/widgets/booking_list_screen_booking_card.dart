import 'package:caresitter_customer/features/booking/presentation/widgets/booking_list_booking_card_border_color_status_config_panel.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/models/booking_status_presentation.dart';

class BookingListScreenBookingCard extends StatelessWidget {
  const BookingListScreenBookingCard(
      {super.key, required this.booking, required this.formatCurrencyFull});
  final BookingModel booking;
  final String Function(double) formatCurrencyFull;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = booking.presentationStatusAt(now);
    final statusConfig =
        BookingStatusPresentation.forBooking(booking, now: now);
    final isWaitingCaregiver = statusConfig.isWaitingCaregiver;
    final borderColor = statusConfig.color;

    return GestureDetector(
      onTap: () => context.push('/bookings/${booking.id}'),
      child: BookingListBookingCardBorderColorStatusConfigPanel(
          borderColor: borderColor,
          statusConfig: statusConfig,
          formatCurrencyFull: formatCurrencyFull,
          booking: booking,
          isWaitingCaregiver: isWaitingCaregiver,
          status: status,
          callbackAction2: () =>
              context.push('/bookings/${booking.id}/review')),
    );
  }
}
