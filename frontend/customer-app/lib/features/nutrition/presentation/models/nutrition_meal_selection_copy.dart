import '../../data/models/nutrition_meal_model.dart';
import '../../data/models/nutrition_recommendation_trace_model.dart';
import 'nutrition_meal_detail_format.dart';
import 'nutrition_reason_copy.dart';

/// Explains stored selection metadata without inventing personal health claims.
class NutritionMealSelectionCopy {
  const NutritionMealSelectionCopy(this.selection, this.nutrition);

  final String selection;
  final String? nutrition;

  static NutritionMealSelectionCopy? forMeal(
      NutritionRecommendationTraceModel? trace, NutritionMealModel meal) {
    if (trace == null ||
        meal.recipeVersionId.isEmpty ||
        meal.recipeVersionId == NutritionReasonCopy.menuId ||
        meal.name.trim().isEmpty) {
      return null;
    }
    final slot = const {
      'breakfast': 'bữa sáng',
      'lunch': 'bữa trưa',
      'dinner': 'bữa tối',
    }[meal.mealType];
    if (slot == null) return null;
    final selection = switch (trace.strategy) {
      'rule_baseline' ||
      'graph_grounded_rule' ||
      'graph_grounded_ai_ranked' =>
        'Được gợi ý cho $slot từ danh mục, sau bước lọc yêu cầu ăn uống đã khai báo khi tạo thực đơn.',
      'rule_manual_replacement' =>
        'Gia đình đã đổi sang món này cho $slot. Dữ liệu bên dưới mô tả khẩu phần của món đã chọn.',
      _ => null,
    };
    if (selection == null) return null;
    final nutrients = <String>[];
    for (final entry in const [
      ('energy_kcal', 'kcal'),
      ('protein_g', 'g chất đạm'),
      ('carbohydrate_g', 'g chất bột đường'),
      ('fat_g', 'g chất béo'),
    ]) {
      final value = meal.nutrients?[entry.$1];
      if (value is num && value.isFinite && value >= 0) {
        nutrients.add('${nutritionDisplayNumber(value)} ${entry.$2}');
      }
    }
    return NutritionMealSelectionCopy(
        selection,
        nutrients.isEmpty
            ? null
            : 'Mỗi phần cung cấp ước tính ${nutrients.join(', ')}.');
  }
}
