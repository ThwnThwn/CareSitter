import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';

class ShiftDetailEarningsCard extends StatelessWidget {
  const ShiftDetailEarningsCard({super.key, required this.booking});
  final ShiftModel booking;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatVnd(booking.caregiverEarning, separator: ',', suffix: '', round: true)}đ',
                  style: const TextStyle(
                      fontSize: AppFontSizes.s26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.micro),
                const Text('Thu nhập dự kiến',
                    style: TextStyle(
                        fontSize: AppFontSizes.s12,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
              width: 1,
              height: 40,
              color: AppColors.border,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.duration,
                  style: const TextStyle(
                      fontSize: AppFontSizes.s26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.micro),
                const Text('Thời lượng',
                    style: TextStyle(
                        fontSize: AppFontSizes.s12,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
