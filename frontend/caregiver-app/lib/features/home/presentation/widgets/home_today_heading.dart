import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeTodayHeading extends StatelessWidget {
  const HomeTodayHeading({super.key, required this.todayLabel});
  final String Function() todayLabel;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.calendar_today_rounded,
              color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Lịch ca hôm nay',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.beVietnamPro(
                fontSize: AppFontSizes.s18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            todayLabel(),
            style: GoogleFonts.beVietnamPro(
              fontSize: AppFontSizes.s11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      );
}
