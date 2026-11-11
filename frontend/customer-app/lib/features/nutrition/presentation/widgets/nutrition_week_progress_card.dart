import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../../data/models/nutrition_decision_model.dart';
import '../../data/models/nutrition_result_model.dart';
import 'nutrition_facts.dart';

class NutritionWeekProgressCard extends StatelessWidget {
  const NutritionWeekProgressCard({
    super.key,
    required this.completedDays,
    required this.decision,
    required this.data,
    required this.health,
  });

  final int completedDays;
  final NutritionDecisionModel decision;
  final NutritionResultModel data;
  final Map<String, dynamic>? health;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('nutrition-week-progress'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Thông tin đã được xác nhận',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text('Đang tạo thực đơn cho 7 ngày từ hồ sơ đã lưu.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: completedDays / 7,
                minHeight: AppSpacing.tight,
                backgroundColor: AppColors.primaryContainer,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Đã lưu $completedDays/7 ngày',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ),
            if (data.facts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              NutritionFacts(
                decision: decision,
                data: data,
                state: 'eligible',
                health: health,
              ),
            ],
          ],
        ),
      );
}
