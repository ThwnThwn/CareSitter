import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_status_badge.dart';

class ShiftCardRecipientService extends StatelessWidget {
  const ShiftCardRecipientService({super.key, required this.shift});
  final ShiftModel shift;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              shift.beneficiaryName.trim().isEmpty
                  ? '?'
                  : shift.beneficiaryName.trim()[0],
              style: GoogleFonts.beVietnamPro(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: AppFontSizes.s18,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.compact),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shift.beneficiaryName,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: AppFontSizes.s16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  shift.serviceName,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: AppFontSizes.s14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ShiftStatusBadge(status: shift.status),
        ],
      );
}
