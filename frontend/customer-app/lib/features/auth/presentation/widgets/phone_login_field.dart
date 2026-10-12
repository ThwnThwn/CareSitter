import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class PhoneLoginField extends StatelessWidget {
  const PhoneLoginField(
      {super.key, required this.phoneController, required this.validatePhone});
  final TextEditingController phoneController;
  final String? Function(String?) validatePhone;
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: phoneController,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(11),
        ],
        validator: validatePhone,
        style: const TextStyle(
          fontSize: AppFontSizes.s16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          letterSpacing: 1.5,
        ),
        decoration: InputDecoration(
          labelText: 'Số điện thoại',
          hintText: '0909 123 456',
          prefixIcon: Padding(
            padding: const EdgeInsets.all(AppSpacing.inset),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.tight),
              ),
              child: const Text(
                '🇻🇳 +84',
                style: TextStyle(
                    fontSize: AppFontSizes.s12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      );
}
