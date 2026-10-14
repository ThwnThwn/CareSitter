import 'package:flutter/material.dart';
import '../../domain/recovery_input_rules.dart';
import 'package:flutter/services.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/password_recovery_controller.dart';

class PasswordRecoveryCodeField extends StatelessWidget {
  const PasswordRecoveryCodeField({
    super.key,
    required this.code,
    required this.flow,
    required this.onSubmit,
  });
  final TextEditingController code;
  final PasswordRecoveryState flow;
  final Future<void> Function() onSubmit;
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
      onFieldSubmitted: (_) => onSubmit(),
      validator: RecoveryInputRules.code);
}
