import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class HomeCaregiverDetailsLink extends StatelessWidget {
  const HomeCaregiverDetailsLink({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.compact),
        ),
        child: const Text(
          'Chi tiết',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: AppFontSizes.s12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
