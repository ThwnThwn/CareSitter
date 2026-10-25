import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/profile/data/models/caregiver_profile_model.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/settings_profile_edit_link.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/settings_profile_identity.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/settings_profile_stats.dart';
import 'package:flutter/material.dart';

class SettingsProfileCard extends StatelessWidget {
  const SettingsProfileCard({
    super.key,
    required this.profile,
    required this.completedShifts,
    required this.monthTotal,
    required this.onEditProfile,
  });

  final CaregiverProfileModel profile;

  final int completedShifts;
  final double monthTotal;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.section),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.primaryContainer),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SettingsProfileIdentity(
              profile: profile,
              onEditProfile: onEditProfile,
            ),
            const SizedBox(height: AppSpacing.inset),
            Text(
              profile.displayName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              profile.locationText == 'Chưa cập nhật'
                  ? 'Hoàn thiện hồ sơ để bắt đầu nhận ca'
                  : profile.locationText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppFontSizes.s13,
              ),
            ),
            const SizedBox(height: AppSpacing.comfortable),
            SettingsProfileStats(
              completedShifts: completedShifts,
              monthTotal: monthTotal,
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsProfileEditLink(onEditProfile: onEditProfile),
          ],
        ),
      );
}
