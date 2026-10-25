import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/schedule/presentation/models/timeline_shift_model.dart';
import 'package:flutter/material.dart';

class ScheduleShiftTimeLocation extends StatelessWidget {
  const ScheduleShiftTimeLocation({super.key, required this.shift});

  final TimelineShift shift;

  @override
  Widget build(BuildContext context) {
    final tags = shift.taskTitles.isNotEmpty
        ? shift.taskTitles
        : _conditionTag(shift.beneficiaryCondition, shift.serviceName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.tight,
          runSpacing: AppSpacing.xs,
          children: [
            for (final tag in tags.take(2))
              _ScheduleInfoChip(
                icon: Icons.check_circle_outline_rounded,
                label: tag,
              ),
            _ScheduleInfoChip(
              icon: Icons.schedule_rounded,
              label: shift.duration,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 14,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                shift.address,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppFontSizes.s11,
                  height: 1.25,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<String> _conditionTag(String? condition, String serviceName) {
    final value = condition?.trim();
    if (value == null ||
        value.isEmpty ||
        value == 'Chưa có thông tin' ||
        value.toLowerCase() == serviceName.trim().toLowerCase()) {
      return const [];
    }
    return [value];
  }
}

class _ScheduleInfoChip extends StatelessWidget {
  const _ScheduleInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 164),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.tight,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.tight),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppFontSizes.s10,
                  height: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
}
