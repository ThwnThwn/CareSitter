import 'package:caregiver_app/features/settings/presentation/widgets/review_rating_bar.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class ReviewRatingDistribution extends StatelessWidget {
  const ReviewRatingDistribution(
      {super.key, required this.ratingCounts, required this.totalReviews});
  final List<int> ratingCounts;
  final int totalReviews;

  @override
  Widget build(BuildContext context) => Expanded(
        flex: 6,
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.section),
          child: Column(
            children: [
              ReviewRatingBar(
                stars: 5,
                count: ratingCounts.length > 4 ? ratingCounts[4] : 0,
                total: totalReviews,
              ),
              const SizedBox(height: AppSpacing.xs),
              ReviewRatingBar(
                stars: 4,
                count: ratingCounts.length > 3 ? ratingCounts[3] : 0,
                total: totalReviews,
              ),
              const SizedBox(height: AppSpacing.xs),
              ReviewRatingBar(
                stars: 3,
                count: ratingCounts.length > 2 ? ratingCounts[2] : 0,
                total: totalReviews,
              ),
              const SizedBox(height: AppSpacing.xs),
              ReviewRatingBar(
                stars: 2,
                count: ratingCounts.length > 1 ? ratingCounts[1] : 0,
                total: totalReviews,
              ),
              const SizedBox(height: AppSpacing.xs),
              ReviewRatingBar(
                stars: 1,
                count: ratingCounts.isNotEmpty ? ratingCounts[0] : 0,
                total: totalReviews,
              ),
            ],
          ),
        ),
      );
}
