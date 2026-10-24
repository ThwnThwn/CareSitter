import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/widgets/beneficiary_avatar.dart';
import 'package:caregiver_app/features/schedule/presentation/models/timeline_shift_model.dart';
import 'package:flutter/material.dart';

class ScheduleShiftRecipientStatus extends StatelessWidget {
  const ScheduleShiftRecipientStatus({
    super.key,
    required this.shift,
    required this.statusLabel,
    required this.statusColor,
  });

  final TimelineShift shift;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        shift.beneficiaryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppFontSizes.s14,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _ScheduleStatusChip(
                      label: statusLabel,
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.micro),
                Text(
                  shift.serviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppFontSizes.s11,
                    height: 1.25,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.micro),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: BeneficiaryAvatar(
              name: shift.beneficiaryName,
              age: shift.beneficiaryAge,
              gender: shift.beneficiaryGender,
              avatarUrl: shift.beneficiaryAvatarUrl,
              radius: 19,
            ),
          ),
        ],
      );
}

class _ScheduleStatusChip extends StatelessWidget {
  const _ScheduleStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.tiny,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppFontSizes.s10,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
}
