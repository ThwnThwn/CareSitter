import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BeneficiaryEditCareLevelChoice extends StatelessWidget {
  const BeneficiaryEditCareLevelChoice(
      {super.key,
      required this.onSelected,
      required this.level,
      required this.isSelected,
      required this.color});
  final ValueChanged<String> onSelected;
  final String level;
  final bool isSelected;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: () => onSelected(level),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.13)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.compact),
              border: Border.all(
                color: isSelected ? color : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              level,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppFontSizes.s13,
                fontWeight: FontWeight.w700,
                color: isSelected ? color : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
}
