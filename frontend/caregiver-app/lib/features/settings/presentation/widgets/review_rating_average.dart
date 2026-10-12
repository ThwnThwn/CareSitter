import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ReviewRatingAverage extends StatelessWidget {
  const ReviewRatingAverage(
      {super.key, required this.avgRating, required this.totalReviews});
  final double avgRating;
  final int totalReviews;

  @override
  Widget build(BuildContext context) => Expanded(
        flex: 4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              avgRating.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: AppFontSizes.s48,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1.1,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (idx) {
                return Icon(
                  idx < avgRating.floor()
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: AppColors.secondary,
                  size: 20,
                );
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$totalReviews lượt đánh giá',
              style: const TextStyle(
                fontSize: AppFontSizes.s12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}
