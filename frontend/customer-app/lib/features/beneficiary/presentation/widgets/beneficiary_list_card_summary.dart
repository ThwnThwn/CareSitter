import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';

class BeneficiaryListCardSummary extends StatelessWidget {
  const BeneficiaryListCardSummary(
      {super.key, required this.b, required this.careColor});
  final BeneficiaryModel b;
  final Color careColor;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              b.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.tiny),
            Text(
              '${b.relation} • ${b.ageLabel}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.s12,
              ),
            ),
            const SizedBox(height: AppSpacing.tight),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.tiny),
              decoration: BoxDecoration(
                color: careColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Text(
                b.careLevelLabel,
                style: TextStyle(
                  color: careColor,
                  fontSize: AppFontSizes.s10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}
