import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverListCaregiverCardCaregiverContent extends StatelessWidget {
  const CaregiverListCaregiverCardCaregiverContent(
      {super.key, required this.caregiver});
  final CaregiverModel caregiver;
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: caregiver.skills.take(3).map((skill) {
          return Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.control, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Text(
              skill,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: AppFontSizes.s11,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      );
}
