import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import '../models/home_offer_display_model.dart';

class HomeOfferRecipientLocation extends StatelessWidget {
  const HomeOfferRecipientLocation({super.key, required this.booking});
  final ShiftModel booking;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.elderly_rounded,
                color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: AppSpacing.control),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.beneficiaryName,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: AppFontSizes.s15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.micro),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: AppColors.primary, size: 14),
                    const SizedBox(width: AppSpacing.micro),
                    Expanded(
                      child: Text(
                        HomeOfferDisplayModel.locationLabel(booking),
                        style: GoogleFonts.beVietnamPro(
                          fontSize: AppFontSizes.s12,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
}
