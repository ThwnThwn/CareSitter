import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/settings/data/models/caregiver_review_model.dart';

class ReviewAuthorService extends StatelessWidget {
  const ReviewAuthorService({super.key, required this.review});
  final CaregiverReviewModel review;

  @override
  Widget build(BuildContext context) => Expanded(
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
      );
}
