import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import '../../domain/login_input_rules.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class LoginIdentifierField extends StatelessWidget {
  const LoginIdentifierField({
    super.key,
    required this.identifierController,
    required this.usePassword,
  });
  final TextEditingController identifierController;
  final bool usePassword;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: identifierController,
        keyboardType: usePassword
            ? TextInputType.emailAddress
            : TextInputType.emailAddress,
        validator: (value) =>
            LoginInputRules.identifier(value, usePassword: usePassword),
        style: const TextStyle(
          fontSize: AppFontSizes.s15,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: usePassword ? 'Email hoặc Số điện thoại' : 'Email',
          hintText: usePassword
              ? 'bichngoc@example.com hoặc 0912333444'
              : 'bichngoc@example.com',
          prefixIcon: Icon(
            usePassword ? Icons.person_outline : Icons.email_outlined,
            color: AppColors.primary,
          ),
        ),
      );
}
