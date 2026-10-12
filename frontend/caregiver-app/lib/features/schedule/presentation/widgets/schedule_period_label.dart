import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class SchedulePeriodLabel extends StatelessWidget {
  const SchedulePeriodLabel(
      {super.key,
      required this.pickDate,
      required this.getMonthName,
      required this.selectedDate,
      required this.isMonthView,
      required this.getFullDayOfWeekName});
  final Future<void> Function() pickDate;
  final String Function(int) getMonthName;
  final DateTime selectedDate;
  final bool isMonthView;
  final String Function(int) getFullDayOfWeekName;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month + toggle chevron
            GestureDetector(
              onTap: pickDate,
              child: Row(
                children: [
                  Text(
                    getMonthName(selectedDate.month),
                    style: const TextStyle(
                      fontSize: AppFontSizes.s14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AnimatedRotation(
                    turns: isMonthView ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.compact),
                  if (!isMonthView)
                    Flexible(
                      child: Text(
                        getFullDayOfWeekName(selectedDate.weekday),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppFontSizes.s14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.micro),
            Text(
              '${selectedDate.day}',
              style: const TextStyle(
                fontSize: AppFontSizes.s56,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.1,
                letterSpacing: -2,
              ),
            ),
          ],
        ),
      );
}
