import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeTodayEmptyState extends StatelessWidget {
  const HomeTodayEmptyState({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            children: [
              Icon(Icons.event_available_rounded,
                  color: AppColors.textHint, size: 40),
              SizedBox(height: AppSpacing.sm),
              Text(
                'Hôm nay bạn rảnh!',
                style: TextStyle(fontFamily: 'Inter',
                  fontSize: AppFontSizes.s14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
}
