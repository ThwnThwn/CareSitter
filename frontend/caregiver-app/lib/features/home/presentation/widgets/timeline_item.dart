import 'package:caregiver_app/features/home/presentation/widgets/timeline_directions_action.dart';
import 'package:caregiver_app/features/home/presentation/widgets/timeline_shift_status.dart';
import 'package:caregiver_app/features/home/presentation/widgets/timeline_connector.dart';
import 'package:caregiver_app/features/home/presentation/widgets/timeline_address.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:caregiver_app/core/theme/app_theme.dart';

/// Timeline item for today's shifts
class TimelineItem extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final bool isActive;
  final String time;
  final String title;
  final String address;
  final String statusLabel;
  final Color statusColor;
  final Color statusBg;
  final VoidCallback? onTap;

  const TimelineItem({
    super.key,
    required this.isFirst,
    required this.isLast,
    required this.isActive,
    required this.time,
    required this.title,
    required this.address,
    required this.statusLabel,
    required this.statusColor,
    required this.statusBg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline line + node
            TimelineConnector(
                isFirst: isFirst, isActive: isActive, isLast: isLast),
            const SizedBox(width: AppSpacing.compact),
            // Card content
            Expanded(
              child: Container(
                margin: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.compact),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primaryContainer.withValues(alpha: 0.3)
                      : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isActive
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.border.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TimelineShiftStatus(
                        isActive: isActive,
                        time: time,
                        statusBg: statusBg,
                        statusLabel: statusLabel,
                        statusColor: statusColor),
                    const SizedBox(height: AppSpacing.tight),
                    Text(
                      title,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: AppFontSizes.s15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TimelineAddress(address: address),
                    if (isActive) ...[
                      const SizedBox(height: AppSpacing.control),
                      const Divider(color: AppColors.border, height: 1),
                      const SizedBox(height: AppSpacing.sm),
                      const TimelineDirectionsAction(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
