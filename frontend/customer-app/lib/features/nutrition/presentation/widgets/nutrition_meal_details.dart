import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_meal_model.dart';
import 'package:flutter/material.dart';

import 'nutrition_meal_sources.dart';

class NutritionMealDetails extends StatelessWidget {
  const NutritionMealDetails({super.key, required this.meal});

  final NutritionMealModel meal;

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
          title: Text(
            'Xem chi tiết món ăn',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                ),
          ),
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.primary,
          children: [_DetailsContent(meal: meal)],
        ),
      );
}

class _DetailsContent extends StatelessWidget {
  const _DetailsContent({required this.meal});

  final NutritionMealModel meal;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Thành phần'),
          const SizedBox(height: AppSpacing.xs),
          for (final ingredient in meal.ingredients)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                '${ingredient.name}: ${ingredient.amount} ${ingredient.unit} '
                '(${ingredient.basis == 'cooked' ? 'đã chế biến' : 'trước chế biến'})',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (meal.preparationSteps.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text('Cách chế biến'),
            const SizedBox(height: AppSpacing.xs),
            if (meal.sourceRecipeNote != null) ...[
              _SourceRecipeNote(note: meal.sourceRecipeNote!),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(
              meal.preparationSteps.join('; '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          _DetailedNutrients(nutrients: meal.nutrients),
          NutritionMealSources(
            sourceIds: meal.sources,
            sources: meal.sourceDetails,
          ),
        ],
      );
}

class _SourceRecipeNote extends StatelessWidget {
  const _SourceRecipeNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.compact),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                note,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
            ),
          ],
        ),
      );
}

class _DetailedNutrients extends StatelessWidget {
  const _DetailedNutrients({required this.nutrients});

  final Map<String, dynamic>? nutrients;

  @override
  Widget build(BuildContext context) {
    if (nutrients == null) return const SizedBox.shrink();
    const labels = {
      'energy_kcal': 'Năng lượng',
      'protein_g': 'Đạm',
      'carbohydrate_g': 'Carbohydrate',
      'fat_g': 'Chất béo',
      'fiber_g': 'Chất xơ',
      'sodium_mg': 'Natri',
      'potassium_mg': 'Kali',
      'phosphorus_mg': 'Phospho',
      'fluid_ml': 'Dịch',
    };
    const units = {
      'energy_kcal': 'kcal',
      'protein_g': 'g',
      'carbohydrate_g': 'g',
      'fat_g': 'g',
      'fiber_g': 'g',
      'sodium_mg': 'mg',
      'potassium_mg': 'mg',
      'phosphorus_mg': 'mg',
      'fluid_ml': 'ml',
    };
    final known =
        nutrients!.entries.where((entry) => labels.containsKey(entry.key));
    if (known.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dinh dưỡng mỗi phần'),
          const SizedBox(height: AppSpacing.xs),
          for (final entry in known)
            Text(
              '${labels[entry.key]}: ${nutritionDisplayValue(entry.value)} '
              '${units[entry.key]}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

String nutritionDisplayValue(Object? value) {
  if (value is num) return nutritionDisplayNumber(value);
  return value?.toString() ?? '—';
}

String nutritionDisplayNumber(num value) =>
    value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
