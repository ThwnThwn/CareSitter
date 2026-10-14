import 'package:caregiver_app/features/schedule/presentation/models/timeline_shift_model.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ScheduleShiftTimeLocation extends StatelessWidget {
  const ScheduleShiftTimeLocation({super.key, required this.shift});
  final TimelineShift shift;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: AppSpacing.control,
        runSpacing: AppSpacing.xs,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_rounded,
                  size: 14, color: AppColors.textHint),
              const SizedBox(width: AppSpacing.xs),
              Text(
                shift.duration,
                style: const TextStyle(
                  fontSize: AppFontSizes.s12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.textHint),
              const SizedBox(width: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  shift.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppFontSizes.s12,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
}
