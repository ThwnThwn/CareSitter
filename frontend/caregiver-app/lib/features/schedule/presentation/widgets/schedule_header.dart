import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_period_label.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ScheduleHeader extends StatelessWidget {
  const ScheduleHeader(
      {super.key,
      required this.pickDate,
      required this.selectedDate,
      required this.isMonthView,
      required this.previousPeriod,
      required this.nextPeriod});
  final Future<void> Function() pickDate;
  final DateTime selectedDate;
  final bool isMonthView;
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
              selectedDate: selectedDate,
              isMonthView: isMonthView),
          // Right — Navigation arrows (week / month aware)
          Row(
            children: [
              _PeriodButton(
                  icon: Icons.chevron_left,
                  label: 'Kỳ trước',
                  onTap: previousPeriod),
              const SizedBox(width: AppSpacing.xs),
              _PeriodButton(
                  icon: Icons.chevron_right,
                  label: 'Kỳ sau',
                  onTap: nextPeriod),
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

class _PeriodButton extends StatelessWidget {
  const _PeriodButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 20, color: AppColors.textSecondary),
          ),
        ),
      );
}
