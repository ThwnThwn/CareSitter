import '../../domain/settings_input_rules.dart';
import 'package:flutter/material.dart';

class ProfileEditEmailField extends StatelessWidget {
  const ProfileEditEmailField(
      {super.key, required this.emailCtrl, required this.onEditRecoveryEmail});
  final TextEditingController emailCtrl;
  final void Function() onEditRecoveryEmail;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: emailCtrl,
        readOnly: true,
        onTap: onEditRecoveryEmail,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Email',
          helperText: 'Chạm để xác minh hoặc đổi email an toàn.',
          prefixIcon: Icon(Icons.email_outlined),
        ),
        validator: SettingsInputRules.email,
      );
}
