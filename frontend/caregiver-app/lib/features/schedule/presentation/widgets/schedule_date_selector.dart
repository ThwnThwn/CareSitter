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
      required this.previousPeriod,
      required this.nextPeriod,
      required this.toggleMonthView,
      required this.onSelectDate});
  final bool isMonthView;
  final DateTime selectedDate;
  final DateTime weekStart;
  final VoidCallback previousPeriod;
  final VoidCallback nextPeriod;
  final VoidCallback toggleMonthView;
  final ValueChanged<DateTime> onSelectDate;
  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Container(
        color: AppColors.cardBackground,
        padding: const EdgeInsets.only(
          top: AppSpacing.compact,
          bottom: AppSpacing.md,
        ),
        child: Column(
          children: [
            // Month + Year label row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${scheduleMonthName(isMonthView ? selectedDate.month : weekStart.month)}, ${isMonthView ? selectedDate.year : weekStart.year}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: AppFontSizes.s14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  _DateActionButton(
                    icon: Icons.chevron_left_rounded,
                    label: isMonthView ? 'Tháng trước' : 'Tuần trước',
                    onPressed: previousPeriod,
                  ),
                  _DateActionButton(
                    icon: Icons.chevron_right_rounded,
                    label: isMonthView ? 'Tháng sau' : 'Tuần sau',
                    onPressed: nextPeriod,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _DateActionButton(
                    icon: Icons.calendar_month_rounded,
                    label:
                        isMonthView ? 'Xem theo tuần' : 'Xem theo lịch tháng',
                    highlighted: true,
                    onPressed: toggleMonthView,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
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

class _DateActionButton extends StatelessWidget {
  const _DateActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: label,
        style: IconButton.styleFrom(
          backgroundColor:
              highlighted ? AppColors.primaryContainer : Colors.transparent,
          foregroundColor:
              highlighted ? AppColors.primary : AppColors.textSecondary,
          minimumSize: const Size(32, 32),
          fixedSize: const Size(32, 32),
          padding: EdgeInsets.zero,
        ),
        icon: Icon(icon, size: 19),
      );
}
