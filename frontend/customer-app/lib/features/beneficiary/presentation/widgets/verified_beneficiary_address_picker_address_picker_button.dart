import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class VerifiedBeneficiaryAddressPickerAddressPickerButton
    extends StatelessWidget {
  const VerifiedBeneficiaryAddressPickerAddressPickerButton(
      {super.key,
      required this.onTap,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      this.selected = false});

  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.inset),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primaryContainer
                : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: AppSpacing.compact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.tiny),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppFontSizes.s13)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint),
            ],
          ),
        ),
      );
}
