import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverProfileSkillsSection extends StatelessWidget {
  const CaregiverProfileSkillsSection({super.key, required this.caregiver});
  final CaregiverModel caregiver;
  @override
  Widget build(BuildContext context) {
    if (caregiver.skills.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.inset),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Text('Chưa cập nhật kỹ năng',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: AppFontSizes.s13)),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: caregiver.skills.map((skill) {
        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.compact, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.compact),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline,
                  color: AppColors.primary, size: 14),
              const SizedBox(width: AppSpacing.tight),
              Flexible(
                child: Text(
                  skill,
                  maxLines: 2,
                  overflow: TextOverflow.fade,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: AppFontSizes.s13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
