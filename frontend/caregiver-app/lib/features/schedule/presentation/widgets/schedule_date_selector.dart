import '../models/schedule_date_labels.dart';
import 'schedule_month_grid.dart';
import 'schedule_week_strip.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ScheduleDateSelector extends StatelessWidget {
  const ScheduleDateSelector(
      {super.key,
      required this.isMonthView,
      required this.selectedDate,
      required this.weekStart,
      required this.onSelectDate});
  final bool isMonthView;
  final DateTime selectedDate;
  final DateTime weekStart;
  final ValueChanged<DateTime> onSelectDate;
  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Container(
        color: AppColors.cardBackground,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.compact),
        child: Column(
          children: [
            // Month + Year label row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Text(
                    '${scheduleMonthName(isMonthView ? selectedDate.month : weekStart.month)} ${isMonthView ? selectedDate.year : weekStart.year}',
                    style: const TextStyle(
                      fontSize: AppFontSizes.s13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.compact),
            // ── Week strip or Month grid ──
            isMonthView
                ? ScheduleMonthGrid(
                    selectedDate: selectedDate, onSelectDate: onSelectDate)
                : ScheduleWeekStrip(
                    weekStart: weekStart,
                    selectedDate: selectedDate,
                    onSelectDate: onSelectDate),
          ],
        ),
      ),
    );
  }
}
