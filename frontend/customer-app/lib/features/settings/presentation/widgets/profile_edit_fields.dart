import 'package:caresitter_customer/features/settings/presentation/widgets/profile_edit_birth_date_gender.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/profile_edit_save_button.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/profile_edit_email_field.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/profile_edit_name_field.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/profile_edit_phone_field.dart';
import 'package:caresitter_customer/features/settings/presentation/widgets/profile_edit_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_edit_controller.dart';

class ProfileEditFields extends StatelessWidget {
  const ProfileEditFields(
      {super.key,
      required this.pendingAvatarFile,
      required this.profile,
      required this.buildInitials,
      required this.nameCtrl,
      required this.isUploadingAvatar,
      required this.ref,
      required this.pickAvatar,
      required this.buildSectionHeader,
      required this.callbackAction1,
      required this.callbackAction2,
      required this.displayNameCtrl,
      required this.emailCtrl,
      required this.callbackAction3,
      required this.callbackAction4,
      required this.dobCtrl,
      required this.selectDate,
      required this.gender,
      required this.callbackAction5,
      required this.saveProfile});
  final XFile? pendingAvatarFile;
  final UserProfile profile;
  final String Function(String) buildInitials;
  final TextEditingController nameCtrl;
  final bool isUploadingAvatar;
  final WidgetRef ref;
  final Future<void> Function() pickAvatar;
  final Widget Function(String) buildSectionHeader;
  final void Function(String) callbackAction1;
  final String? Function(String?) callbackAction2;
  final TextEditingController displayNameCtrl;
  final TextEditingController emailCtrl;
  final void Function() callbackAction3;
  final String? Function(String?) callbackAction4;
  final TextEditingController dobCtrl;
  final Future<void> Function() selectDate;
  final String gender;
  final void Function(String?) callbackAction5;
  final Future<void> Function() saveProfile;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // ── Avatar ───────────────────────────────────────────────────
          ProfileEditAvatar(
              pendingAvatarFile: pendingAvatarFile,
              profile: profile,
              buildInitials: buildInitials,
              nameCtrl: nameCtrl,
              isUploadingAvatar: isUploadingAvatar,
              isSaving: ref.watch(profileEditControllerProvider).busy,
              pickAvatar: pickAvatar),
          const SizedBox(height: AppSpacing.lg),

          // ── Tài khoản & Liên hệ ──────────────────────────────────────
          buildSectionHeader('Tài khoản & Liên hệ'),
          const SizedBox(height: AppSpacing.compact),

          ProfileEditNameField(
              nameCtrl: nameCtrl,
              callbackAction1: callbackAction1,
              callbackAction2: callbackAction2),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: displayNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Tên hiển thị',
              helperText: 'Để trống → dùng họ tên',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Số điện thoại — readonly (identity/login)
          ProfileEditPhoneField(profile: profile),
          const SizedBox(height: AppSpacing.md),

          ProfileEditEmailField(
              emailCtrl: emailCtrl,
              callbackAction3: callbackAction3,
              callbackAction4: callbackAction4),
          const SizedBox(height: AppSpacing.lg),

          // ── Thông tin cá nhân ─────────────────────────────────────────
          buildSectionHeader('Thông tin cá nhân'),
          const SizedBox(height: AppSpacing.compact),

          ProfileEditBirthDateGender(
              dobCtrl: dobCtrl,
              selectDate: selectDate,
              gender: gender,
              callbackAction5: callbackAction5),
          const SizedBox(height: AppSpacing.xl),

          ProfileEditSaveButton(
              ref: ref,
              isUploadingAvatar: isUploadingAvatar,
              saveProfile: saveProfile),
          const SizedBox(height: AppSpacing.lg),
        ],
      );
}
