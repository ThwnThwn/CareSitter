import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftSummaryStatusLabel extends StatelessWidget {
  const ShiftSummaryStatusLabel(
      {super.key, required this.checkoutPendingReview});
  final bool checkoutPendingReview;

  @override
  Widget build(BuildContext context) => Text(
        checkoutPendingReview
            ? 'Đã gửi yêu cầu checkout'
            : 'Hoàn thành ca làm việc!',
        style: const TextStyle(
            fontSize: AppFontSizes.s24,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary),
      );
}
