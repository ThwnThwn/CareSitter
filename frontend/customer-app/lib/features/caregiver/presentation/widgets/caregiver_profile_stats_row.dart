import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/caregiver/data/models/caregiver_model.dart';

class CaregiverProfileStatsRow extends StatelessWidget {
  const CaregiverProfileStatsRow(
      {super.key,
      required this.buildStatItem,
      required this.caregiver,
      required this.buildDivider});
  final Widget Function(String, String) buildStatItem;
  final CaregiverModel caregiver;
  final Widget Function() buildDivider;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: buildStatItem('⭐ ${caregiver.ratingAvg.toStringAsFixed(1)}',
                '${caregiver.ratingCount} đánh giá'),
          ),
          buildDivider(),
          Expanded(child: buildStatItem('🛡️ 100%', 'Xác minh KYC')),
          buildDivider(),
          Expanded(
            child: buildStatItem(
                '📍 ${caregiver.location.isNotEmpty ? caregiver.location : 'TP.HCM'}',
                'Khu vực'),
          ),
        ],
      ),
    );
  }
}
