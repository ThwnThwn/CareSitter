import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';

class BeneficiaryFieldLabel extends StatelessWidget {
  const BeneficiaryFieldLabel({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.tight),
      child: Text(text,
          style: const TextStyle(
              fontSize: AppFontSizes.s13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)));
}
