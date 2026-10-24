import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../models/nutrition_menu_overview_model.dart';
import 'nutrition_week_strip.dart';

class NutritionMenuOverview extends StatelessWidget {
  const NutritionMenuOverview({
    super.key,
    required this.overview,
    this.onDateSelected,
  });

  final NutritionMenuOverviewModel overview;
  final ValueChanged<DateTime>? onDateSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: const Border.fromBorderSide(
          BorderSide(color: AppColors.border),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OverviewHeader(overview: overview),
              if (overview.hasMeals) ...[
                const SizedBox(height: AppSpacing.md),
                _OverviewMetrics(overview: overview, compact: compact),
              ],
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              _CalendarSection(
                overview: overview,
                onDateSelected: onDateSelected,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({required this.overview});

  final NutritionMenuOverviewModel overview;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.compact),
                ),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.compact),
              Expanded(
                child: Text(
                  overview.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            overview.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatusBadge(overview: overview),
        ],
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.overview});

  final NutritionMenuOverviewModel overview;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (overview.tone) {
      NutritionMenuOverviewTone.success => (
          AppColors.successLight,
          AppColors.success
        ),
      NutritionMenuOverviewTone.primary => (
          AppColors.primaryContainer,
          AppColors.primary
        ),
      NutritionMenuOverviewTone.warning => (
          AppColors.warningLight,
          AppColors.warning
        ),
      NutritionMenuOverviewTone.error => (
          AppColors.errorLight,
          AppColors.error
        ),
      NutritionMenuOverviewTone.neutral => (
          AppColors.background,
          AppColors.textSecondary
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        overview.badgeLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _OverviewMetrics extends StatelessWidget {
  const _OverviewMetrics({required this.overview, required this.compact});

  final NutritionMenuOverviewModel overview;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Text(
        '${overview.mealCount} bữa • ${overview.totalKcal.round()} kcal dự kiến',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _Metric(
            value: '${overview.mealCount}',
            label: 'bữa trong ngày',
            icon: Icons.schedule_rounded,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _Metric(
            value: '${overview.totalKcal.round()}',
            label: 'kcal dự kiến',
            icon: Icons.local_fire_department_outlined,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _Metric(
            value: '${overview.mealCount}/3',
            label: 'đã có món',
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.compact),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(value, style: _metricStyle(context, emphasized: true)),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _metricStyle(context),
            ),
          ],
        ),
      );

  TextStyle? _metricStyle(BuildContext context, {bool emphasized = false}) =>
      (emphasized
              ? Theme.of(context).textTheme.titleSmall
              : Theme.of(context).textTheme.labelSmall)
          ?.copyWith(
        color: emphasized ? AppColors.textPrimary : AppColors.textSecondary,
        fontWeight: emphasized ? FontWeight.w800 : null,
      );
}

class _CalendarSection extends StatelessWidget {
  const _CalendarSection({
    required this.overview,
    required this.onDateSelected,
  });

  final NutritionMenuOverviewModel overview;
  final ValueChanged<DateTime>? onDateSelected;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lịch thực đơn',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${overview.plannedDate.month}/${overview.plannedDate.year}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          NutritionWeekStrip(
            selected: overview.plannedDate,
            onSelected: onDateSelected,
          ),
        ],
      );
}
