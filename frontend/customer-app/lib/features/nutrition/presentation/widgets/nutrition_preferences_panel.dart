import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'nutrition_expansion_card.dart';
import 'nutrition_status_field.dart';

class NutritionPreferencesPanel extends StatelessWidget {
  const NutritionPreferencesPanel({
    super.key,
    required this.enabled,
    required this.dietaryPattern,
    required this.nutritionGoal,
    required this.onDietaryPatternChanged,
    required this.onNutritionGoalChanged,
  });

  final bool enabled;
  final String dietaryPattern;
  final String nutritionGoal;
  final ValueChanged<String> onDietaryPatternChanged;
  final ValueChanged<String> onNutritionGoalChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.compact,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              'TÙY CHỌN BỔ SUNG',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
            ),
          ),
          _PreferencesCard(
            enabled: enabled,
            dietaryPattern: dietaryPattern,
            nutritionGoal: nutritionGoal,
            onDietaryPatternChanged: onDietaryPatternChanged,
            onNutritionGoalChanged: onNutritionGoalChanged,
          ),
        ],
      );
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({
    required this.enabled,
    required this.dietaryPattern,
    required this.nutritionGoal,
    required this.onDietaryPatternChanged,
    required this.onNutritionGoalChanged,
  });

  final bool enabled;
  final String dietaryPattern;
  final String nutritionGoal;
  final ValueChanged<String> onDietaryPatternChanged;
  final ValueChanged<String> onNutritionGoalChanged;

  @override
  Widget build(BuildContext context) => NutritionExpansionCard(
        key: const ValueKey('nutrition-preferences'),
        title: 'Kiểu ăn và mục tiêu',
        subtitle: 'Lọc món và ưu tiên mức năng lượng tương đối.',
        children: [
          _PreferenceFields(
            enabled: enabled,
            dietaryPattern: dietaryPattern,
            nutritionGoal: nutritionGoal,
            onDietaryPatternChanged: onDietaryPatternChanged,
            onNutritionGoalChanged: onNutritionGoalChanged,
          ),
        ],
      );
}

class _PreferenceFields extends StatelessWidget {
  const _PreferenceFields({
    required this.enabled,
    required this.dietaryPattern,
    required this.nutritionGoal,
    required this.onDietaryPatternChanged,
    required this.onNutritionGoalChanged,
  });

  final bool enabled;
  final String dietaryPattern;
  final String nutritionGoal;
  final ValueChanged<String> onDietaryPatternChanged;
  final ValueChanged<String> onNutritionGoalChanged;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          NutritionStatusField(
            key: const ValueKey('nutrition-dietaryPattern'),
            label: 'Chế độ ăn mong muốn',
            value: dietaryPattern,
            enabled: enabled,
            options: const {
              'regular': 'Ăn thông thường',
              'vegetarian': 'Ăn chay',
            },
            onChanged: onDietaryPatternChanged,
          ),
          const SizedBox(height: AppSpacing.compact),
          NutritionStatusField(
            key: const ValueKey('nutrition-nutritionGoal'),
            label: 'Mục tiêu dinh dưỡng',
            value: nutritionGoal,
            enabled: enabled,
            options: const {
              'maintain': 'Giữ cân',
              'gain': 'Tăng cân',
              'lose': 'Giảm cân',
            },
            onChanged: onNutritionGoalChanged,
          ),
          const SizedBox(height: AppSpacing.compact),
          Text(
            'Mục tiêu này không thay thế tư vấn dinh dưỡng chuyên môn.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
}
