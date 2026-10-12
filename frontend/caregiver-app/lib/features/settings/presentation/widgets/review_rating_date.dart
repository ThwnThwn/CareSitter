import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/settings/data/models/caregiver_review_model.dart';

class ReviewRatingDate extends StatelessWidget {
  const ReviewRatingDate({super.key, required this.review});
  final CaregiverReviewModel review;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: List.generate(5, (idx) {
              return Icon(
                idx < review.rating
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: AppColors.secondary,
                size: 14,
              );
            }),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            review.date,
            style: const TextStyle(
              fontSize: AppFontSizes.s11,
              color: AppColors.textHint,
            ),
          ),
        ],
      );
}
