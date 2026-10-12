import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftSafetyItem extends StatelessWidget {
  const ShiftSafetyItem({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.tight),
            child: Icon(Icons.circle, size: 5, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: AppFontSizes.s13,
                      color: AppColors.textSecondary,
                      height: 1.4))),
        ],
      ),
    );
  }
}
