import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class SettingsBeneficiaryTitle extends StatelessWidget {
  const SettingsBeneficiaryTitle({super.key});

  @override
  Widget build(BuildContext context) => const Row(children: [
        Icon(Icons.directions_walk_rounded, color: AppColors.primary, size: 18),
        SizedBox(width: AppSpacing.sm),
        Text('Người thân được chăm sóc',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: AppFontSizes.s16,
                fontWeight: FontWeight.w700)),
      ]);
}
