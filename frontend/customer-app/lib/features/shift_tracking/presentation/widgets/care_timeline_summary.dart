import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';

class CareTimelineSummary extends StatelessWidget {
  const CareTimelineSummary(
      {super.key,
      required this.avatar,
      required this.name,
      required this.schedule,
      required this.duration});
  final String avatar, name, schedule, duration;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        color: AppColors.cardBackground,
        child: Row(children: [
          CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primaryContainer,
              child: Text(avatar,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: AppFontSizes.s11,
                      fontWeight: FontWeight.w800))),
          const SizedBox(width: AppSpacing.compact),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: AppFontSizes.s14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                Text(schedule,
                    style: const TextStyle(
                        fontSize: AppFontSizes.s12,
                        color: AppColors.textSecondary)),
              ])),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.control, vertical: 5),
            decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.compact)),
            child: Text(duration,
                style: const TextStyle(
                    fontSize: AppFontSizes.s12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ),
        ]),
      );
}
