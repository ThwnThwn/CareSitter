import 'package:flutter/material.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryConfirmationField extends StatelessWidget {
  const PasswordRecoveryConfirmationField(
      {super.key,
      required this.confirmation,
      required this.flow,
      required this.hidden,
      required this.callbackAction1,
      required this.callbackAction2});
  final TextEditingController confirmation;
  final PasswordRecoveryState flow;
  final bool hidden;
  final String? Function(String?) callbackAction1;
  final void Function(String) callbackAction2;

  @override
  Widget build(BuildContext context) => TextFormField(
      key: const ValueKey('recovery-confirmation'),
      controller: confirmation,
      enabled: !flow.busy,
      obscureText: hidden,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.newPassword],
      decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu mới'),
      validator: callbackAction1,
      onFieldSubmitted: callbackAction2);
}
