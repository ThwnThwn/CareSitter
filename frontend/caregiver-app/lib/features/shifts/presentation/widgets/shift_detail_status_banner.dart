import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class ShiftDetailStatusBanner extends StatelessWidget {
  const ShiftDetailStatusBanner(
      {super.key, required this.getStatusInfo, required this.booking});
  final ({
    Color bgColor,
    Color color,
    IconData icon,
    String label,
    String subtitle
  })
      Function(String) getStatusInfo;
  final ShiftModel booking;
  @override
  Widget build(BuildContext context) {
    final info = getStatusInfo(booking.status);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.compact, vertical: AppSpacing.control),
      decoration: BoxDecoration(
        color: info.bgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: info.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(info.icon, color: info.color, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.control, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: info.color,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Text(
              info.label,
              style: const TextStyle(
                  fontSize: AppFontSizes.s12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              info.subtitle,
              style: const TextStyle(
                  fontSize: AppFontSizes.s12, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
