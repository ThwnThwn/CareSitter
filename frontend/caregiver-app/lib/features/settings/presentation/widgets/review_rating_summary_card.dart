import 'package:caregiver_app/features/settings/presentation/widgets/review_rating_distribution.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/review_rating_average.dart';
import 'package:flutter/material.dart';
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
          ReviewRatingAverage(avgRating: avgRating, totalReviews: totalReviews),
          // Middle divider
          Container(
            height: 80,
            width: 1,
            color: AppColors.border,
          ),
          // Right: Star Breakout
          ReviewRatingDistribution(
              ratingCounts: ratingCounts, totalReviews: totalReviews),
        ],
      ),
    );
  }
}
