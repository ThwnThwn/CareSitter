import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverListHasLocationAllCaregiversContent extends StatelessWidget {
  const CaregiverListHasLocationAllCaregiversContent(
      {super.key, required this.hasLocation, required this.allCaregivers});
  final bool hasLocation;
  final List<CaregiverModel> allCaregivers;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Đội ngũ Chăm sóc viên',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppFontSizes.s20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.tiny),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Text(
                    hasLocation
                        ? '${allCaregivers.length} trong khu vực'
                        : 'Chưa chọn địa chỉ',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: AppFontSizes.s11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      );
}
