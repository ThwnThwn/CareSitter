import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/settings/data/models/caregiver_review_model.dart';

class ReviewAuthorAvatar extends StatelessWidget {
  const ReviewAuthorAvatar({super.key, required this.review});
  final CaregiverReviewModel review;

  @override
  Widget build(BuildContext context) => CircleAvatar(
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
      );
}
