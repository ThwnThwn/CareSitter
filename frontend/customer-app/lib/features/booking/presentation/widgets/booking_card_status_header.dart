import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/models/booking_status_presentation.dart';

class BookingCardStatusHeader extends StatelessWidget {
  const BookingCardStatusHeader(
      {super.key, required this.statusConfig, required this.booking});
  final BookingStatusPresentation statusConfig;
  final BookingModel booking;
  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.compact,
        runSpacing: AppSpacing.sm,
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
                  color: statusConfig.color,
                  fontSize: AppFontSizes.s11,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            formatVnd(booking.totalPrice),
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: AppFontSizes.s15,
                fontWeight: FontWeight.w800),
          ),
        ],
      );
}
