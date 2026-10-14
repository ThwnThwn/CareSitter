import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';

class OtpDigitField extends StatelessWidget {
  const OtpDigitField(
      {super.key,
      required this.controller,
      required this.focusNode,
      required this.onChanged});
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([focusNode, controller]),
        builder: (context, _) {
          final isFocused = focusNode.hasFocus;
          final hasValue = controller.text.isNotEmpty;
          return SizedBox(
            width: 46,
            height: 54,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: AppFontSizes.s20,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: isFocused
                    ? AppColors.primaryContainer
                    : AppColors.cardBackground,
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
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.compact),
              ),
              onChanged: onChanged,
            ),
          );
        },
      );
}
