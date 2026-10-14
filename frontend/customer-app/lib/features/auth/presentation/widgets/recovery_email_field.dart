import 'package:flutter/material.dart';
import '../../domain/recovery_input_rules.dart';

class RecoveryEmailField extends StatelessWidget {
  const RecoveryEmailField(
      {super.key,
      required this.email,
      required this.busy,
      required this.hasPassword,
      required this.onEmailChanged});
  final TextEditingController email;
  final bool busy;
  final bool hasPassword;
  final void Function(String) onEmailChanged;
  @override
  Widget build(BuildContext context) => TextFormField(
      key: const ValueKey('profile-recovery-email'),
      controller: email,
      enabled: !busy,
      readOnly: !hasPassword,
      onChanged: onEmailChanged,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(labelText: 'Email cần xác minh'),
      validator: RecoveryInputRules.email);
}
