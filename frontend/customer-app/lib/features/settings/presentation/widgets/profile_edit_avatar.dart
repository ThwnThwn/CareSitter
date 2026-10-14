import 'package:caresitter_customer/features/settings/presentation/widgets/profile_edit_avatar_widget.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ProfileEditAvatar extends StatelessWidget {
  const ProfileEditAvatar(
      {super.key,
      required this.pendingAvatarFile,
      required this.avatarUrl,
      required this.name,
      required this.isUploadingAvatar,
      required this.isSaving,
      required this.onPickAvatar});
  final XFile? pendingAvatarFile;
  final String? avatarUrl;
  final String name;
  final bool isUploadingAvatar;
  final bool isSaving;
  final VoidCallback onPickAvatar;
  @override
  Widget build(BuildContext context) => Center(
        child: Stack(
          children: [
            ProfileEditAvatarWidget(
              avatarUrl: pendingAvatarFile != null
                  ? null // preview local file bên dưới
                  : avatarUrl,
              localFile: pendingAvatarFile,
              initials: _initials(name),
              isUploading: isUploadingAvatar,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: (isUploadingAvatar || isSaving) ? null : onPickAvatar,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      );
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final initials = parts.map((p) => p[0].toUpperCase()).take(3).join();
    return initials.isNotEmpty ? initials : 'U';
  }
}
