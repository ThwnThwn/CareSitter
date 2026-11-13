import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import '../../data/models/meal_ingredient_model.dart';
import '../models/nutrition_meal_detail_format.dart';

class NutritionMealIngredients extends StatelessWidget {
  const NutritionMealIngredients({super.key, required this.ingredients});
  final List<MealIngredientModel> ingredients;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thành phần', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          if (ingredients.isEmpty) const Text('Chưa có dữ liệu'),
          for (final ingredient in ingredients)
            _IngredientRow(ingredient: ingredient),
        ],
      );
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.ingredient});
  final MealIngredientModel ingredient;

  @override
  Widget build(BuildContext context) {
    final amount = ingredient.amount;
    final quantity = amount == null
        ? 'Chưa có dữ liệu'
        : '${nutritionDisplayNumber(amount)} ${ingredient.unit}'.trim();
    final basis = switch (ingredient.basis) {
      'raw' => 'trước chế biến',
      'cooked' => 'đã chế biến',
      _ => '',
    };
    final name =
        Text(ingredient.name, style: Theme.of(context).textTheme.bodySmall);
    final value = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(quantity, style: Theme.of(context).textTheme.labelLarge),
      if (basis.isNotEmpty)
        Text(basis, style: Theme.of(context).textTheme.labelSmall),
    ]);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.control),
      decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 250 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [name, const SizedBox(height: AppSpacing.xs), value]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: name),
          const SizedBox(width: AppSpacing.sm),
          Expanded(flex: 2, child: value),
        ]);
      }),
    );
  }
}
