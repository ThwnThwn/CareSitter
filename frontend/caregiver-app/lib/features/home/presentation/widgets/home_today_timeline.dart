import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_today_heading.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_today_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/theme/shift_status_style.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/home/presentation/widgets/timeline_item.dart';

class HomeTodayTimeline extends StatelessWidget {
  const HomeTodayTimeline(
      {super.key, required this.todayLabel, required this.shifts});
  final String Function() todayLabel;
  final List<ShiftModel> shifts;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — ngày được tính động
          HomeTodayHeading(todayLabel: todayLabel),
          const SizedBox(height: AppSpacing.md),

          if (shifts.isEmpty)
            const HomeTodayEmptyState()
          else
            ...List.generate(shifts.length, (i) {
              final shift = shifts[i];
              final isFirst = i == 0;
              final isLast = i == shifts.length - 1;
              final statusStyle = ShiftStatusStyle.of(shift.status);

              return TimelineItem(
                isFirst: isFirst,
                isLast: isLast,
                isActive: shift.status == 'in_progress' ||
                    shift.status == 'caregiver_en_route',
                time: shift.time,
                title: '${shift.serviceName} - ${shift.beneficiaryName}',
                address: shift.address,
                statusLabel: statusStyle.label,
                statusColor: statusStyle.color,
                statusBg: statusStyle.backgroundColor,
                onTap: () => context.push('/shifts/${shift.id}'),
              );
            }),
        ],
      ),
    );
  }
}
