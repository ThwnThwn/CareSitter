import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/settings/data/models/caregiver_review_model.dart';

/// Card hiển thị chi tiết một nhận xét từ khách hàng.
class ReviewItemCard extends StatelessWidget {
  final CaregiverReviewModel review;

  const ReviewItemCard({
    super.key,
    required this.review,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  review.reviewerInitial,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: AppFontSizes.s13,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.compact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.reviewerName,
                      style: const TextStyle(
                        fontSize: AppFontSizes.s14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.micro),
                    Text(
                      review.shiftService,
                      style: const TextStyle(
                        fontSize: AppFontSizes.s11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
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
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.compact),
          Text(
            review.comment,
            style: const TextStyle(
              fontSize: AppFontSizes.s13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
