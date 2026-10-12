import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/auth/presentation/widgets/login_hero_tokens.dart';

class LoginHeroInputField extends StatelessWidget {
  const LoginHeroInputField(
      {super.key,
      required this.controller,
      required this.label,
      required this.hint,
      required this.icon,
      this.obscureText = false,
      this.keyboardType,
      this.validator,
      this.textInputAction,
      this.autofillHints,
      this.enabled = true,
      this.onFieldSubmitted,
      this.suffixIcon});

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final void Function(String)? onFieldSubmitted;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppFontSizes.s13,
            fontWeight: FontWeight.w500,
            color: LoginHeroTokens.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.tight),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          enabled: enabled,
          onFieldSubmitted: onFieldSubmitted,
          style: const TextStyle(
            fontSize: AppFontSizes.s14,
            color: LoginHeroTokens.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
