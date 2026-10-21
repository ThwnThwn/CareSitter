import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class NutritionExpansionCard extends StatelessWidget {
  const NutritionExpansionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.cardBackground,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: AppColors.primaryContainer,
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            childrenPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
            ).copyWith(bottom: AppSpacing.md),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            iconColor: AppColors.primary,
            collapsedIconColor: AppColors.textSecondary,
            title: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            subtitle: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            children: children,
          ),
        ),
      );
}
