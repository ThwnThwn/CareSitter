import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class TimelineDirectionsAction extends StatelessWidget {
  const TimelineDirectionsAction({super.key});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: const TextSpan(
                style: TextStyle(fontFamily: 'Inter',
                  fontSize: AppFontSizes.s12,
                  color: AppColors.textSecondary,
                ),
                children: [
                  TextSpan(text: 'Bắt đầu sau: '),
                  TextSpan(
                    text: '25 phút',
                    style: TextStyle(fontFamily: 'Inter',
                      fontSize: AppFontSizes.s12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.compact, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.navigation_rounded,
                    color: Colors.white, size: 14),
                SizedBox(width: AppSpacing.xs),
                Text(
                  'Chỉ đường',
                  style: TextStyle(fontFamily: 'Inter',
                    fontSize: AppFontSizes.s12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
