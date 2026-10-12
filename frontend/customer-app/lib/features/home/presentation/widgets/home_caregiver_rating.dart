import 'package:caresitter_customer/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class HomeCaregiverRating extends StatelessWidget {
  const HomeCaregiverRating({super.key, required this.c});
  final CaregiverModel c;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.star_rounded, color: AppColors.secondary, size: 13),
          const SizedBox(width: AppSpacing.micro),
          Text(
            c.ratingAvg.toStringAsFixed(1),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppFontSizes.s12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            ' (${c.ratingCount})',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: AppFontSizes.s11,
            ),
          ),
        ],
      );
}
