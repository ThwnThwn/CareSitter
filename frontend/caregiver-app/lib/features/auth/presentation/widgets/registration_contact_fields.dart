import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import '../../domain/registration_rules.dart';

class RegistrationContactFields extends StatelessWidget {
  const RegistrationContactFields(
      {super.key,
      required this.name,
      required this.email,
      required this.phone,
      required this.enabled});
  final TextEditingController name, email, phone;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(children: [
        TextFormField(
          controller: name,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          validator: registrationName,
          decoration: const InputDecoration(
              labelText: 'Họ và tên',
              prefixIcon: Icon(Icons.person_outline_rounded)),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: email,
          enabled: enabled,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          validator: registrationEmail,
          decoration: const InputDecoration(
              labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: phone,
          enabled: enabled,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10)
          ],
          validator: registrationPhone,
          decoration: const InputDecoration(
              labelText: 'Số điện thoại', prefixIcon: Icon(Icons.phone_outlined)),
        ),
      ]);
}
