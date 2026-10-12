import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class ShiftTaskRequiredBadge extends StatelessWidget {
  const ShiftTaskRequiredBadge({super.key});

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.only(left: AppSpacing.xs),
              padding: const EdgeInsets.symmetric(
                  horizontal: 5, vertical: AppSpacing.micro),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'Bắt buộc',
                style: TextStyle(
                  fontSize: AppFontSizes.s9,
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ]);
}
