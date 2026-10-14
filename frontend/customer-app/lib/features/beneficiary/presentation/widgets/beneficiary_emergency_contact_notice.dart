import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BeneficiaryEmergencyContactNotice extends StatelessWidget {
  const BeneficiaryEmergencyContactNotice({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.inset, vertical: AppSpacing.compact),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(AppRadius.compact),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.4),
          ),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: AppColors.warning, size: 18),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Bắt buộc ít nhất 2 liên hệ khẩn cấp. Những người này sẽ được thông báo ngay khi xảy ra sự cố trong ca chăm sóc.',
                style: TextStyle(
                  fontSize: AppFontSizes.s12,
                  color: AppColors.warning,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
}
