import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/models/booking_status_presentation.dart';

class BookingListBookingCardStatusConfigBorderColorContent
    extends StatelessWidget {
  const BookingListBookingCardStatusConfigBorderColorContent(
      {super.key,
      required this.statusConfig,
      required this.borderColor,
      required this.formatCurrencyFull,
      required this.booking});
  final BookingStatusPresentation statusConfig;
  final Color borderColor;
  final String Function(double) formatCurrencyFull;
  final BookingModel booking;
  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.control, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: statusConfig.backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Text(
              statusConfig.label,
              style: TextStyle(
                  color: borderColor,
                  fontSize: AppFontSizes.s11,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            formatCurrencyFull(booking.totalPrice),
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: AppFontSizes.s15,
                fontWeight: FontWeight.w800),
          ),
        ],
      );
}
