import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverListCaregiverCardCaregiverContentBody extends StatelessWidget {
  const CaregiverListCaregiverCardCaregiverContentBody(
      {super.key, required this.caregiver});
  final CaregiverModel caregiver;
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded,
                  color: AppColors.secondary, size: 14),
              const SizedBox(width: AppSpacing.tiny),
              Text(
                caregiver.ratingAvg.toStringAsFixed(1),
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppFontSizes.s13,
                    fontWeight: FontWeight.w600),
              ),
              Text(
                ' (${caregiver.ratingCount})',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: AppFontSizes.s12),
              ),
            ],
          ),
          if (caregiver.yearsOfExperience != null) ...[
            Text(
              '${caregiver.yearsOfExperience} năm kinh nghiệm',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: AppFontSizes.s12),
            ),
          ],
        ],
      );
}
