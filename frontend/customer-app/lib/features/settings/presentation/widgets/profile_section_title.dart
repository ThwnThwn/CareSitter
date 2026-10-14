import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';

class ProfileSectionTitle extends StatelessWidget {
  const ProfileSectionTitle(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(
          fontSize: AppFontSizes.s14,
          fontWeight: FontWeight.w700,
          color: AppColors.primary));
}
