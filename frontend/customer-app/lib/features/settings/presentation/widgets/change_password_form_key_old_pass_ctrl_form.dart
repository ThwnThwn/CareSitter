import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ChangePasswordFormKeyOldPassCtrlForm extends StatelessWidget {
  const ChangePasswordFormKeyOldPassCtrlForm(
      {super.key,
      required this.formKey,
      required this.buildLabel,
      required this.buildPasswordField,
      required this.oldPassCtrl,
      required this.obscureOld,
      required this.newPassCtrl,
      required this.obscureNew,
      required this.confirmPassCtrl,
      required this.obscureConfirm,
      required this.isSaving,
      required this.submit,
      required this.callbackAction1,
      required this.callbackAction2,
      required this.callbackAction3,
      required this.callbackAction4,
      required this.callbackAction5,
      required this.callbackAction6});
  final GlobalKey<FormState> formKey;
  final Widget Function(String) buildLabel;
  final Widget Function(
      {required TextEditingController controller,
      required String hint,
      required bool obscure,
      required void Function() onToggle,
      required String? Function(String?) validator}) buildPasswordField;
  final TextEditingController oldPassCtrl;
  final bool obscureOld;
  final TextEditingController newPassCtrl;
  final bool obscureNew;
  final TextEditingController confirmPassCtrl;
  final bool obscureConfirm;
  final bool isSaving;
  final Future<void> Function() submit;
  final void Function() callbackAction1;
  final String? Function(String?) callbackAction2;
  final void Function() callbackAction3;
  final String? Function(String?) callbackAction4;
  final void Function() callbackAction5;
  final String? Function(String?) callbackAction6;

  @override
  Widget build(BuildContext context) => Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                  SizedBox(width: AppSpacing.control),
                  Expanded(
                    child: Text(
                      'Mật khẩu mới phải có ít nhất 8 ký tự, bao gồm chữ cái và số.',
                      style: TextStyle(
                          color: AppColors.warning,
                          fontSize: AppFontSizes.s13,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            buildLabel('Mật khẩu hiện tại'),
            buildPasswordField(
              controller: oldPassCtrl,
              hint: 'Nhập mật khẩu hiện tại',
              obscure: obscureOld,
              onToggle: callbackAction1,
              validator: callbackAction2,
            ),
            const SizedBox(height: AppSpacing.md),
            buildLabel('Mật khẩu mới'),
            buildPasswordField(
              controller: newPassCtrl,
              hint: 'Nhập mật khẩu mới',
              obscure: obscureNew,
              onToggle: callbackAction3,
              validator: callbackAction4,
            ),
            const SizedBox(height: AppSpacing.md),
            buildLabel('Xác nhận mật khẩu mới'),
            buildPasswordField(
              controller: confirmPassCtrl,
              hint: 'Nhập lại mật khẩu mới',
              obscure: obscureConfirm,
              onToggle: callbackAction5,
              validator: callbackAction6,
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: isSaving ? null : submit,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52)),
              child: isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text('Cập nhật mật khẩu',
                      style: TextStyle(fontSize: AppFontSizes.s15)),
            ),
          ],
        ),
      );
}
