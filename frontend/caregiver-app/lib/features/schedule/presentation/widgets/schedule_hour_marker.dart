import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ScheduleHourMarker extends StatelessWidget {
  const ScheduleHourMarker(
      {super.key, required this.isCurrentHour, required this.isShiftHour});
  final bool isCurrentHour;
  final bool isShiftHour;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 32,
        child: Column(
          children: [
            // Dot — smaller sizes to avoid overflow
            Container(
              width: isCurrentHour ? 10 : 6,
              height: isCurrentHour ? 10 : 6,
              margin: const EdgeInsets.only(top: AppSpacing.xs),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrentHour
                    ? AppColors.primary
                    : isShiftHour
                        ? AppColors.statusConfirmed
                        : AppColors.border,
                border: isCurrentHour
                    ? Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 3)
                    : null,
              ),
            ),
            // Vertical line — fills remaining space
            Expanded(
              child: Center(
                child: Container(
                  width: isShiftHour ? 3 : 1.5,
                  decoration: BoxDecoration(
                    color: isShiftHour
                        ? AppColors.statusConfirmed
                        : AppColors.border.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.s2),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
