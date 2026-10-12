import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverProfileHeaderCaregiverRow extends StatelessWidget {
  const CaregiverProfileHeaderCaregiverRow(
      {super.key, required this.caregiver});
  final CaregiverModel caregiver;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star, size: 14, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              '${caregiver.ratingAvg.toStringAsFixed(1)} (${caregiver.ratingCount} đánh giá)',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppFontSizes.s13,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
}
