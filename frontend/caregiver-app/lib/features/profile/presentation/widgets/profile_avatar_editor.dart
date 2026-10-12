import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

/// Widget chỉnh sửa ảnh đại diện với overlay camera.
/// Screen sở hữu trạng thái upload và gọi onTap khi cần.
class ProfileAvatarEditor extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final bool isUploading;
  final VoidCallback onTap;

  const ProfileAvatarEditor({
    super.key,
    required this.avatarUrl,
    required this.initials,
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
                backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? ResizeImage(CachedNetworkImageProvider(avatarUrl!),
                        width: 192)
                    : null,
                child: isUploading
                    ? const CircularProgressIndicator(color: AppColors.primary)
                    : (avatarUrl == null || avatarUrl!.isEmpty)
                        ? Text(
                            initials,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: AppFontSizes.s32,
                              fontWeight: FontWeight.bold,
                            ),
                          )
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
