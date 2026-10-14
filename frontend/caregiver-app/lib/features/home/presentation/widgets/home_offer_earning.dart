import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/core/utils/currency_formatter.dart';

class HomeOfferEarning extends StatelessWidget {
  const HomeOfferEarning({super.key, required this.booking});
  final ShiftModel booking;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Thu nhập',
            style: GoogleFonts.beVietnamPro(
              fontSize: AppFontSizes.s11,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            formatVnd(
                booking.caregiverEarning > 0
                    ? booking.caregiverEarning
                    : booking.totalPrice,
                compact: true,
                round: true),
            style: GoogleFonts.beVietnamPro(
              fontSize: AppFontSizes.s18,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      );
}
