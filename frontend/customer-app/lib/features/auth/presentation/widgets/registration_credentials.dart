import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import '../../domain/registration_rules.dart';
import 'register_screen_password_field.dart';

class RegistrationCredentials extends StatelessWidget {
  const RegistrationCredentials({
    super.key,
    required this.password,
    required this.confirmation,
    required this.enabled,
    required this.onSubmit,
  });
  final TextEditingController password, confirmation;
  final bool enabled;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) => Column(children: [
        FadeSlideStaggered(
          index: 5,
          child: RegisterScreenPasswordField(
            controller: password,
            enabled: enabled,
            label: 'Mật khẩu',
            validator: registrationPassword,
          ),
        ),
        const SizedBox(height: AppSpacing.inset),
        FadeSlideStaggered(
          index: 6,
          child: RegisterScreenPasswordField(
            controller: confirmation,
            enabled: enabled,
            label: 'Xác nhận mật khẩu',
            validator: (value) => registrationConfirmation(value, password.text),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
          ),
        ),
      ]);
}
