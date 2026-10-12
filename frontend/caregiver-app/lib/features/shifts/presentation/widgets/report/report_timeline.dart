import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/report/report_section_card.dart';

/// Section hiển thị timeline check-in / check-out của ca làm việc.
class ReportTimeline extends StatelessWidget {
  final String checkInTime;
  final String checkOutTime;
  final String duration;

  const ReportTimeline({
    super.key,
    required this.checkInTime,
    required this.checkOutTime,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return ReportSectionCard(
      title: '⏱ Thời gian ca làm việc',
      child: Row(
        children: [
          _TimePoint(
            label: 'Check-in',
            time: checkInTime,
            icon: Icons.login_rounded,
            color: AppColors.primary,
          ),
          Expanded(
            child: Column(
              children: [
                Container(height: 2, color: AppColors.border),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  duration,
                  style: const TextStyle(
                      fontSize: AppFontSizes.s12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          _TimePoint(
            label: 'Check-out',
            time: checkOutTime,
            icon: Icons.logout_rounded,
            color: AppColors.success,
          ),
        ],
      ),
    );
  }
}

/// Điểm thời gian trong timeline (private, chỉ dùng trong file này).
class _TimePoint extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;
  final Color color;

  const _TimePoint({
    required this.label,
    required this.time,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.control),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: AppSpacing.tight),
        Text(
          time,
          style: TextStyle(
              fontSize: AppFontSizes.s16,
              fontWeight: FontWeight.w800,
              color: color),
        ),
        Text(label,
            style: const TextStyle(
                fontSize: AppFontSizes.s11, color: AppColors.textSecondary)),
      ],
    );
  }
}
