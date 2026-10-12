import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryCodeField extends StatelessWidget {
  const PasswordRecoveryCodeField(
      {super.key,
      required this.code,
      required this.flow,
      required this.callbackAction1,
      required this.callbackAction2});
  final TextEditingController code;
  final PasswordRecoveryState flow;
  final void Function(String) callbackAction1;
  final String? Function(String?) callbackAction2;

  @override
  Widget build(BuildContext context) => TextFormField(
      key: const ValueKey('recovery-code'),
      controller: code,
      enabled: !flow.busy && !flow.expired,
      keyboardType: TextInputType.number,
      autofillHints: const [AutofillHints.oneTimeCode],
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(labelText: 'Mã gồm 6 chữ số'),
      onFieldSubmitted: callbackAction1,
      validator: callbackAction2);
}
