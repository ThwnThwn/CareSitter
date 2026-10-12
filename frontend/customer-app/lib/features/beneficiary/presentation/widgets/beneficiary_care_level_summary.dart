import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/beneficiary/presentation/controllers/beneficiary_controller.dart';

class BeneficiaryCareLevelSummary extends StatelessWidget {
  const BeneficiaryCareLevelSummary(
      {super.key, required this.careLevelColor, required this.b});
  final Color careLevelColor;
  final BeneficiaryModel b;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: careLevelColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: careLevelColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.volunteer_activism_outlined,
                color: careLevelColor, size: 22),
            const SizedBox(width: AppSpacing.control),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Mức độ chăm sóc',
                  style: TextStyle(
                      fontSize: AppFontSizes.s12,
                      color: AppColors.textSecondary)),
              Text(b.careLevelLabel,
                  style: TextStyle(
                      fontSize: AppFontSizes.s16,
                      fontWeight: FontWeight.w800,
                      color: careLevelColor)),
            ]),
            const Spacer(),
            Icon(Icons.circle, color: careLevelColor, size: 12),
          ],
        ),
      );
}
