import 'package:caregiver_app/features/settings/presentation/widgets/review_rating_date.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/review_author_service.dart';
import 'package:caregiver_app/features/settings/presentation/widgets/review_author_avatar.dart';
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
              ReviewAuthorAvatar(review: review),
              const SizedBox(width: AppSpacing.compact),
              ReviewAuthorService(review: review),
              ReviewRatingDate(review: review),
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
