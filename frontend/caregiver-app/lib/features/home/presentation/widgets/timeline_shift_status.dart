import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class TimelineShiftStatus extends StatelessWidget {
  const TimelineShiftStatus(
      {super.key,
      required this.isActive,
      required this.time,
      required this.statusBg,
      required this.statusLabel,
      required this.statusColor});
  final bool isActive;
  final String time;
  final Color statusBg;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                  size: 15),
              const SizedBox(width: AppSpacing.xs),
              Text(
                time,
                style: GoogleFonts.beVietnamPro(
                  fontSize: AppFontSizes.s11,
                  fontWeight: FontWeight.w700,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.micro),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              statusLabel,
              style: GoogleFonts.beVietnamPro(
                fontSize: AppFontSizes.s11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      );
}
