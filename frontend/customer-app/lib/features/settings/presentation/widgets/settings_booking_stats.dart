import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class SettingsBookingStats extends StatelessWidget {
  const SettingsBookingStats(
      {super.key,
      required this.bookingCount,
      required this.formatCurrency,
      required this.totalSpent});
  final int bookingCount;
  final String Function(double) formatCurrency;
  final double totalSpent;

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('$bookingCount lịch hẹn',
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: AppFontSizes.s13,
                fontWeight: FontWeight.w700)),
        const Text('  -  ',
            style: TextStyle(
                color: AppColors.textHint, fontWeight: FontWeight.w700)),
        Text(formatCurrency(totalSpent),
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: AppFontSizes.s13,
                fontWeight: FontWeight.w700)),
      ]);
}
