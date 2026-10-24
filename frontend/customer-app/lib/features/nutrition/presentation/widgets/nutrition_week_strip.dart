import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class NutritionWeekStrip extends StatelessWidget {
  const NutritionWeekStrip({
    super.key,
    required this.selected,
    this.onSelected,
  });

  final DateTime selected;
  final ValueChanged<DateTime>? onSelected;

  @override
  Widget build(BuildContext context) {
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    return Row(
      children: List.generate(7, (index) {
        final day = monday.add(Duration(days: index));
        final active = _sameDay(day, selected);
        final label =
            day.weekday == DateTime.sunday ? 'CN' : 'T${day.weekday + 1}';
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 6 ? 0 : AppSpacing.xs),
            child: Semantics(
              button: true,
              selected: active,
              label: 'Chọn ngày ${day.day}/${day.month}/${day.year}',
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.compact),
                onTap: active || onSelected == null
                    ? null
                    : () => onSelected!(day),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 50),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.compact),
                    border: Border.all(
                      color: active ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DayText(
                        value: label,
                        color: active
                            ? AppColors.onPrimary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 2),
                      _DayText(
                        value: '${day.day}',
                        color: active
                            ? AppColors.onPrimary
                            : AppColors.textPrimary,
                        emphasized: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayText extends StatelessWidget {
  const _DayText({
    required this.value,
    required this.color,
    this.emphasized = false,
  });

  final String value;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          maxLines: 1,
          style: (emphasized
                  ? Theme.of(context).textTheme.titleSmall
                  : Theme.of(context).textTheme.labelSmall)
              ?.copyWith(
            color: color,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      );
}
