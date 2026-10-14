import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../../data/models/user_profile.dart';
import 'profile_edit_avatar.dart';
import 'profile_section_title.dart';
import 'profile_contact_fields.dart';
import 'profile_edit_birth_date_gender.dart';
import 'profile_edit_save_button.dart';

class ProfileEditForm extends StatelessWidget {
  const ProfileEditForm(
      {super.key,
      required this.formKey,
      required this.pendingAvatarFile,
      required this.profile,
      required this.nameCtrl,
      required this.isUploadingAvatar,
      required this.isSaving,
      required this.onPickAvatar,
      required this.displayNameCtrl,
      required this.emailCtrl,
      required this.dobCtrl,
      required this.onSelectDate,
      required this.gender,
      required this.onSave,
      required this.onNameChanged,
      required this.onEditRecoveryEmail,
      required this.onGenderChanged});
  final GlobalKey<FormState> formKey;
  final XFile? pendingAvatarFile;
  final UserProfile profile;
  final TextEditingController nameCtrl, displayNameCtrl, emailCtrl, dobCtrl;
  final bool isUploadingAvatar, isSaving;
  final String gender;
  final VoidCallback onPickAvatar, onSelectDate, onSave, onEditRecoveryEmail;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String?> onGenderChanged;

  @override
  Widget build(BuildContext context) => Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          ProfileEditAvatar(
              pendingAvatarFile: pendingAvatarFile,
              avatarUrl: profile.avatarUrl,
              name: nameCtrl.text,
              isUploadingAvatar: isUploadingAvatar,
              isSaving: isSaving,
              onPickAvatar: onPickAvatar),
          const SizedBox(height: AppSpacing.lg),
          const ProfileSectionTitle('Tài khoản & Liên hệ'),
          const SizedBox(height: AppSpacing.compact),
          ProfileContactFields(
              profile: profile,
              nameCtrl: nameCtrl,
              displayNameCtrl: displayNameCtrl,
              emailCtrl: emailCtrl,
              onNameChanged: onNameChanged,
              onEditRecoveryEmail: onEditRecoveryEmail),
          const SizedBox(height: AppSpacing.lg),
          const ProfileSectionTitle('Thông tin cá nhân'),
          const SizedBox(height: AppSpacing.compact),
          ProfileEditBirthDateGender(
              dobCtrl: dobCtrl,
              selectDate: onSelectDate,
              gender: gender,
              onGenderChanged: onGenderChanged),
          const SizedBox(height: AppSpacing.xl),
          ProfileEditSaveButton(
              busy: isSaving || isUploadingAvatar, onSave: onSave),
          const SizedBox(height: AppSpacing.lg),
        ],
      ));
}
