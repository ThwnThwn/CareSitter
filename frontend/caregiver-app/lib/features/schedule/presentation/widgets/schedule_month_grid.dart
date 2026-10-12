import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ScheduleMonthGrid extends StatelessWidget {
  const ScheduleMonthGrid(
      {super.key, required this.selectedDate, required this.buildDayCell});
  final DateTime selectedDate;
  final Widget Function(DateTime, {double chipWidth, bool compact})
      buildDayCell;
  @override
  Widget build(BuildContext context) {
    final year = selectedDate.year;
    final month = selectedDate.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // offset: Monday=1 → 0-indexed offset (Mon=0)
    final startOffset = (firstDay.weekday - 1) % 7;

    // Day-of-week header (T2..CN)
    const dayHeaders = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          // Header row
          Row(
            children: dayHeaders
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: AppFontSizes.s11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Grid cells
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
              childAspectRatio: 0.9,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startOffset) {
                return const SizedBox
                    .shrink(); // empty cells before month start
              }
              final day = index - startOffset + 1;
              final date = DateTime(year, month, day);
              return buildDayCell(date,
                  chipWidth: double.infinity, compact: true);
            },
          ),
        ],
      ),
    );
  }
}
