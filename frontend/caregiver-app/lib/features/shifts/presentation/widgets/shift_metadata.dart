import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';

class ShiftMetadata extends StatelessWidget {
  final IconData icon;
  final String label;

  const ShiftMetadata({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.tight),
        Text(
          label,
          style: GoogleFonts.beVietnamPro(
            fontSize: AppFontSizes.s14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
