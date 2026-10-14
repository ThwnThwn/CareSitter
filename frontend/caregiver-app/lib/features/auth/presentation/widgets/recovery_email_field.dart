import 'package:flutter/material.dart';
import '../../domain/recovery_input_rules.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/recovery_email_controller.dart';

class RecoveryEmailField extends StatelessWidget {
  const RecoveryEmailField(
      {super.key,
      required this.email,
      required this.flow,
      required this.onEmailChanged});
  final TextEditingController email;
  final RecoveryEmailState flow;
  final void Function(String) onEmailChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
        key: const ValueKey('profile-recovery-email'),
        controller: email,
        enabled: !flow.busy,
        readOnly: !flow.hasPassword,
        onChanged: onEmailChanged,
        validator: RecoveryInputRules.email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Email cần xác minh'),
      );
}
