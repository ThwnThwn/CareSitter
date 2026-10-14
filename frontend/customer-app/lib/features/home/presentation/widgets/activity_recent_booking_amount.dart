import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ActivityRecentBookingAmount extends StatelessWidget {
  const ActivityRecentBookingAmount(
      {super.key, required this.booking, required this.statusConfig});
  final BookingModel booking;
  final ({String label, Color foreground, Color background}) statusConfig;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatVnd(booking.totalPrice),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppFontSizes.s14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.tiny),
            decoration: BoxDecoration(
              color: statusConfig.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              statusConfig.label,
              style: TextStyle(
                color: statusConfig.foreground,
                fontSize: AppFontSizes.s10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
}
