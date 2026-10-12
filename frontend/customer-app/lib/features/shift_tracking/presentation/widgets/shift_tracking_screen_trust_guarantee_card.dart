import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ShiftTrackingScreenTrustGuaranteeCard extends StatelessWidget {
  const ShiftTrackingScreenTrustGuaranteeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.inset, vertical: AppSpacing.control),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_rounded, color: AppColors.warning, size: 18),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Cam kết Đồng hành Phi Y tế & Bảo hiểm CareSitter CareGuard 24/7',
              style: TextStyle(
                fontSize: AppFontSizes.s11,
                fontWeight: FontWeight.w500,
                color: AppColors.goldText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
