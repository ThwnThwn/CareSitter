import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';

/// Widget thanh tiến độ cho từng mức sao (private theo file).
class ReviewRatingBar extends StatelessWidget {
  final int stars;
  final int count;
  final int total;

  const ReviewRatingBar({
    super.key,
    required this.stars,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$stars',
          style: const TextStyle(
            fontSize: AppFontSizes.s12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        const Icon(Icons.star_rounded, color: AppColors.secondary, size: 13),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : count / total,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}
