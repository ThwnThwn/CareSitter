import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_meal_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/recipe_option_model.dart';
import 'package:flutter/material.dart';

import 'nutrition_meal_details.dart';

class NutritionReplacementSheet extends StatelessWidget {
  const NutritionReplacementSheet({super.key, required this.options});

  final List<RecipeOptionModel> options;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text('Chọn món thay thế',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              Expanded(
                child: options.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                              'Chưa có món thay thế đáp ứng các yêu cầu của thực đơn.'),
                        ),
                      )
                    : ListView.builder(
                        itemCount: options.length,
                        itemBuilder: (context, index) =>
                            _OptionTile(recipe: options[index]),
                      ),
              ),
            ],
          ),
        ),
      );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.recipe});
  final RecipeOptionModel recipe;

  @override
  Widget build(BuildContext context) {
    final servings = recipe.servings;
    final energy = recipe.energyKcal;
    return ExpansionTile(
      leading: const Icon(Icons.restaurant_outlined),
      title: Text(recipe.name),
      subtitle: Text(
        '${servings == null ? 'Khẩu phần: Chưa có dữ liệu' : '${nutritionDisplayNumber(servings)} phần'}\n'
        '${energy == null ? 'Năng lượng: Chưa có dữ liệu' : '${nutritionDisplayNumber(energy)} kcal'}',
      ),
      childrenPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: recipe.versionId.isEmpty
                ? null
                : () => Navigator.of(context).pop(recipe.versionId),
            child: const Text('Chọn món này'),
          ),
        ),
        NutritionMealDetails(
            meal: NutritionMealModel.fromJson(recipe.toJson())),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
