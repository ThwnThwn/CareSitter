import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../data/models/nutrition_meal_model.dart';
import '../models/nutrition_meal_detail_format.dart';
import 'nutrition_meal_accordion.dart';
import 'nutrition_meal_ingredients.dart';
import 'nutrition_meal_nutrients.dart';
import 'nutrition_meal_preparation.dart';
import 'nutrition_meal_sources.dart';
export '../models/nutrition_meal_detail_format.dart';

class NutritionMealDetails extends StatelessWidget {
  const NutritionMealDetails({super.key, required this.meal});
  final NutritionMealModel meal;

  @override
  Widget build(BuildContext context) => NutritionMealAccordion(
        title: 'Xem chi tiết món ăn',
        icon: Icons.assignment_outlined,
        tinted: true,
        children: [_DetailsContent(meal: meal)],
      );
}

class _DetailsContent extends StatelessWidget {
  const _DetailsContent({required this.meal});
  final NutritionMealModel meal;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text(
              meal.servings == null
                  ? 'Khẩu phần công thức: chưa có dữ liệu'
                  : 'Khẩu phần công thức: ${nutritionDisplayNumber(meal.servings!)} phần',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.compact),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          NutritionMealIngredients(ingredients: meal.ingredients),
          const SizedBox(height: AppSpacing.md),
          NutritionMealPreparation(meal: meal),
          const SizedBox(height: AppSpacing.sm),
          NutritionMealNutrients(nutrients: meal.nutrients),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          NutritionMealSources(
              sourceIds: meal.sources, sources: meal.sourceDetails),
        ],
      );
}
