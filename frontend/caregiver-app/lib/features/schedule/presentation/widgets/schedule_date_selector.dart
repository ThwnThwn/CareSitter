import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ScheduleDateSelector extends StatelessWidget {
  const ScheduleDateSelector(
      {super.key,
      required this.getMonthName,
      required this.isMonthView,
      required this.selectedDate,
      required this.weekStart,
      required this.buildMonthGrid,
      required this.buildWeekStrip});
  final String Function(int) getMonthName;
  final bool isMonthView;
  final DateTime selectedDate;
  final DateTime weekStart;
  final Widget Function() buildMonthGrid;
  final Widget Function() buildWeekStrip;
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
                    '${getMonthName(isMonthView ? selectedDate.month : weekStart.month)} ${isMonthView ? selectedDate.year : weekStart.year}',
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
            isMonthView ? buildMonthGrid() : buildWeekStrip(),
          ],
        ),
      ),
    );
  }
}
