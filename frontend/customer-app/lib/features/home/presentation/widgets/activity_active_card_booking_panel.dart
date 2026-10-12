import 'package:caresitter_customer/features/home/presentation/widgets/activity_active_card_booking_fields.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ActivityActiveCardBookingPanel extends StatelessWidget {
  const ActivityActiveCardBookingPanel(
      {super.key, required this.booking, required this.callbackAction1});
  final BookingModel booking;
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Container(
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
        child: ActivityActiveCardBookingFields(
            booking: booking, callbackAction1: callbackAction1),
      );
}
