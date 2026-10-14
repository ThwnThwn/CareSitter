import 'package:caregiver_app/features/auth/presentation/widgets/password_recovery_password_field.dart';
import 'package:caregiver_app/features/auth/presentation/widgets/password_recovery_confirmation_field.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryPasswordStep extends StatelessWidget {
  const PasswordRecoveryPasswordStep(
      {super.key,
      required this.password,
      required this.flow,
      required this.hidden,
      required this.confirmation,
      required this.onTogglePassword,
      required this.onSubmit});
  final TextEditingController password;
  final PasswordRecoveryState flow;
  final bool hidden;
  final TextEditingController confirmation;
  final void Function() onTogglePassword;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
                'Mật khẩu mới cần ít nhất 8 ký tự, một chữ hoa và một chữ số. Mọi thiết bị sẽ cần đăng nhập lại.'),
            const SizedBox(height: AppSpacing.lg),
            PasswordRecoveryPasswordField(
                password: password,
                flow: flow,
                hidden: hidden,
                onTogglePassword: onTogglePassword),
            const SizedBox(height: AppSpacing.md),
            PasswordRecoveryConfirmationField(
                confirmation: confirmation,
                password: password,
                flow: flow,
                hidden: hidden,
                onSubmit: onSubmit),
          ]);
}
