import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/schedule/presentation/models/schedule_date_labels.dart';
import 'package:caregiver_app/features/schedule/presentation/models/timeline_shift_model.dart';
import 'package:flutter/material.dart';

class ScheduleDailySummary extends StatelessWidget {
  const ScheduleDailySummary({
    super.key,
    required this.selectedDate,
    required this.shifts,
  });

  final DateTime selectedDate;
  final List<TimelineShift> shifts;

  @override
  Widget build(BuildContext context) {
    final totalMinutes = shifts.fold<int>(
      0,
      (total, shift) => total + shift.durationMinutes,
    );
    final totalHours = totalMinutes ~/ 60;
    final remainingMinutes = totalMinutes % 60;
    final totalLabel = remainingMinutes == 0
        ? '$totalHours giờ'
        : '$totalHours giờ $remainingMinutes phút';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.inset,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${scheduleFullDayName(selectedDate.weekday)}, '
              '${selectedDate.day.toString().padLeft(2, '0')}/'
              '${selectedDate.month.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: AppFontSizes.s13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '${shifts.length} ${shifts.length == 1 ? 'ca làm việc' : 'ca làm việc'} · $totalLabel',
            style: const TextStyle(
              fontSize: AppFontSizes.s11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
