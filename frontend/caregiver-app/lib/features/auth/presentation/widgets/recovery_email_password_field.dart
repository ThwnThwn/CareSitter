import 'package:flutter/material.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/recovery_email_controller.dart';

class RecoveryEmailPasswordField extends StatelessWidget {
  const RecoveryEmailPasswordField(
      {super.key,
      required this.password,
      required this.flow,
      required this.hidden,
      required this.callbackAction1,
      required this.callbackAction2});
  final TextEditingController password;
  final RecoveryEmailState flow;
  final bool hidden;
  final void Function() callbackAction1;
  final String? Function(String?) callbackAction2;

  @override
  Widget build(BuildContext context) => TextFormField(
      controller: password,
      enabled: !flow.busy,
      obscureText: hidden,
      decoration: InputDecoration(
          labelText: 'Mật khẩu hiện tại',
          suffixIcon: IconButton(
              tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
              onPressed: callbackAction1,
              icon: Icon(hidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined))),
      validator: callbackAction2);
}
