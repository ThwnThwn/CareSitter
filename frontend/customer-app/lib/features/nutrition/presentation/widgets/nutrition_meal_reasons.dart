import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../../data/models/nutrition_meal_model.dart';
import '../../data/models/nutrition_recommendation_trace_model.dart';
import '../models/nutrition_reason_copy.dart';
import 'nutrition_meal_ai_reason.dart';
import 'nutrition_meal_accordion.dart';

class NutritionMealReasons extends StatelessWidget {
  const NutritionMealReasons({super.key, required this.meal, this.trace});

  final NutritionMealModel meal;
  final NutritionRecommendationTraceModel? trace;

  @override
  Widget build(BuildContext context) {
    final reasons = NutritionReasonCopy.forMeal(trace, meal);
    final explanation = NutritionReasonCopy.aiForMeal(trace, meal);
    final sources = reasons.map((reason) => reason.source).toSet();
    return NutritionMealAccordion(
      key: ValueKey('meal-reasons:${meal.mealType}:${meal.recipeVersionId}'),
      title: 'Vì sao chọn món này?',
      icon: Icons.info_outline_rounded,
      children: [
        if (explanation != null)
          NutritionMealAiReason(explanation: explanation, trace: trace!),
        if (reasons.isEmpty && explanation == null)
          const Text('Chưa có lý do riêng đã xác minh cho món này.'),
        if (reasons.isNotEmpty && explanation != null)
          Text('Kiểm tra theo quy tắc',
              style: Theme.of(context).textTheme.labelMedium),
        for (final reason in reasons)
          Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text('• ${reason.detail}',
                  style: Theme.of(context).textTheme.bodySmall)),
        if (sources.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text('Đối chiếu hồ sơ: ${sources.join(', ')}.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Text(
              'Các kiểm tra này chưa chứng minh món ăn phù hợp để điều trị bệnh.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
        ],
      ],
    );
  }
}
