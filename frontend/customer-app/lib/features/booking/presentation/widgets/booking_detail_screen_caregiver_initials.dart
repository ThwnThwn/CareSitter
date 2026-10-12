import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class BookingDetailScreenCaregiverInitials extends StatelessWidget {
  const BookingDetailScreenCaregiverInitials(
      {super.key, required this.booking});
  final BookingModel booking;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Center(
        child: Text(
          booking.caregiverInitials,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: AppFontSizes.s18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
