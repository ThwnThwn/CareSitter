import 'package:caresitter_customer/features/shift_tracking/presentation/widgets/care_timeline_timeline_event.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

class CareTimelineTimelineItemEventIsLastFields extends StatelessWidget {
  const CareTimelineTimelineItemEventIsLastFields(
      {super.key, required this.event, required this.isLast});
  final CareTimelineTimelineEvent event;
  final bool isLast;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: event.isDone
                  ? event.color.withValues(alpha: 0.15)
                  : AppColors.surfaceVariant,
              shape: BoxShape.circle,
              border: Border.all(
                  color: event.isDone ? event.color : AppColors.border,
                  width: 2),
            ),
            child: Icon(event.icon,
                size: 16,
                color: event.isDone ? event.color : AppColors.textHint),
          ),
          if (!isLast)
            Container(
              width: 2,
              height: 60,
              color: event.isDone
                  ? event.color.withValues(alpha: 0.2)
                  : AppColors.border,
            ),
        ],
      );
}
