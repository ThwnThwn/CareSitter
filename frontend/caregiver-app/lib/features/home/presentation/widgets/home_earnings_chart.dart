import 'package:caregiver_app/features/home/presentation/widgets/home_earnings_bars.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_earnings_heading.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_earnings_summary.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeEarningsChart extends StatelessWidget {
  const HomeEarningsChart(
      {super.key,
      required this.last7Days,
      required this.completedShifts,
      required this.monthTotal});
  final List<double> last7Days;
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
              total: total, onOpenDetails: () => context.push('/earnings')),
          const SizedBox(height: AppSpacing.section),

          // Bar chart
          HomeEarningsBars(earningsData: earningsData, labels: labels),
          const SizedBox(height: AppSpacing.compact),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.sm),
          HomeEarningsSummary(
              completedShifts: completedShifts, monthTotal: monthTotal),
        ],
      ),
    );
  }
}
