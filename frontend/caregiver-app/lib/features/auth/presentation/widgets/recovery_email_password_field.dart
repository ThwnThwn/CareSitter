import 'package:flutter/material.dart';
import '../../domain/recovery_input_rules.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/recovery_email_controller.dart';

class RecoveryEmailPasswordField extends StatelessWidget {
  const RecoveryEmailPasswordField(
      {super.key,
      required this.password,
      required this.flow,
      required this.hidden,
      required this.onTogglePassword});
  final TextEditingController password;
  final RecoveryEmailState flow;
  final bool hidden;
  final void Function() onTogglePassword;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: password,
        enabled: !flow.busy,
        obscureText: hidden,
        validator: RecoveryInputRules.currentPassword,
        decoration: InputDecoration(
            labelText: 'Mật khẩu hiện tại',
            suffixIcon: IconButton(
                tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                onPressed: onTogglePassword,
                icon: Icon(hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined))),
      );
}
