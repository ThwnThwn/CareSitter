import 'package:flutter/material.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryPasswordField extends StatelessWidget {
  const PasswordRecoveryPasswordField(
      {super.key,
      required this.password,
      required this.flow,
      required this.hidden,
      required this.validatePassword,
      required this.callbackAction1});
  final TextEditingController password;
  final PasswordRecoveryState flow;
  final bool hidden;
  final String? Function(String?) validatePassword;
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => TextFormField(
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
              onPressed: callbackAction1,
              icon: Icon(hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined))));
}
