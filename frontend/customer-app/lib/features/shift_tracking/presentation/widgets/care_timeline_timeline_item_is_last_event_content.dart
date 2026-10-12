import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/care_timeline_timeline_event.dart';
import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class CareTimelineTimelineItemIsLastEventContent extends StatelessWidget {
  const CareTimelineTimelineItemIsLastEventContent(
      {super.key, required this.isLast, required this.event});
  final bool isLast;
  final CareTimelineTimelineEvent event;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.wide),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title,
                  style: TextStyle(
                    fontSize: AppFontSizes.s14,
                    fontWeight: FontWeight.w700,
                    color: event.isDone
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                  )),
              const SizedBox(height: AppSpacing.xs),
              Text(event.description,
                  style: TextStyle(
                    fontSize: AppFontSizes.s12,
                    color: event.isDone
                        ? AppColors.textSecondary
                        : AppColors.textHint,
                    height: 1.4,
                  )),
              if (!event.isDone && event.title != 'Check-out (dự kiến)') ...[
                const SizedBox(height: AppSpacing.tight),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.tiny),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Text('Đang diễn ra',
                      style: TextStyle(
                          fontSize: AppFontSizes.s10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning)),
                ),
              ],
            ],
          ),
        ),
      );
}
