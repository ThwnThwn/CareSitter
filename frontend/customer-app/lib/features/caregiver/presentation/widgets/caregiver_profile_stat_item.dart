import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class CaregiverProfileStatItem extends StatelessWidget {
  const CaregiverProfileStatItem(
      {super.key, required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.fade,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppFontSizes.s15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.tiny),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: AppFontSizes.s11),
        ),
      ],
    );
  }
}
