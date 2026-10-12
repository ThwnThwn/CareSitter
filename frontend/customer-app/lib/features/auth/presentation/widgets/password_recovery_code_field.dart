import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryCodeField extends StatelessWidget {
  const PasswordRecoveryCodeField(
      {super.key,
      required this.code,
      required this.flow,
      required this.action1,
      required this.action2});
  final TextEditingController code;
  final PasswordRecoveryState flow;
  final void Function(String) action1;
  final String? Function(String?) action2;
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
      onFieldSubmitted: action1,
      validator: action2);
}
