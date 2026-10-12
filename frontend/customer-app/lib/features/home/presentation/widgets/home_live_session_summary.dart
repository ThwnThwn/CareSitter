import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';

class HomeLiveSessionSummary extends StatelessWidget {
  const HomeLiveSessionSummary(
      {super.key,
      required this.formatCurrency,
      required this.booking,
      required this.statusLabel,
      required this.accentColor});
  final String Function(double) formatCurrency;
  final BookingModel booking;
  final String statusLabel;
  final Color accentColor;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCurrency(booking.totalPrice),
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: AppFontSizes.s12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.tiny),
          Text(
            statusLabel,
            style: TextStyle(
              color: accentColor,
              fontSize: AppFontSizes.s9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
}
