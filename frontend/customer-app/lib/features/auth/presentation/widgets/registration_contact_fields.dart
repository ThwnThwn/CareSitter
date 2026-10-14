import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/widgets/fade_slide_staggered.dart';
import '../../domain/registration_rules.dart';
import 'register_screen_field.dart';
import 'registration_phone_field.dart';

class RegistrationContactFields extends StatelessWidget {
  const RegistrationContactFields({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.enabled,
  });
  final TextEditingController name, email, phone;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(children: [
        FadeSlideStaggered(
          index: 2,
          child: RegisterScreenField(
            controller: name,
            enabled: enabled,
            label: 'Họ và tên',
            hint: 'Nguyễn Văn A',
            icon: Icons.person_outline_rounded,
            validator: registrationName,
            textCapitalization: TextCapitalization.words,
          ),
        ),
        const SizedBox(height: AppSpacing.inset),
        FadeSlideStaggered(
          index: 3,
          child: RegisterScreenField(
            controller: email,
            enabled: enabled,
            label: 'Email',
            hint: 'example@email.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: registrationEmail,
          ),
        ),
        const SizedBox(height: AppSpacing.inset),
        RegistrationPhoneField(controller: phone, enabled: enabled),
      ]);
}
