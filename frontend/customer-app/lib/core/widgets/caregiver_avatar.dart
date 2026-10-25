import 'package:cached_network_image/cached_network_image.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/utils/default_avatar.dart';
import 'package:flutter/material.dart';

class CaregiverAvatar extends StatelessWidget {
  const CaregiverAvatar({
    super.key,
    required this.initials,
    required this.radius,
    this.avatarUrl,
    this.seed,
    this.backgroundColor = AppColors.primaryContainer,
  });

  final String? avatarUrl;
  final String initials;
  final String? seed;
  final double radius;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim() ?? '';
    final fallback = _DefaultCaregiverAvatar(
      seed: seed?.trim().isNotEmpty == true ? seed! : initials,
      backgroundColor: backgroundColor,
    );

    return SizedBox.square(
      dimension: radius * 2,
      child: ClipOval(
        child: url.startsWith('http://') || url.startsWith('https://')
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }
}

class _DefaultCaregiverAvatar extends StatelessWidget {
  const _DefaultCaregiverAvatar({
    required this.seed,
    required this.backgroundColor,
  });

  final String seed;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: backgroundColor,
        child: Image.asset(
          defaultAvatarAsset(seed: seed),
          fit: BoxFit.cover,
        ),
      );
}
