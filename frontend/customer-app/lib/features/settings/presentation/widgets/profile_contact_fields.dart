import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/settings/data/models/user_profile.dart';
import 'profile_edit_name_field.dart';
import 'profile_edit_email_field.dart';
import 'profile_edit_phone_field.dart';

class ProfileContactFields extends StatelessWidget {
  const ProfileContactFields(
      {super.key,
      required this.profile,
      required this.nameCtrl,
      required this.displayNameCtrl,
      required this.emailCtrl,
      required this.onNameChanged,
      required this.onEditRecoveryEmail});
  final UserProfile profile;
  final TextEditingController nameCtrl, displayNameCtrl, emailCtrl;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onEditRecoveryEmail;
  @override
  Widget build(BuildContext context) => Column(children: [
        ProfileEditNameField(nameCtrl: nameCtrl, onNameChanged: onNameChanged),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
            controller: displayNameCtrl,
            decoration: const InputDecoration(
                labelText: 'Tên hiển thị',
                helperText: 'Để trống → dùng họ tên',
                prefixIcon: Icon(Icons.badge_outlined))),
        const SizedBox(height: AppSpacing.md),
        ProfileEditPhoneField(profile: profile),
        const SizedBox(height: AppSpacing.md),
        ProfileEditEmailField(
            emailCtrl: emailCtrl, onEditRecoveryEmail: onEditRecoveryEmail),
      ]);
}
