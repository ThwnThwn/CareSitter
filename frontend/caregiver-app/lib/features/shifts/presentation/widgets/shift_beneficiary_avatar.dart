import 'package:cached_network_image/cached_network_image.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/utils/default_avatar.dart';
import 'package:flutter/material.dart';

class ShiftBeneficiaryAvatar extends StatelessWidget {
  const ShiftBeneficiaryAvatar({
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
    final defaultAsset = defaultAvatarAssetForGender(
      age: age,
      gender: gender,
    );
    Widget fallback() => defaultAsset == null
        ? Center(
            child: Icon(
              Icons.person_outline_rounded,
              color: AppColors.primary,
              size: radius,
            ),
          )
        : Image.asset(
            defaultAsset,
            fit: BoxFit.cover,
            width: radius * 2,
            height: radius * 2,
            errorBuilder: (_, __, ___) => Icon(
              Icons.person_outline_rounded,
              color: AppColors.primary,
              size: radius,
            ),
          );
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
                ? fallback()
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => fallback(),
                    errorWidget: (_, __, ___) => fallback(),
                  ),
          ),
        ),
      ),
    );
  }
}
