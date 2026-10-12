import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftSummaryStatusIcon extends StatelessWidget {
  const ShiftSummaryStatusIcon(
      {super.key, required this.checkoutPendingReview});
  final bool checkoutPendingReview;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          checkoutPendingReview
              ? Icons.hourglass_top_rounded
              : Icons.check_circle_rounded,
          color: checkoutPendingReview ? AppColors.warning : AppColors.success,
          size: 80,
        ),
      );
}
