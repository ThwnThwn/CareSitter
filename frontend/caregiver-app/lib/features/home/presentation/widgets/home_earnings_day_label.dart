import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeEarningsDayLabel extends StatelessWidget {
  const HomeEarningsDayLabel(
      {super.key,
      required this.labels,
      required this.idx,
      required this.isToday});
  final List<String> labels;
  final int idx;
  final bool isToday;

  @override
  Widget build(BuildContext context) => Text(
        labels[idx],
        style: GoogleFonts.beVietnamPro(
          fontSize: AppFontSizes.s11,
          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
          color: isToday ? AppColors.primary : AppColors.textSecondary,
        ),
      );
}
