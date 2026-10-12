import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeEarningsHeading extends StatelessWidget {
  const HomeEarningsHeading(
      {super.key,
      required this.formatPrice,
      required this.total,
      required this.callbackAction1});
  final String Function(double) formatPrice;
  final double total;
  final void Function() callbackAction1;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thu nhập 7 ngày qua',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: AppFontSizes.s18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.micro),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.beVietnamPro(
                      fontSize: AppFontSizes.s12,
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      const TextSpan(text: 'Tổng tích luỹ: '),
                      TextSpan(
                        text: '${formatPrice(total)}đ',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: AppFontSizes.s12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: callbackAction1,
            child: Row(
              children: [
                Text(
                  'Chi tiết',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: AppFontSizes.s11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.primary, size: 14),
              ],
            ),
          ),
        ],
      );
}
