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
          filled: true,
          fillColor: AppColors.surface,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelText: usePassword ? 'Email hoặc Số điện thoại' : 'Email',
          hintText: usePassword
              ? 'Nhập email hoặc số điện thoại của bạn'
              : 'Nhập email của bạn',
          prefixIcon: Icon(
            usePassword ? Icons.person_outline : Icons.email_outlined,
            color: AppColors.primary,
          ),
        ),
      );
}
