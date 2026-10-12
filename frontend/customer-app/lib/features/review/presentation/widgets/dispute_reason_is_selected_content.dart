import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class DisputeReasonIsSelectedContent extends StatelessWidget {
  const DisputeReasonIsSelectedContent(
      {super.key,
      required this.onSelected,
      required this.r,
      required this.isSelected});
  final ValueChanged<String> onSelected;
  final String r;
  final bool isSelected;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onSelected(r),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.inset, vertical: AppSpacing.compact),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.errorLight : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: isSelected ? AppColors.error : AppColors.border,
                width: isSelected ? 2 : 1),
          ),
          child: Row(children: [
            Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? AppColors.error : AppColors.textHint,
                size: 20),
            const SizedBox(width: AppSpacing.control),
            Text(r,
                style: TextStyle(
                    fontSize: AppFontSizes.s13,
                    fontWeight: FontWeight.w600,
                    color:
                        isSelected ? AppColors.error : AppColors.textPrimary)),
          ]),
        ),
      );
}
