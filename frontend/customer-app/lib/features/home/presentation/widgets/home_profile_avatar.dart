import 'package:cached_network_image/cached_network_image.dart';
import 'package:caresitter_customer/core/utils/default_avatar.dart';
import 'package:caresitter_customer/features/home/presentation/widgets/home_hover_button.dart';
import 'package:caresitter_customer/features/settings/data/models/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeProfileAvatar extends StatelessWidget {
  const HomeProfileAvatar(
      {super.key, required this.callbackAction1, required this.profile});
  final void Function() callbackAction1;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) => HomeHoverButton(
        borderRadius: BorderRadius.circular(999),
        onTap: callbackAction1,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.18),
              width: 2,
            ),
          ),
          child: ClipOval(
            child: SizedBox.square(
              dimension: 44,
              child: _avatar(profile),
            ),
          ),
        ),
      );

  Widget _avatar(UserProfile profile) {
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
