import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ActivityRecentRowBookingPanel extends StatelessWidget {
  const ActivityRecentRowBookingPanel({super.key, required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Center(
          child: Text(
            booking.caregiverAvatar ?? booking.caregiverInitials,
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: AppFontSizes.s12,
                fontWeight: FontWeight.w700),
          ),
        ),
      );
}
