import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ScheduleDayLabel extends StatelessWidget {
  const ScheduleDayLabel(
      {super.key,
      required this.date,
      required this.compact,
      required this.isSelected,
      required this.dayName,
      required this.hasSlots});
  final DateTime date;
  final bool compact;
  final bool isSelected;
  final String dayName;
  final bool hasSlots;

  @override
  Widget build(BuildContext context) => Column(
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
          // Dot indicator for days with availability
          if (hasSlots && !isSelected) ...[
            SizedBox(height: compact ? 2 : 4),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      );
}
