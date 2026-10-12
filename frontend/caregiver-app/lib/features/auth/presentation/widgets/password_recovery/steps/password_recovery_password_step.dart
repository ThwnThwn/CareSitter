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
      required this.validatePassword,
      required this.confirmation,
      required this.callbackAction3,
      required this.callbackAction4,
      required this.callbackAction5});
  final TextEditingController password;
  final PasswordRecoveryState flow;
  final bool hidden;
  final String? Function(String?) validatePassword;
  final TextEditingController confirmation;
  final void Function() callbackAction3;
  final String? Function(String?) callbackAction4;
  final void Function(String) callbackAction5;

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
                validatePassword: validatePassword,
                callbackAction1: callbackAction3),
            const SizedBox(height: AppSpacing.md),
            PasswordRecoveryConfirmationField(
                confirmation: confirmation,
                flow: flow,
                hidden: hidden,
                callbackAction1: callbackAction4,
                callbackAction2: callbackAction5),
          ]);
}
