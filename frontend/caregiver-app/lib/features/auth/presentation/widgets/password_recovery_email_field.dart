import 'package:flutter/material.dart';
import '../../domain/recovery_input_rules.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryEmailField extends StatelessWidget {
  const PasswordRecoveryEmailField({
    super.key,
    required this.email,
    required this.flow,
    required this.onSubmit,
  });
  final TextEditingController email;
  final PasswordRecoveryState flow;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) => TextFormField(
      key: const ValueKey('recovery-email'),
      controller: email,
      enabled: !flow.busy,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => onSubmit(),
      decoration: const InputDecoration(
          labelText: 'Email khôi phục', prefixIcon: Icon(Icons.email_outlined)),
      validator: RecoveryInputRules.email);
}
