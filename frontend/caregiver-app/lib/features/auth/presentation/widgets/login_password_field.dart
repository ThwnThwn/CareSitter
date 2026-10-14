import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import '../../domain/login_input_rules.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class LoginPasswordField extends StatelessWidget {
  const LoginPasswordField(
      {super.key,
      required this.passwordController,
      required this.obscurePassword,
      required this.onTogglePassword});
  final TextEditingController passwordController;
  final bool obscurePassword;
  final void Function() onTogglePassword;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: passwordController,
        obscureText: obscurePassword,
        validator: LoginInputRules.password,
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
            onPressed: onTogglePassword,
          ),
        ),
      );
}
