import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/features/auth/presentation/controllers/recovery_email_controller.dart';

class RecoveryEmailCodeField extends StatelessWidget {
  const RecoveryEmailCodeField(
      {super.key,
      required this.code,
      required this.flow,
      required this.callbackAction1});
  final TextEditingController code;
  final RecoveryEmailState flow;
  final String? Function(String?) callbackAction1;

  @override
  Widget build(BuildContext context) => TextFormField(
      key: const ValueKey('profile-email-code'),
      controller: code,
      enabled: !flow.busy && !flow.expired,
      keyboardType: TextInputType.number,
      maxLength: 6,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(labelText: 'Mã gồm 6 chữ số'),
      validator: callbackAction1);
}
