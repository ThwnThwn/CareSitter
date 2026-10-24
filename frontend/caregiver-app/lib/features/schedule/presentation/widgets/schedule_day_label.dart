import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ScheduleDayLabel extends StatelessWidget {
  const ScheduleDayLabel(
      {super.key,
      required this.date,
      required this.compact,
      required this.isSelected,
      required this.isCurrentDay,
      required this.dayName,
      required this.hasShifts});
  final DateTime date;
  final bool compact;
  final bool isSelected;
  final bool isCurrentDay;
  final String dayName;
  final bool hasShifts;

  @override
  Widget build(BuildContext context) {
    final showIndicator = !isSelected && (isCurrentDay || hasShifts);
    return Stack(
      alignment: Alignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: compact ? AppFontSizes.s14 : AppFontSizes.s18,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: AppSpacing.micro),
              Text(
                dayName,
                style: TextStyle(
                  fontSize: AppFontSizes.s11,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.85)
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        if (showIndicator)
          Positioned(
            bottom: compact ? AppSpacing.xxs : AppSpacing.tight,
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: isCurrentDay
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
