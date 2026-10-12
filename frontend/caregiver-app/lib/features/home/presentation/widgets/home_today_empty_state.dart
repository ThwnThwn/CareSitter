import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeTodayEmptyState extends StatelessWidget {
  const HomeTodayEmptyState({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            children: [
              const Icon(Icons.event_available_rounded,
                  color: AppColors.textHint, size: 40),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Hôm nay bạn rảnh!',
                style: GoogleFonts.beVietnamPro(
                  fontSize: AppFontSizes.s14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
}
