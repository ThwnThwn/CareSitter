import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import '../../domain/registration_rules.dart';
import 'registration_password_field.dart';

class RegistrationCredentials extends StatelessWidget {
  const RegistrationCredentials(
      {super.key,
      required this.password,
      required this.confirmation,
      required this.enabled,
      required this.onSubmit});
  final TextEditingController password, confirmation;
  final bool enabled;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) => Column(children: [
        RegistrationPasswordField(
            controller: password,
            enabled: enabled,
            label: 'Mật khẩu',
            validator: registrationPassword),
        const SizedBox(height: AppSpacing.md),
        RegistrationPasswordField(
            controller: confirmation,
            enabled: enabled,
            label: 'Xác nhận mật khẩu',
            validator: (value) => registrationConfirmation(value, password.text),
            onSubmitted: (_) => onSubmit()),
      ]);
}
