import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';
import 'package:caregiver_app/features/home/presentation/widgets/kpi_item.dart';

class HomeKpiContent extends StatelessWidget {
  const HomeKpiContent(
      {super.key,
      required this.todayCount,
      required this.monthLabel,
      required this.rating,
      required this.ratingLabel,
      required this.reviewLabel});
  final int todayCount;
  final String monthLabel;
  final double rating;
  final String ratingLabel;
  final String reviewLabel;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          children: [
            // Ca hôm nay
            Expanded(
              child: KpiItem(
                label: 'Ca hôm nay',
                value: '$todayCount',
                unit: 'ca',
                badge: todayCount > 0 ? 'Đúng tiến độ' : null,
              ),
            ),
            const VerticalDivider(
                color: AppColors.border, width: 1, thickness: 1),
            // Thu nhập tháng này
            Expanded(
              child: KpiItem(
                label: 'Thu nhập T${DateTime.now().month}',
                value: monthLabel,
              ),
            ),
            const VerticalDivider(
                color: AppColors.border, width: 1, thickness: 1),
            // Đánh giá từ profile DB
            Expanded(
              child: KpiItem(
                label: 'Đánh giá',
                valueWidget: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (rating > 0) ...[
                      const Icon(Icons.star_rounded,
                          color: AppColors.secondary, size: 18),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Text(
                      ratingLabel,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: AppFontSizes.s18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                trailing: Text(
                  reviewLabel,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: AppFontSizes.s11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
