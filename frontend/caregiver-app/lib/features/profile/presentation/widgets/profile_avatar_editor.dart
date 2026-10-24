import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/utils/default_avatar.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

/// Widget chỉnh sửa ảnh đại diện với overlay camera.
/// Screen sở hữu trạng thái upload và gọi onTap khi cần.
class ProfileAvatarEditor extends StatelessWidget {
  final String? avatarUrl;
  final String? gender;
  final DateTime? dateOfBirth;
  final String seed;
  final bool isUploading;
  final VoidCallback onTap;

  const ProfileAvatarEditor({
    super.key,
    required this.avatarUrl,
    this.gender,
    this.dateOfBirth,
    this.seed = '',
    required this.isUploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: isUploading ? null : onTap,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: AppColors.primaryContainer,
                backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty
                    ? ResizeImage(CachedNetworkImageProvider(avatarUrl!),
                        width: 192)
                    : AssetImage(defaultAvatarAsset(
                        dateOfBirth: dateOfBirth,
                        gender: gender,
                        seed: seed,
                      ))) as ImageProvider<Object>,
                onBackgroundImageError: (_, __) {},
                child: isUploading
                    ? const CircularProgressIndicator(color: AppColors.primary)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Chạm để đổi ảnh đại diện',
          style: TextStyle(
              fontSize: AppFontSizes.s12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
