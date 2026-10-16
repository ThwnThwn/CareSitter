import '../../data/models/nutrition_meal_model.dart';
import 'package:flutter/material.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';

import 'nutrition_meal_sources.dart';

class NutritionMealCard extends StatelessWidget {
  const NutritionMealCard(
      {super.key,
      required this.meal,
      required this.loading,
      required this.canReplace,
      required this.onReplace});
  final NutritionMealModel meal;
  final bool loading, canReplace;
  final VoidCallback onReplace;
  @override
  Widget build(BuildContext context) {
    const labels = {
      'breakfast': 'Bữa sáng',
      'lunch': 'Bữa trưa',
      'dinner': 'Bữa tối'
    };
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(labels[meal.mealType] ?? 'Bữa ăn',
              style: Theme.of(context).textTheme.titleMedium),
          Text(meal.name),
          Text('Khẩu phần: ${meal.servings} phần'),
          for (final ingredient in meal.ingredients)
            Text(
                '${ingredient.name}: ${ingredient.amount} ${ingredient.unit} (${ingredient.basis == 'cooked' ? 'đã chế biến' : 'trước chế biến'})'),
          const Text(
              'Được gợi ý vì đáp ứng các ràng buộc đã kiểm tra của hồ sơ này.'),
          const Text(
              'Điều cần lưu ý: dùng đúng công thức và khẩu phần đã kiểm tra.'),
          Text('Cách chế biến: ${meal.preparationSteps.join('; ')}'),
          ..._nutrients(meal.nutrients),
          NutritionMealSources(
              sourceIds: meal.sources, sources: meal.sourceDetails),
          if (canReplace)
            OutlinedButton(
                onPressed: loading ? null : onReplace,
                child: const Text('Chọn món thay thế')),
        ]));
  }

  List<Widget> _nutrients(Map<String, dynamic>? raw) {
    const labels = {
      'energy_kcal': 'Năng lượng (kcal)',
      'protein_g': 'Đạm (g)',
      'carbohydrate_g': 'Carbohydrate (g)',
      'fat_g': 'Chất béo (g)',
      'fiber_g': 'Chất xơ (g)',
      'sodium_mg': 'Natri (mg)',
      'potassium_mg': 'Kali (mg)',
      'phosphorus_mg': 'Phospho (mg)',
      'fluid_ml': 'Dịch (ml)'
    };
    if (raw == null) {
      return [const Text('Chưa có thông tin dinh dưỡng mỗi phần.')];
    }
    final known = raw.entries.where((e) => labels.containsKey(e.key)).toList();
    return [
      const Text('Dinh dưỡng mỗi phần:'),
      for (final e in known)
        Text('${labels[e.key]}: ${e.value ?? 'Chưa có dữ liệu'}')
    ];
  }
}
