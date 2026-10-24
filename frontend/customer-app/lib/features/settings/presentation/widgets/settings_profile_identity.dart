import 'package:cached_network_image/cached_network_image.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/default_avatar.dart';
import 'package:caresitter_customer/features/settings/data/models/user_profile.dart';
import 'package:flutter/material.dart';

class SettingsProfileIdentity extends StatelessWidget {
  const SettingsProfileIdentity({
    super.key,
    required this.profile,
    required this.onEditProfile,
  });

  final UserProfile profile;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) => Stack(children: [
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
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: onEditProfile,
            child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2)),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 14)),
          ),
        ),
      ]);

  Widget _avatar() {
    final fallback = Image.asset(
      defaultAvatarAsset(
        dateOfBirth: parseAvatarDate(profile.dob),
        gender: profile.gender,
        seed: profile.name,
      ),
      fit: BoxFit.cover,
    );
    final url = profile.avatarUrl?.trim() ?? '';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return fallback;
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
