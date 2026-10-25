import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import '../controllers/schedule_selectors.dart';
import '../models/schedule_date_labels.dart';
import 'schedule_day_label.dart';

class ScheduleDayCell extends ConsumerWidget {
  const ScheduleDayCell(
      {super.key,
      required this.date,
      required this.selectedDate,
      required this.onSelectDate,
      this.chipWidth = 48,
      this.compact = false});
  final DateTime date;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final double chipWidth;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = DateUtils.isSameDay(date, selectedDate);
    final isCurrentDay = DateUtils.isSameDay(date, DateTime.now());
    final hasShifts = ref
        .watch(dayShiftsProvider(date).select((shifts) => shifts.isNotEmpty));
    final dayName = scheduleDayName(date.weekday);
    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${date.day}/${date.month}/${date.year}${hasShifts ? ", có ca chăm sóc" : ""}',
      child: GestureDetector(
        onTap: () => onSelectDate(date),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: chipWidth == double.infinity ? null : chipWidth,
          margin: compact
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: AppSpacing.micro),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(
                compact ? AppRadius.compact : AppRadius.control),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : isCurrentDay
                      ? AppColors.primary
                      : AppColors.border,
              width: isSelected || isCurrentDay ? 1.5 : 1,
            ),
          ),
          child: ScheduleDayLabel(
              date: date,
              compact: compact,
              isSelected: isSelected,
              isCurrentDay: isCurrentDay,
              dayName: dayName,
              hasShifts: hasShifts),
        ),
      ),
    );
  }
}
