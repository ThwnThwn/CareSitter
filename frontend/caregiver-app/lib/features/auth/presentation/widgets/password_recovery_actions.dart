import 'package:caregiver_app/features/auth/presentation/widgets/password_recovery_submit_button.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryActions extends StatelessWidget {
  const PasswordRecoveryActions(
      {super.key,
      required this.flow,
      required this.submit,
      required this.startOver});
  final PasswordRecoveryState flow;
  final Future<void> Function() submit;
  final void Function() startOver;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            PasswordRecoverySubmitButton(flow: flow, submit: submit),
            if (flow.step > 0)
              TextButton(
                  onPressed: flow.busy ? null : startOver,
                  child: Text(flow.step == 1 ? 'Đổi email' : 'Bắt đầu lại')),
            const SizedBox(height: AppSpacing.md),
            const Text('Đổi mật khẩu không mở khóa tài khoản bị admin khóa.',
                style: TextStyle(color: AppColors.textSecondary)),
          ]);
}
