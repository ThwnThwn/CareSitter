import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_list_caregiver_card_caregiver_content_body.dart';
import 'package:caresitter_customer/features/caregiver/presentation/widgets/caregiver_list_caregiver_card_caregiver_decoration.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverListCaregiverCardCaregiverRow extends StatelessWidget {
  const CaregiverListCaregiverCardCaregiverRow(
      {super.key, required this.caregiver});
  final CaregiverModel caregiver;
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CaregiverListCaregiverCardCaregiverDecoration(caregiver: caregiver),
          const SizedBox(width: AppSpacing.compact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        caregiver.displayName,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: AppFontSizes.s15,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.verified_rounded,
                        color: AppColors.primary, size: 16),
                    const SizedBox(width: AppSpacing.xs),
                    const Icon(Icons.favorite_border_rounded,
                        color: AppColors.textHint, size: 20),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                CaregiverListCaregiverCardCaregiverContentBody(
                    caregiver: caregiver),
                if (caregiver.yearsOfExperience != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      '📖 ${caregiver.yearsOfExperience} năm chăm sóc người lớn tuổi',
                      style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppFontSizes.s12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
}
