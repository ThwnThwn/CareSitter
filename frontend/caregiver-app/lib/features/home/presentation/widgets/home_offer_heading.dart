import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeOfferHeading extends StatelessWidget {
  const HomeOfferHeading(
      {super.key, required this.isExpired, required this.countdownLabel});
  final bool isExpired;
  final String? countdownLabel;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_active_rounded,
                color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Có lịch mới cần xác nhận!',
              style: GoogleFonts.beVietnamPro(
                fontSize: AppFontSizes.s13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_rounded,
                    color: AppColors.error, size: 14),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  isExpired ? 'Đang cập nhật' : countdownLabel ?? 'Đang chờ',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: AppFontSizes.s11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
