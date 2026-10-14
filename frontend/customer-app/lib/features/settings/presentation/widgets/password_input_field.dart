import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';

class PasswordInputField extends StatefulWidget {
  const PasswordInputField(
      {super.key,
      required this.controller,
      required this.label,
      required this.hint,
      required this.validator});
  final TextEditingController controller;
  final String label, hint;
  final FormFieldValidator<String> validator;
  @override
  State<PasswordInputField> createState() => _PasswordInputFieldState();
}

class _PasswordInputFieldState extends State<PasswordInputField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(widget.label,
                style: const TextStyle(
                    fontSize: AppFontSizes.s14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary))),
        TextFormField(
            controller: widget.controller,
            obscureText: _obscure,
            validator: widget.validator,
            decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                    icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    color: AppColors.textSecondary))),
      ]);
}
