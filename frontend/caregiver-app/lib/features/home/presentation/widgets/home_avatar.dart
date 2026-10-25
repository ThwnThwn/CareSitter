import 'package:cached_network_image/cached_network_image.dart';
import 'package:caregiver_app/core/utils/default_avatar.dart';
import 'package:caregiver_app/features/profile/data/models/caregiver_profile_model.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeAvatar extends StatelessWidget {
  const HomeAvatar({super.key, required this.profile});
  final CaregiverProfileModel profile;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryContainer,
              backgroundImage: (profile.avatarUrl?.trim().isNotEmpty == true
                  ? ResizeImage(
                      CachedNetworkImageProvider(profile.avatarUrl!),
                      width: 128,
                    )
                  : AssetImage(defaultAvatarAsset(
                      dateOfBirth: profile.parsedDateOfBirth,
                      gender: profile.gender,
                      seed: profile.userId,
                    ))) as ImageProvider<Object>,
              onBackgroundImageError: (_, __) {},
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardBackground, width: 2),
              ),
            ),
          ),
        ],
      );
}
