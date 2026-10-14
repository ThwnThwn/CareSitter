import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import '../../domain/settings_input_rules.dart';
import 'password_input_field.dart';
import 'password_requirements_notice.dart';

class ChangePasswordForm extends StatelessWidget {
  const ChangePasswordForm(
      {super.key,
      required this.formKey,
      required this.oldPassCtrl,
      required this.newPassCtrl,
      required this.confirmPassCtrl,
      required this.isSaving,
      required this.onSubmit});
  final GlobalKey<FormState> formKey;
  final TextEditingController oldPassCtrl, newPassCtrl, confirmPassCtrl;
  final bool isSaving;
  final VoidCallback onSubmit;
  @override
  Widget build(BuildContext context) => Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const PasswordRequirementsNotice(),
          const SizedBox(height: AppSpacing.lg),
          PasswordInputField(
              controller: oldPassCtrl,
              label: 'Mật khẩu hiện tại',
              hint: 'Nhập mật khẩu hiện tại',
              validator: SettingsInputRules.currentPassword),
          const SizedBox(height: AppSpacing.md),
          PasswordInputField(
              controller: newPassCtrl,
              label: 'Mật khẩu mới',
              hint: 'Nhập mật khẩu mới',
              validator: SettingsInputRules.newPassword),
          const SizedBox(height: AppSpacing.md),
          PasswordInputField(
              controller: confirmPassCtrl,
              label: 'Xác nhận mật khẩu mới',
              hint: 'Nhập lại mật khẩu mới',
              validator: (value) =>
                  SettingsInputRules.confirmPassword(value, newPassCtrl.text)),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(
              onPressed: isSaving ? null : onSubmit,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
              child: isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Cập nhật mật khẩu',
                      style: TextStyle(fontSize: AppFontSizes.s15))),
        ],
      ));
}
