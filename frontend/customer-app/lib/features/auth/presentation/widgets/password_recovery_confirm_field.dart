import 'package:flutter/material.dart';
import '../../domain/recovery_input_rules.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryConfirmField extends StatelessWidget {
  const PasswordRecoveryConfirmField(
      {super.key,
      required this.confirmation,
      required this.password,
      required this.flow,
      required this.hidden,
      required this.onSubmit});
  final TextEditingController confirmation;
  final TextEditingController password;
  final PasswordRecoveryState flow;
  final bool hidden;
  final Future<void> Function() onSubmit;
  @override
  Widget build(BuildContext context) => TextFormField(
      key: const ValueKey('recovery-confirmation'),
      controller: confirmation,
      enabled: !flow.busy,
      obscureText: hidden,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.newPassword],
      decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu mới'),
      validator: (value) =>
          RecoveryInputRules.confirmation(value, password.text),
      onFieldSubmitted: (_) => onSubmit());
}
