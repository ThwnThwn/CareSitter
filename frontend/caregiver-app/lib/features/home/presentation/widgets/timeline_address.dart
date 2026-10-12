import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class TimelineAddress extends StatelessWidget {
  const TimelineAddress({super.key, required this.address});
  final String address;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.home_rounded, color: AppColors.textHint, size: 15),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              address,
              style: GoogleFonts.beVietnamPro(
                fontSize: AppFontSizes.s12,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}
