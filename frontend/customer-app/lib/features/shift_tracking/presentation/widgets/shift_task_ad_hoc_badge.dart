import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ShiftTaskAdHocBadge extends StatelessWidget {
  const ShiftTaskAdHocBadge({super.key});

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.only(left: AppSpacing.tight),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.tight, vertical: AppSpacing.micro),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.tight),
              ),
              child: const Text(
                'Phát sinh',
                style: TextStyle(
                  fontSize: AppFontSizes.s9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ]);
}
