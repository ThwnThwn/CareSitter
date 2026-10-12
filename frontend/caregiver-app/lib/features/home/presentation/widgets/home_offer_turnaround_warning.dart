import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeOfferTurnaroundWarning extends StatelessWidget {
  const HomeOfferTurnaroundWarning(
      {super.key, required this.turnaroundWarning});
  final String turnaroundWarning;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.control),
          decoration: BoxDecoration(
            color: AppColors.warningLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  turnaroundWarning,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: AppFontSizes.s12,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
