import 'package:cached_network_image/cached_network_image.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/utils/default_avatar.dart';
import 'package:flutter/material.dart';

class BeneficiaryAvatar extends StatelessWidget {
  const BeneficiaryAvatar({
    super.key,
    required this.name,
    this.age,
    this.gender,
    this.avatarUrl,
    this.radius = 24,
  });

  final String name;
  final int? age;
  final String? gender;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final defaultAsset = defaultAvatarAssetForGender(age: age, gender: gender);
    final url = avatarUrl?.trim();

    return Semantics(
      image: true,
      label: 'Ảnh đại diện $name',
      child: ClipOval(
        child: ColoredBox(
          color: AppColors.primaryContainer,
          child: SizedBox.square(
            dimension: radius * 2,
            child: url == null || url.isEmpty
                ? _BeneficiaryAvatarFallback(
                    asset: defaultAsset,
                    radius: radius,
                  )
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _BeneficiaryAvatarFallback(
                      asset: defaultAsset,
                      radius: radius,
                    ),
                    errorWidget: (_, __, ___) => _BeneficiaryAvatarFallback(
                      asset: defaultAsset,
                      radius: radius,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _BeneficiaryAvatarFallback extends StatelessWidget {
  const _BeneficiaryAvatarFallback({required this.asset, required this.radius});

  final String? asset;
  final double radius;

  @override
  Widget build(BuildContext context) => asset == null
      ? Center(
          child: Icon(
            Icons.person_outline_rounded,
            color: AppColors.primary,
            size: radius,
          ),
        )
      : Image.asset(
          asset!,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          errorBuilder: (_, __, ___) => Icon(
            Icons.person_outline_rounded,
            color: AppColors.primary,
            size: radius,
          ),
        );
}
