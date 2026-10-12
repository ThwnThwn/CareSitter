import 'package:caresitter_customer/features/home/presentation/widgets/activity_recent_row_booking_is_cancelled_inset.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ActivityRecentRow extends StatelessWidget {
  const ActivityRecentRow(
      {super.key,
      required this.booking,
      required this.getStatusConfig,
      required this.formatCurrency});
  final BookingModel booking;
  final Map<String, dynamic> Function(String) getStatusConfig;
  final String Function(double) formatCurrency;
  @override
  Widget build(BuildContext context) {
    final status = booking.presentationStatusAt(DateTime.now());
    final statusConfig = getStatusConfig(status);
    final isCancelled = status == 'cancelled';

    return GestureDetector(
      onTap: () => context.push('/bookings/${booking.id}'),
      child: ActivityRecentRowBookingIsCancelledInset(
          booking: booking,
          isCancelled: isCancelled,
          status: status,
          formatCurrency: formatCurrency,
          statusConfig: statusConfig,
          callbackAction2: () => context.push('/booking/new')),
    );
  }
}
