import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'schedule_day_cell.dart';

class ScheduleWeekStrip extends StatelessWidget {
  const ScheduleWeekStrip(
      {super.key,
      required this.weekStart,
      required this.selectedDate,
      required this.onSelectDate});
  final DateTime weekStart;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.micro),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(
              7,
              (index) => Expanded(
                child: ScheduleDayCell(
                  date: weekStart.add(Duration(days: index)),
                  selectedDate: selectedDate,
                  chipWidth: double.infinity,
                  onSelectDate: onSelectDate,
                ),
              ),
            ),
          ),
        ),
      );
}
