import 'package:flutter/material.dart';

import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ShiftChecklistHeader extends StatelessWidget {
  const ShiftChecklistHeader({
    super.key,
    required this.completed,
    required this.total,
  });

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final label = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Checklist công việc',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: const Text(
            'Theo hợp đồng',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.s11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
    final progress = Text(
      '$completed / $total',
      style: const TextStyle(
        color: AppColors.primary,
        fontSize: AppFontSizes.s13,
        fontWeight: FontWeight.w800,
      ),
    );
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (largeText)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [label, progress],
          )
        else
          Row(children: [Expanded(child: label), progress]),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : completed / total,
            minHeight: 4,
            backgroundColor: AppColors.primaryContainer,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
