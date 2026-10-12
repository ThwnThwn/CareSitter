import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeOfferQueueLink extends StatelessWidget {
  const HomeOfferQueueLink(
      {super.key, required this.pendingCount, required this.callbackAction1});
  final int pendingCount;
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: callbackAction1,
          icon: const Icon(Icons.format_list_bulleted_rounded, size: 16),
          label: Text('+${pendingCount - 1} lịch khác'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(44, 40),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            textStyle: GoogleFonts.beVietnamPro(
              fontSize: AppFontSizes.s12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
}
