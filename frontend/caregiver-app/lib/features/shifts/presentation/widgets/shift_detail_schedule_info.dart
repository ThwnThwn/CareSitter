import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class ShiftDetailScheduleInfo extends StatelessWidget {
  const ShiftDetailScheduleInfo({super.key, required this.booking});
  final ShiftModel booking;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.inset, vertical: AppSpacing.compact),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(booking.date,
                style: const TextStyle(
                    fontSize: AppFontSizes.s14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500)),
          ),
          Container(
              width: 1,
              height: 18,
              color: AppColors.border,
              margin:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.compact)),
          const Icon(Icons.access_time_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text(booking.time,
                  style: const TextStyle(
                      fontSize: AppFontSizes.s14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
