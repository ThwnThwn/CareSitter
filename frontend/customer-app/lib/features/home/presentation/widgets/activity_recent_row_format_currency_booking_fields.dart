import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class ActivityRecentRowFormatCurrencyBookingFields extends StatelessWidget {
  const ActivityRecentRowFormatCurrencyBookingFields(
      {super.key,
      required this.formatCurrency,
      required this.booking,
      required this.statusConfig});
  final String Function(double) formatCurrency;
  final BookingModel booking;
  final Map<String, dynamic> statusConfig;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatCurrency(booking.totalPrice),
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
              color: statusConfig['bg'] as Color,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              statusConfig['shortLabel'] as String,
              style: TextStyle(
                color: statusConfig['color'] as Color,
                fontSize: AppFontSizes.s10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
}
