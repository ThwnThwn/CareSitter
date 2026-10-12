import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeEarningsSummary extends StatelessWidget {
  const HomeEarningsSummary(
      {super.key,
      required this.completedShifts,
      required this.formatPrice,
      required this.monthTotal});
  final int completedShifts;
  final String Function(double) formatPrice;
  final double monthTotal;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Builder(builder: (context) {
              // Tính trung bình từ ca đã hoàn thành
              final avgLabel = completedShifts > 0
                  ? 'TB/ca: ${formatPrice(monthTotal / completedShifts)}đ'
                  : 'Chưa có ca hoàn thành';
              return Text(
                avgLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.beVietnamPro(
                  fontSize: AppFontSizes.s11,
                  color: AppColors.textSecondary,
                ),
              );
            }),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Đã trả vào Ví CareSitter',
            style: GoogleFonts.beVietnamPro(
              fontSize: AppFontSizes.s11,
              fontWeight: FontWeight.w500,
              color: AppColors.secondary,
            ),
          ),
        ],
      );
}
