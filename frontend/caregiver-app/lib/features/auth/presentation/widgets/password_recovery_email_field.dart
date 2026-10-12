import 'package:flutter/material.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryEmailField extends StatelessWidget {
  const PasswordRecoveryEmailField(
      {super.key,
      required this.email,
      required this.flow,
      required this.callbackAction1,
      required this.callbackAction2});
  final TextEditingController email;
  final PasswordRecoveryState flow;
  final void Function(String) callbackAction1;
  final String? Function(String?) callbackAction2;

  @override
  Widget build(BuildContext context) => TextFormField(
      key: const ValueKey('recovery-email'),
      controller: email,
      enabled: !flow.busy,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: callbackAction1,
      decoration: const InputDecoration(
          labelText: 'Email khôi phục', prefixIcon: Icon(Icons.email_outlined)),
      validator: callbackAction2);
}
