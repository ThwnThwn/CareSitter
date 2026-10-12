import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class ShiftDetailCompletedCard extends StatelessWidget {
  const ShiftDetailCompletedCard({super.key, required this.booking});
  final ShiftModel booking;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.statusCompletedBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border:
            Border.all(color: AppColors.statusCompleted.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded,
                  color: AppColors.statusCompleted, size: 22),
              SizedBox(width: AppSpacing.sm),
              Text('Ca làm việc đã hoàn thành',
                  style: TextStyle(
                      fontSize: AppFontSizes.s15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.statusCompleted)),
            ],
          ),
          const SizedBox(height: AppSpacing.compact),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Thu nhập của bạn:',
                  style: TextStyle(
                      fontSize: AppFontSizes.s14,
                      color: AppColors.textPrimary)),
              Text(
                '+ ${formatVnd(booking.caregiverEarning, separator: ',', suffix: '', round: true)}đ',
                style: const TextStyle(
                    fontSize: AppFontSizes.s16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.statusCompleted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
