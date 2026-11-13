import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class NutritionMealAccordion extends StatelessWidget {
  const NutritionMealAccordion(
      {super.key,
      required this.title,
      required this.icon,
      required this.children,
      this.tinted = false});
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool tinted;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.inset),
            childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.inset,
                AppSpacing.xs, AppSpacing.inset, AppSpacing.md),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
          backgroundColor: AppColors.surface,
            collapsedBackgroundColor:
                tinted ? AppColors.background : AppColors.surface,
            iconColor: AppColors.primary,
            collapsedIconColor: AppColors.primary,
            leading: Icon(icon, size: 18, color: AppColors.primary),
            title: Text(title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
            children: children,
          ),
        ),
      );
}
