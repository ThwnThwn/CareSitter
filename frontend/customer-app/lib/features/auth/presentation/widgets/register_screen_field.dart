import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class RegisterScreenField extends StatelessWidget {
  const RegisterScreenField(
      {super.key,
      required this.controller,
      this.keyboardType,
      this.inputFormatters,
      this.validator,
      this.textInputAction = TextInputAction.next,
      this.textCapitalization = TextCapitalization.none,
      required this.label,
      required this.hint,
      this.prefixWidget,
      this.enabled = true,
      required this.icon});
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final String label;
  final String hint;
  final Widget? prefixWidget;
  final IconData icon;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: const TextStyle(
          fontSize: AppFontSizes.s15,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixWidget != null
            ? Padding(
                padding:
                    const EdgeInsets.only(left: AppSpacing.inset, right: 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: AppColors.primary, size: 20),
                    const SizedBox(width: AppSpacing.tight),
                    prefixWidget!,
                  ],
                ),
              )
            : Icon(icon, color: AppColors.primary, size: 20),
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
