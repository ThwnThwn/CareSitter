import 'package:caregiver_app/features/home/presentation/widgets/home_kpi_content.dart';
import 'package:flutter/material.dart';
import 'package:caregiver_app/core/theme/app_theme.dart';

class HomeKpiCards extends StatelessWidget {
  const HomeKpiCards(
      {super.key,
      required this.monthTotal,
      required this.rating,
      required this.totalReviews,
      required this.todayCount});
  final double monthTotal;
  final double rating;
  final int totalReviews;
  final int todayCount;
  @override
  Widget build(BuildContext context) {
    // Format thu nhập tháng: 4.800.000 → "4.800k"
    final monthTotalK = monthTotal / 1000;
    final monthLabel = monthTotal <= 0
        ? '-'
        : monthTotalK >= 1000
            ? '${(monthTotalK / 1000).toStringAsFixed(1)}M'
            : '${monthTotalK.round()}k';
    final ratingLabel = rating <= 0 ? '-' : rating.toStringAsFixed(1);
    final reviewLabel = totalReviews == 0 ? 'Chưa có' : '($totalReviews ca)';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: HomeKpiContent(
          todayCount: todayCount,
          monthLabel: monthLabel,
          rating: rating,
          ratingLabel: ratingLabel,
          reviewLabel: reviewLabel),
    );
  }
}
