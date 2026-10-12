import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class BeneficiaryCreateScreenSectionHeader extends StatelessWidget {
  const BeneficiaryCreateScreenSectionHeader({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: AppFontSizes.s15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.control),
          const Expanded(child: Divider(color: AppColors.divider)),
        ],
      ),
    );
  }
}
