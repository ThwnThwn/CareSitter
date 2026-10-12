import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

/// Card tóm tắt đánh giá: điểm trung bình + thanh phân bổ sao.
class ReviewRatingSummaryCard extends StatelessWidget {
  final double avgRating;
  final int totalReviews;
  final List<int> ratingCounts;

  const ReviewRatingSummaryCard({
    super.key,
    required this.avgRating,
    required this.totalReviews,
    required this.ratingCounts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          // Left: Big number
          Expanded(
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
          ),
          // Middle divider
          Container(
            height: 80,
            width: 1,
            color: AppColors.border,
          ),
          // Right: Star Breakout
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.section),
              child: Column(
                children: [
                  _RatingBar(
                    stars: 5,
                    count: ratingCounts.length > 4 ? ratingCounts[4] : 0,
                    total: totalReviews,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _RatingBar(
                    stars: 4,
                    count: ratingCounts.length > 3 ? ratingCounts[3] : 0,
                    total: totalReviews,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _RatingBar(
                    stars: 3,
                    count: ratingCounts.length > 2 ? ratingCounts[2] : 0,
                    total: totalReviews,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _RatingBar(
                    stars: 2,
                    count: ratingCounts.length > 1 ? ratingCounts[1] : 0,
                    total: totalReviews,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _RatingBar(
                    stars: 1,
                    count: ratingCounts.isNotEmpty ? ratingCounts[0] : 0,
                    total: totalReviews,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget thanh tiến độ cho từng mức sao (private theo file).
class _RatingBar extends StatelessWidget {
  final int stars;
  final int count;
  final int total;

  const _RatingBar({
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
