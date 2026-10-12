import 'package:caresitter_customer/features/home/presentation/widgets/activity_active_card_booking_panel.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ActivityActiveCard extends StatelessWidget {
  const ActivityActiveCard({super.key, required this.booking});
  final BookingModel booking;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('active_${booking.id}'),
      onTap: () => context.push('/bookings/${booking.id}/tracking'),
      child: ActivityActiveCardBookingPanel(
          booking: booking,
          callbackAction1: () =>
              context.push('/bookings/${booking.id}/tracking')),
    );
  }
}
