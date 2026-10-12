import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeAvatar extends StatelessWidget {
  const HomeAvatar({super.key, required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                initials,
                style: GoogleFonts.beVietnamPro(
                  fontSize: AppFontSizes.s14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cardBackground, width: 2),
              ),
            ),
          ),
        ],
      );
}
