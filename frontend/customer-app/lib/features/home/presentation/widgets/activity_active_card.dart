import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'activity_active_card_booking_row.dart';
import 'activity_active_card_booking_panel_body.dart';
import 'activity_active_card_control.dart';

class ActivityActiveCard extends StatelessWidget {
  const ActivityActiveCard({super.key, required this.booking});
  final BookingModel booking;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('active_${booking.id}'),
      onTap: () => context.push('/bookings/${booking.id}/tracking'),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.compact),
        padding: const EdgeInsets.all(AppSpacing.comfortable),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            ActivityActiveCardBookingRow(booking: booking),
            const SizedBox(height: AppSpacing.inset),
            // Info row
            ActivityActiveCardBookingPanelBody(booking: booking),
            const SizedBox(height: AppSpacing.compact),
            // Theo dõi button
            ActivityActiveCardControl(
                onTrackBooking: () =>
                    context.push('/bookings/${booking.id}/tracking')),
          ],
        ),
      ),
    );
  }
}
