import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../models/activity_booking_status.dart';
import 'activity_recent_booking_summary.dart';
import 'activity_recent_booking_amount.dart';
import 'activity_recent_row_booking_panel.dart';

class ActivityRecentRow extends StatelessWidget {
  const ActivityRecentRow({super.key, required this.booking});
  final BookingModel booking;
  @override
  Widget build(BuildContext context) {
    final status = booking.presentationStatusAt(DateTime.now());
    final statusConfig = activityBookingStatus(status);
    final isCancelled = status == 'cancelled';

    return GestureDetector(
      onTap: () => context.push('/bookings/${booking.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.inset),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar icon
            ActivityRecentRowBookingPanel(booking: booking),
            const SizedBox(width: AppSpacing.inset),

            // Content
            ActivityRecentBookingSummary(
                isCancelled: isCancelled,
                booking: booking,
                status: status,
                onBookAgain: () => context.push('/booking/new')),

            // Price + status badge
            ActivityRecentBookingAmount(
                booking: booking, statusConfig: statusConfig),
          ],
        ),
      ),
    );
  }
}
