import 'package:cached_network_image/cached_network_image.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/utils/default_avatar.dart';
import 'package:caregiver_app/features/profile/data/models/caregiver_profile_model.dart';
import 'package:flutter/material.dart';

class SettingsProfileIdentity extends StatelessWidget {
  const SettingsProfileIdentity({
    super.key,
    required this.profile,
    required this.onEditProfile,
  });

  final CaregiverProfileModel profile;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: ClipOval(child: _avatar()),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: IconButton(
              onPressed: onEditProfile,
              tooltip: 'Chỉnh sửa hồ sơ',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size(32, 32),
                fixedSize: const Size(32, 32),
                side: const BorderSide(
                  color: AppColors.cardBackground,
                  width: 2,
                ),
              ),
              icon: const Icon(Icons.camera_alt_outlined, size: 16),
            ),
          ),
        ],
      );

  Widget _avatar() {
    final fallback = Image.asset(
      defaultAvatarAsset(
        dateOfBirth: profile.parsedDateOfBirth,
        gender: profile.gender,
        seed: profile.userId,
      ),
      fit: BoxFit.cover,
    );
    final avatarUrl = profile.avatarUrl?.trim() ?? '';
    if (!avatarUrl.startsWith('http://') && !avatarUrl.startsWith('https://')) {
      return fallback;
    }
    return CachedNetworkImage(
      imageUrl: avatarUrl,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
