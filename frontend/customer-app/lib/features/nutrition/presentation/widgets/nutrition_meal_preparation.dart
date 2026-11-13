import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../../data/models/nutrition_meal_model.dart';

class NutritionMealPreparation extends StatelessWidget {
  const NutritionMealPreparation({super.key, required this.meal});
  final NutritionMealModel meal;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cách chế biến', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          if (meal.sourceRecipeNote case final note?)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.compact),
              padding: const EdgeInsets.all(AppSpacing.compact),
              decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.compact)),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.menu_book_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: Text(note,
                        style: Theme.of(context).textTheme.bodySmall)),
              ]),
            ),
          if (meal.preparationSteps.isEmpty) const Text('Chưa có dữ liệu'),
          for (final step in meal.preparationSteps.asMap().entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.compact),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primaryContainer,
                    child: Text('${step.key + 1}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Bước ${step.key + 1}',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Text(step.value,
                          style: Theme.of(context).textTheme.bodySmall),
                    ])),
              ]),
            ),
        ],
      );
}
