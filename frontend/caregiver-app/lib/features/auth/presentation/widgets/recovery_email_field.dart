import 'package:flutter/material.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/recovery_email_controller.dart';

class RecoveryEmailField extends StatelessWidget {
  const RecoveryEmailField(
      {super.key,
      required this.email,
      required this.flow,
      required this.callbackAction1,
      required this.callbackAction2});
  final TextEditingController email;
  final RecoveryEmailState flow;
  final void Function(String) callbackAction1;
  final String? Function(String?) callbackAction2;

  @override
  Widget build(BuildContext context) => TextFormField(
      key: const ValueKey('profile-recovery-email'),
      controller: email,
      enabled: !flow.busy,
      readOnly: !flow.hasPassword,
      onChanged: callbackAction1,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(labelText: 'Email cần xác minh'),
      validator: callbackAction2);
}
