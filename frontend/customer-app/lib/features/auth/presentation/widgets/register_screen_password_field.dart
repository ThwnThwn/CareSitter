import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class RegisterScreenPasswordField extends StatefulWidget {
  const RegisterScreenPasswordField(
      {super.key,
      required this.controller,
      required this.validator,
      this.enabled = true,
      this.textInputAction = TextInputAction.next,
      this.onSubmitted,
      required this.label});
  final TextEditingController controller;
  final bool enabled;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final String label;
  @override
  State<RegisterScreenPasswordField> createState() =>
      _RegisterScreenPasswordFieldState();
}

class _RegisterScreenPasswordFieldState
    extends State<RegisterScreenPasswordField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscure,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      style: const TextStyle(
          fontSize: AppFontSizes.s15,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: '••••••••',
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: AppColors.primary, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.textHint,
            size: 20,
          ),
          tooltip: _obscure
              ? 'Hiện ${widget.label.toLowerCase()}'
              : 'Ẩn ${widget.label.toLowerCase()}',
          onPressed: widget.enabled
              ? () => setState(() => _obscure = !_obscure)
              : null,
        ),
        filled: true,
        fillColor: AppInputStyle.fillColor,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        border: AppInputStyle.enabledBorder,
        enabledBorder: AppInputStyle.enabledBorder,
        focusedBorder: AppInputStyle.focusedBorder,
        errorBorder: AppInputStyle.errorBorder,
        focusedErrorBorder: AppInputStyle.errorBorder,
      ),
    );
  }
}
