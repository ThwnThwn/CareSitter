import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ScheduleHourLabel extends StatelessWidget {
  const ScheduleHourLabel(
      {super.key, required this.timeLabel, required this.isCurrentHour});
  final String timeLabel;
  final bool isCurrentHour;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 60,
        child: Padding(
          padding:
              const EdgeInsets.only(left: AppSpacing.md, top: AppSpacing.micro),
          child: Text(
            timeLabel,
            style: TextStyle(
              fontSize: AppFontSizes.s13,
              fontWeight: isCurrentHour ? FontWeight.w700 : FontWeight.w400,
              color: isCurrentHour ? AppColors.primary : AppColors.textHint,
            ),
          ),
        ),
      );
}
