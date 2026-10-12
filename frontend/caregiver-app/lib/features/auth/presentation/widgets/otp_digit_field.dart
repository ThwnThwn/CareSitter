import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class OtpDigitField extends StatelessWidget {
  const OtpDigitField(
      {super.key,
      required this.focusNodes,
      required this.index,
      required this.controllers,
      required this.onDigitChanged});
  final List<FocusNode> focusNodes;
  final int index;
  final List<TextEditingController> controllers;
  final void Function(int, String) onDigitChanged;
  @override
  Widget build(BuildContext context) {
    final isFocused = focusNodes[index].hasFocus;
    final hasValue = controllers[index].text.isNotEmpty;
    return SizedBox(
      width: 48,
      height: 56,
      child: TextField(
        controller: controllers[index],
        focusNode: focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: AppFontSizes.s22,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor:
              isFocused ? AppColors.primaryContainer : AppColors.cardBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(
              color: hasValue ? AppColors.primary : AppColors.border,
              width: isFocused ? 2 : 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(
              color: hasValue ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        onChanged: (v) => onDigitChanged(index, v),
      ),
    );
  }
}
