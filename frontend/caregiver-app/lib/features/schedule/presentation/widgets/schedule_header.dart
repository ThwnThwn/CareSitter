import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_period_label.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ScheduleHeader extends StatelessWidget {
  const ScheduleHeader(
      {super.key,
      required this.pickDate,
      required this.getMonthName,
      required this.selectedDate,
      required this.isMonthView,
      required this.getFullDayOfWeekName,
      required this.buildNavButton,
      required this.previousPeriod,
      required this.nextPeriod});
  final Future<void> Function() pickDate;
  final String Function(int) getMonthName;
  final DateTime selectedDate;
  final bool isMonthView;
  final String Function(int) getFullDayOfWeekName;
  final Widget Function(IconData, void Function()) buildNavButton;
  final void Function() previousPeriod;
  final void Function() nextPeriod;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: AppSpacing.lg,
        right: AppSpacing.md,
        bottom: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left — Month name + Day of week + Big day number
          SchedulePeriodLabel(
              pickDate: pickDate,
              getMonthName: getMonthName,
              selectedDate: selectedDate,
              isMonthView: isMonthView,
              getFullDayOfWeekName: getFullDayOfWeekName),
          // Right — Navigation arrows (week / month aware)
          Row(
            children: [
              buildNavButton(Icons.chevron_left, previousPeriod),
              const SizedBox(width: AppSpacing.xs),
              buildNavButton(Icons.chevron_right, nextPeriod),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
          // Mở date picker giống customer
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded,
                color: AppColors.textSecondary),
            tooltip: 'Chọn ngày',
            onPressed: pickDate,
          ),
        ],
      ),
    );
  }
}
