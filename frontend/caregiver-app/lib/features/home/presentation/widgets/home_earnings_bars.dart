import 'package:caregiver_app/features/home/presentation/widgets/home_earnings_day_label.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeEarningsBars extends StatelessWidget {
  const HomeEarningsBars(
      {super.key,
      required this.earningsData,
      required this.labels,
      required this.callbackAction2});
  final List<double> earningsData;
  final List<String> labels;
  final BarTooltipItem Function(BarChartGroupData, int, BarChartRodData, int)
      callbackAction2;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 120,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: earningsData.isEmpty || earningsData.every((v) => v == 0)
                ? 100 // placeholder khi chưa có data
                : (earningsData.reduce((a, b) => a > b ? a : b) * 1.25)
                    .ceilToDouble(),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: callbackAction2,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    final isToday = idx == labels.length - 1;
                    return Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.tight),
                      child: HomeEarningsDayLabel(
                          labels: labels, idx: idx, isToday: isToday),
                    );
                  },
                ),
              ),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(earningsData.length, (i) {
              final isToday = i == earningsData.length - 1;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: earningsData[i],
                    color: isToday
                        ? AppColors.primary
                        : AppColors.surfaceContainerHigh,
                    width: 24,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.tight)),
                  ),
                ],
              );
            }),
          ),
        ),
      );
}
