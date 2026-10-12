import 'package:caregiver_app/features/home/presentation/widgets/home_earnings_bars.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_earnings_heading.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_earnings_summary.dart';
import 'package:caregiver_app/core/theme/app_font_sizes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeEarningsChart extends StatelessWidget {
  const HomeEarningsChart(
      {super.key,
      required this.last7Days,
      required this.formatPrice,
      required this.completedShifts,
      required this.monthTotal});
  final List<double> last7Days;
  final String Function(double) formatPrice;
  final int completedShifts;
  final double monthTotal;
  @override
  Widget build(BuildContext context) {
    // last7Days từ earningsProvider — đơn vị: VND
    // Chuyển sang nghìn đồng cho chart label
    final earningsData = last7Days.map((v) => v / 1000).toList();
    final total = last7Days.fold(0.0, (a, b) => a + b);

    // Label: 7 ngày gần nhất, ngày cuối = hôm nay
    final now = DateTime.now();
    final labels = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      if (i == 6) return 'Nay';
      const short = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
      return short[d.weekday - 1];
    });

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeEarningsHeading(
              formatPrice: formatPrice,
              total: total,
              callbackAction1: () => context.push('/earnings')),
          const SizedBox(height: AppSpacing.section),

          // Bar chart
          HomeEarningsBars(
              earningsData: earningsData,
              labels: labels,
              callbackAction2: (group, gIdx, rod, rIdx) {
                return BarTooltipItem(
                  '${earningsData[group.x.toInt()].toInt()}k',
                  GoogleFonts.beVietnamPro(
                    fontSize: AppFontSizes.s11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                );
              }),
          const SizedBox(height: AppSpacing.compact),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.sm),
          HomeEarningsSummary(
              completedShifts: completedShifts,
              formatPrice: formatPrice,
              monthTotal: monthTotal),
        ],
      ),
    );
  }
}
