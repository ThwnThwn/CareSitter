import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class HomeAppointmentServiceLabel extends StatelessWidget {
  const HomeAppointmentServiceLabel({super.key, required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: AppSpacing.micro),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Text(
                booking.serviceName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: AppFontSizes.s10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ]);
}
