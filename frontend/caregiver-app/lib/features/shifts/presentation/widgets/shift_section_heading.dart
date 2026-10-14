import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';

class ShiftSectionHeading extends StatelessWidget {
  const ShiftSectionHeading({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(
          fontSize: AppFontSizes.s16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary));
}
