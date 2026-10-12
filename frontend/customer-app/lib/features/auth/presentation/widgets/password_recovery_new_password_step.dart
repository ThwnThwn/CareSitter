import 'package:caresitter_customer/features/auth/presentation/widgets/password_recovery_confirm_field.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryNewPasswordStep extends StatelessWidget {
  const PasswordRecoveryNewPasswordStep(
      {super.key,
      required this.password,
      required this.flow,
      required this.hidden,
      required this.validatePassword,
      required this.callbackAction5,
      required this.confirmation,
      required this.callbackAction6,
      required this.callbackAction7});
  final TextEditingController password;
  final PasswordRecoveryState flow;
  final bool hidden;
  final String? Function(String?) validatePassword;
  final void Function() callbackAction5;
  final TextEditingController confirmation;
  final String? Function(String?) callbackAction6;
  final void Function(String) callbackAction7;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
                'Mật khẩu mới cần ít nhất 8 ký tự, một chữ hoa và một chữ số. Mọi thiết bị sẽ cần đăng nhập lại.'),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
                key: const ValueKey('recovery-password'),
                controller: password,
                enabled: !flow.busy,
                obscureText: hidden,
                autofillHints: const [AutofillHints.newPassword],
                validator: validatePassword,
                decoration: InputDecoration(
                    labelText: 'Mật khẩu mới',
                    suffixIcon: IconButton(
                        tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                        onPressed: callbackAction5,
                        icon: Icon(hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined)))),
            const SizedBox(height: AppSpacing.md),
            PasswordRecoveryConfirmField(
                confirmation: confirmation,
                flow: flow,
                hidden: hidden,
                action1: callbackAction6,
                action2: callbackAction7),
          ]);
}
