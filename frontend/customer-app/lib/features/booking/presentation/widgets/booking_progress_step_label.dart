import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BookingProgressStepLabel extends StatelessWidget {
  const BookingProgressStepLabel(
      {super.key,
      required this.steps,
      required this.idx,
      required this.isActive,
      required this.isPassed});
  final List<Map<String, Object>> steps;
  final int idx;
  final bool isActive;
  final bool isPassed;

  @override
  Widget build(BuildContext context) => Text(
        steps[idx]['title'] as String,
        style: TextStyle(
          fontSize: AppFontSizes.s11,
          fontWeight: isActive
              ? FontWeight.w700
              : (isPassed ? FontWeight.w600 : FontWeight.w400),
          color: isActive
              ? AppColors.primary
              : (isPassed ? AppColors.textPrimary : AppColors.textSecondary),
        ),
      );
}
