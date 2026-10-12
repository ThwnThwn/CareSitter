import 'package:flutter/material.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryEmailField extends StatelessWidget {
  const PasswordRecoveryEmailField(
      {super.key,
      required this.email,
      required this.flow,
      required this.action1,
      required this.action2});
  final TextEditingController email;
  final PasswordRecoveryState flow;
  final void Function(String) action1;
  final String? Function(String?) action2;
  @override
  Widget build(BuildContext context) => TextFormField(
      key: const ValueKey('recovery-email'),
      controller: email,
      enabled: !flow.busy,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: TextInputAction.done,
      onFieldSubmitted: action1,
      decoration: const InputDecoration(
          labelText: 'Email khôi phục', prefixIcon: Icon(Icons.email_outlined)),
      validator: action2);
}
