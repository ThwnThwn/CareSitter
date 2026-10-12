import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class RegistrationIntro extends StatelessWidget {
  const RegistrationIntro({super.key});

  @override
  Widget build(BuildContext context) => const Text(
        'Tham gia đội ngũ chăm sóc',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppFontSizes.s22,
          fontWeight: FontWeight.w700,
        ),
      );
}
