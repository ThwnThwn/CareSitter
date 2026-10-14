import 'package:caregiver_app/features/schedule/presentation/models/timeline_shift_model.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_shift_time_location.dart';
import 'package:caregiver_app/features/schedule/presentation/widgets/schedule_shift_recipient_status.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/theme/shift_status_style.dart';

class ScheduleShiftCard extends StatelessWidget {
  const ScheduleShiftCard({super.key, required this.shift});
  final TimelineShift shift;
  @override
  Widget build(BuildContext context) {
    final style = ShiftStatusStyle.of(shift.status);
    final statusColor = style.color;
    final statusLabel = style.label;
    final accentColor = style.color;

    return GestureDetector(
      onTap: () {
        if (shift.status == 'in_progress') {
          context.push('/shifts/${shift.id}/active');
        } else {
          context.push('/shifts/${shift.id}');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.compact),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Accent left bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
              const SizedBox(width: AppSpacing.compact),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScheduleShiftRecipientStatus(
                        shift: shift,
                        statusLabel: statusLabel,
                        statusColor: statusColor),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      shift.serviceName,
                      style: const TextStyle(
                        fontSize: AppFontSizes.s13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Meta-info row: allow wrapping on narrow screens
                    ScheduleShiftTimeLocation(shift: shift),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
