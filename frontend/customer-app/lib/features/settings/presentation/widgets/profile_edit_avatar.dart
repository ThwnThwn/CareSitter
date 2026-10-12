import 'package:caresitter_customer/features/settings/presentation/widgets/profile_edit_avatar_widget.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';

class ProfileEditAvatar extends StatelessWidget {
  const ProfileEditAvatar(
      {super.key,
      required this.pendingAvatarFile,
      required this.profile,
      required this.buildInitials,
      required this.nameCtrl,
      required this.isUploadingAvatar,
      required this.isSaving,
      required this.pickAvatar});
  final XFile? pendingAvatarFile;
  final UserProfile profile;
  final String Function(String) buildInitials;
  final TextEditingController nameCtrl;
  final bool isUploadingAvatar;
  final bool isSaving;
  final Future<void> Function() pickAvatar;
  @override
  Widget build(BuildContext context) => Center(
        child: Stack(
          children: [
            ProfileEditAvatarWidget(
              avatarUrl: pendingAvatarFile != null
                  ? null // preview local file bên dưới
                  : profile.avatarUrl,
              localFile: pendingAvatarFile,
              initials: buildInitials(nameCtrl.text),
              isUploading: isUploadingAvatar,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: (isUploadingAvatar || isSaving) ? null : pickAvatar,
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
}
