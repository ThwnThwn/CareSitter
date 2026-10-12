import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class LoginPasswordField extends StatelessWidget {
  const LoginPasswordField(
      {super.key,
      required this.passwordController,
      required this.obscurePassword,
      required this.validatePassword,
      required this.callbackAction1});
  final TextEditingController passwordController;
  final bool obscurePassword;
  final String? Function(String?) validatePassword;
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: passwordController,
        obscureText: obscurePassword,
        validator: validatePassword,
        style: const TextStyle(
          fontSize: AppFontSizes.s15,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: 'Mật khẩu',
          hintText: '••••••••',
          prefixIcon: const Icon(
            Icons.lock_outline,
            color: AppColors.primary,
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: AppColors.textSecondary,
            ),
            onPressed: callbackAction1,
          ),
        ),
      );
}
