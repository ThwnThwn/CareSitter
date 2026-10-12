import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryConfirmField extends StatelessWidget {
  const PasswordRecoveryConfirmField(
      {super.key,
      required this.confirmation,
      required this.flow,
      required this.hidden,
      required this.action1,
      required this.action2});
  final TextEditingController confirmation;
  final PasswordRecoveryState flow;
  final bool hidden;
  final String? Function(String?) action1;
  final void Function(String) action2;
  @override
  Widget build(BuildContext context) => TextFormField(
      key: const ValueKey('recovery-confirmation'),
      controller: confirmation,
      enabled: !flow.busy,
      obscureText: hidden,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.newPassword],
      decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu mới'),
      validator: action1,
      onFieldSubmitted: action2);
}
