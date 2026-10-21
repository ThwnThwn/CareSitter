import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/app_avatar_image_provider.dart';
import 'package:flutter/material.dart';

import '../models/nutrition_profile_item.dart';

class NutritionProfileCard extends StatelessWidget {
  const NutritionProfileCard({
    super.key,
    required this.profile,
    required this.onTap,
  });

  final NutritionProfileItem profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatarPath = profile.avatarPath;
    final hasAvatar = avatarPath != null && avatarPath.isNotEmpty;
    return Semantics(
      button: true,
      label: 'Xem hồ sơ dinh dưỡng của ${profile.name}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('nutrition-beneficiary-${profile.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primaryContainer,
                  backgroundImage:
                      hasAvatar ? appAvatarImageProvider(avatarPath) : null,
                  child: hasAvatar
                      ? null
                      : Text(
                          profile.avatarInitial,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: AppFontSizes.s17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(width: AppSpacing.compact),
                Expanded(child: _ProfileDetails(profile: profile)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({required this.profile});

  final NutritionProfileItem profile;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.tight),
          Wrap(
            spacing: AppSpacing.tight,
            runSpacing: AppSpacing.tight,
            children: [
              _ProfileBadge(label: profile.relationshipLabel),
              _ProfileBadge(label: profile.ageLabel),
            ],
          ),
          const SizedBox(height: AppSpacing.control),
          Text(
            profile.supportingText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.s12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.control),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'Xem hồ sơ dinh dưỡng',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: AppFontSizes.s13,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      );
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.control,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: AppFontSizes.s11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
