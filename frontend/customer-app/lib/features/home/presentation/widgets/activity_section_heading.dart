import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';

class ActivitySectionHeading extends StatelessWidget {
  const ActivitySectionHeading({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppFontSizes.s17,
          fontWeight: FontWeight.w800));
}
