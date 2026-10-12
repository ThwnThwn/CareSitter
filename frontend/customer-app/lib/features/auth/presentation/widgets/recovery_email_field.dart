import 'package:flutter/material.dart';

class RecoveryEmailField extends StatelessWidget {
  const RecoveryEmailField(
      {super.key,
      required this.email,
      required this.busy,
      required this.hasPassword,
      required this.action1});
  final TextEditingController email;
  final bool busy;
  final bool hasPassword;
  final void Function(String) action1;
  @override
  Widget build(BuildContext context) => TextFormField(
      key: const ValueKey('profile-recovery-email'),
      controller: email,
      enabled: !busy,
      readOnly: !hasPassword,
      onChanged: action1,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(labelText: 'Email cần xác minh'),
      validator: (value) => value != null &&
              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
          ? null
          : 'Vui lòng nhập email hợp lệ.');
}
