import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'nutrition_expansion_card.dart';
import 'nutrition_preference_tag_field.dart';
import 'nutrition_status_field.dart';

class NutritionPreferencesPanel extends StatelessWidget {
  const NutritionPreferencesPanel({
    super.key,
    required this.enabled,
    required this.dietaryPattern,
    required this.nutritionGoal,
    required this.mealFormatPreference,
    required this.preferredFoods,
    required this.dislikedFoods,
    required this.onDietaryPatternChanged,
    required this.onNutritionGoalChanged,
    required this.onMealFormatPreferenceChanged,
    required this.onPreferredFoodsChanged,
    required this.onDislikedFoodsChanged,
  });

  final bool enabled;
  final String dietaryPattern;
  final String nutritionGoal;
  final String mealFormatPreference;
  final String preferredFoods;
  final String dislikedFoods;
  final ValueChanged<String> onDietaryPatternChanged;
  final ValueChanged<String> onNutritionGoalChanged;
  final ValueChanged<String> onMealFormatPreferenceChanged;
  final ValueChanged<String> onPreferredFoodsChanged;
  final ValueChanged<String> onDislikedFoodsChanged;

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
            mealFormatPreference: mealFormatPreference,
            preferredFoods: preferredFoods,
            dislikedFoods: dislikedFoods,
            onDietaryPatternChanged: onDietaryPatternChanged,
            onNutritionGoalChanged: onNutritionGoalChanged,
            onMealFormatPreferenceChanged: onMealFormatPreferenceChanged,
            onPreferredFoodsChanged: onPreferredFoodsChanged,
            onDislikedFoodsChanged: onDislikedFoodsChanged,
          ),
        ],
      );
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({
    required this.enabled,
    required this.dietaryPattern,
    required this.nutritionGoal,
    required this.mealFormatPreference,
    required this.preferredFoods,
    required this.dislikedFoods,
    required this.onDietaryPatternChanged,
    required this.onNutritionGoalChanged,
    required this.onMealFormatPreferenceChanged,
    required this.onPreferredFoodsChanged,
    required this.onDislikedFoodsChanged,
  });

  final bool enabled;
  final String dietaryPattern;
  final String nutritionGoal;
  final String mealFormatPreference;
  final String preferredFoods;
  final String dislikedFoods;
  final ValueChanged<String> onDietaryPatternChanged;
  final ValueChanged<String> onNutritionGoalChanged;
  final ValueChanged<String> onMealFormatPreferenceChanged;
  final ValueChanged<String> onPreferredFoodsChanged;
  final ValueChanged<String> onDislikedFoodsChanged;

  @override
  Widget build(BuildContext context) => NutritionExpansionCard(
        key: const ValueKey('nutrition-preferences'),
        title: 'Kiểu ăn, mục tiêu và sở thích',
        subtitle: 'Lọc món bắt buộc và ưu tiên món hợp thói quen.',
        children: [
          _PreferenceFields(
            enabled: enabled,
            dietaryPattern: dietaryPattern,
            nutritionGoal: nutritionGoal,
            mealFormatPreference: mealFormatPreference,
            preferredFoods: preferredFoods,
            dislikedFoods: dislikedFoods,
            onDietaryPatternChanged: onDietaryPatternChanged,
            onNutritionGoalChanged: onNutritionGoalChanged,
            onMealFormatPreferenceChanged: onMealFormatPreferenceChanged,
            onPreferredFoodsChanged: onPreferredFoodsChanged,
            onDislikedFoodsChanged: onDislikedFoodsChanged,
          ),
        ],
      );
}

class _PreferenceFields extends StatelessWidget {
  const _PreferenceFields({
    required this.enabled,
    required this.dietaryPattern,
    required this.nutritionGoal,
    required this.mealFormatPreference,
    required this.preferredFoods,
    required this.dislikedFoods,
    required this.onDietaryPatternChanged,
    required this.onNutritionGoalChanged,
    required this.onMealFormatPreferenceChanged,
    required this.onPreferredFoodsChanged,
    required this.onDislikedFoodsChanged,
  });

  final bool enabled;
  final String dietaryPattern;
  final String nutritionGoal;
  final String mealFormatPreference;
  final String preferredFoods;
  final String dislikedFoods;
  final ValueChanged<String> onDietaryPatternChanged;
  final ValueChanged<String> onNutritionGoalChanged;
  final ValueChanged<String> onMealFormatPreferenceChanged;
  final ValueChanged<String> onPreferredFoodsChanged;
  final ValueChanged<String> onDislikedFoodsChanged;

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
          NutritionStatusField(
            key: const ValueKey('nutrition-mealFormatPreference'),
            label: 'Dạng món muốn ưu tiên',
            value: mealFormatPreference,
            enabled: enabled,
            options: const {
              'no_preference': 'Không ưu tiên',
              'prefer_dry': 'Ưu tiên món khô',
              'prefer_soup': 'Ưu tiên món nước',
            },
            onChanged: onMealFormatPreferenceChanged,
          ),
          const SizedBox(height: AppSpacing.compact),
          NutritionPreferenceTagField(
            fieldKey: const ValueKey('nutrition-preferredFoods'),
            label: 'Món hoặc nguyên liệu thường thích',
            helperText:
                'Ví dụ: cá hấp, bí đỏ. CareSitter dùng để ưu tiên khi có lựa chọn phù hợp.',
            value: preferredFoods,
            enabled: enabled,
            onChanged: onPreferredFoodsChanged,
          ),
          const SizedBox(height: AppSpacing.compact),
          NutritionPreferenceTagField(
            fieldKey: const ValueKey('nutrition-dislikedFoods'),
            label: 'Món hoặc nguyên liệu không thích',
            helperText:
                'Đây là sở thích mềm, không thay thế khai báo dị ứng ở phần bắt buộc.',
            value: dislikedFoods,
            enabled: enabled,
            onChanged: onDislikedFoodsChanged,
          ),
          const SizedBox(height: AppSpacing.compact),
          Text(
            'Sở thích được dùng để xếp hạng món; các ràng buộc sức khỏe và dị ứng luôn được kiểm tra trước.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
}
