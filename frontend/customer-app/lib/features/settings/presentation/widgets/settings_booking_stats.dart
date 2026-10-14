import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/utils/currency_formatter.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class SettingsBookingStats extends StatelessWidget {
  const SettingsBookingStats(
      {super.key, required this.bookingCount, required this.totalSpent});
  final int bookingCount;
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
        Text(formatVnd(totalSpent, suffix: 'đ đã chi'),
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: AppFontSizes.s13,
                fontWeight: FontWeight.w700)),
      ]);
}
