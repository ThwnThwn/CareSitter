import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class EmailLoginField extends StatelessWidget {
  const EmailLoginField(
      {super.key, required this.emailController, required this.validateEmail});
  final TextEditingController emailController;
  final String? Function(String?) validateEmail;
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: emailController,
        keyboardType: TextInputType.emailAddress,
        validator: validateEmail,
        style: const TextStyle(
          fontSize: AppFontSizes.s15,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: 'Địa chỉ Email',
          hintText: 'example@gmail.com',
          prefixIcon: const Icon(
            Icons.email_outlined,
            color: AppColors.textSecondary,
            size: 22,
          ),
          filled: true,
          fillColor: AppColors.cardBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      );
}
