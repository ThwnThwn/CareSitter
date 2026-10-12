import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/profile/data/models/caregiver_profile_model.dart';

class SettingsProfileCard extends StatelessWidget {
  const SettingsProfileCard(
      {super.key, required this.profile, required this.shortIdLabel});
  final CaregiverProfileModel profile;
  final String Function(String) shortIdLabel;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.primaryContainer,
            backgroundImage: profile.avatarUrl != null &&
                    profile.avatarUrl!.isNotEmpty
                ? ResizeImage(CachedNetworkImageProvider(profile.avatarUrl!),
                    width: 192)
                : null,
            child: (profile.avatarUrl == null || profile.avatarUrl!.isEmpty)
                ? Text(
                    profile.initials,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: AppFontSizes.s20,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: const TextStyle(
                    fontSize: AppFontSizes.s18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  profile.locationText == 'Chưa cập nhật'
                      ? shortIdLabel(profile.id)
                      : profile.locationText,
                  style: const TextStyle(
                    fontSize: AppFontSizes.s14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: () => context.push('/settings/profile/edit'),
          ),
        ],
      ),
    );
  }
}
