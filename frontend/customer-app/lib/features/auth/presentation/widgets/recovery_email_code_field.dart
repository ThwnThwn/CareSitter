import 'package:flutter/material.dart';
import '../../domain/recovery_input_rules.dart';
import 'package:flutter/services.dart';

class RecoveryEmailCodeField extends StatelessWidget {
  const RecoveryEmailCodeField(
      {super.key,
      required this.code,
      required this.busy,
      required this.expired});
  final TextEditingController code;
  final bool busy;
  final bool expired;
  @override
  Widget build(BuildContext context) => TextFormField(
      key: const ValueKey('profile-email-code'),
      controller: code,
      enabled: !busy && !expired,
      keyboardType: TextInputType.number,
      maxLength: 6,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(labelText: 'Mã gồm 6 chữ số'),
      validator: RecoveryInputRules.code);
}
