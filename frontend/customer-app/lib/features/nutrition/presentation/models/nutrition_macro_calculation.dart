import '../../data/models/nutrition_meal_model.dart';
import '../../domain/nutrition_nutrient_total.dart';

class NutritionMacroCalculation {
  const NutritionMacroCalculation(this.key, this.meals);
  final String key;
  final List<NutritionMealModel> meals;
  static const fields = {
    'protein_g': 'Chất đạm',
    'carbohydrate_g': 'Đường bột',
    'fat_g': 'Chất béo',
  };

  num? amount(NutritionMealModel meal) =>
      meal.nutrients?[key] is num ? meal.nutrients![key] as num : null;

  num? get total => NutritionNutrientTotal.sum(meals.map(amount));

  String amountLabel(NutritionMealModel meal) {
    final value = amount(meal);
    return value == null || !value.isFinite || value < 0
        ? 'Chưa có dữ liệu'
        : '${number(value)} g';
  }

  String get equation => total == null
      ? 'Chưa đủ dữ liệu để tính tổng'
      : '${meals.map((meal) => number(amount(meal)!)).join(' + ')} = ${number(total!)} g';

  static String number(num value) =>
      value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}
