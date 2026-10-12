import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_day_label.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ScheduleDayCell extends StatelessWidget {
  const ScheduleDayCell(
      {super.key,
      required this.chipWidth,
      required this.compact,
      required this.isSelected,
      required this.isCurrentDay,
      required this.date,
      required this.dayName,
      required this.hasSlots});
  final double chipWidth;
  final bool compact;
  final bool isSelected;
  final bool isCurrentDay;
  final DateTime date;
  final String dayName;
  final bool hasSlots;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: chipWidth == double.infinity ? null : chipWidth,
        margin: compact
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : isCurrentDay
                  ? AppColors.primaryContainer
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(
              compact ? AppRadius.compact : AppRadius.xxl),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : isCurrentDay
                    ? AppColors.primaryLight
                    : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: ScheduleDayLabel(
            date: date,
            compact: compact,
            isSelected: isSelected,
            dayName: dayName,
            hasSlots: hasSlots),
      );
}
