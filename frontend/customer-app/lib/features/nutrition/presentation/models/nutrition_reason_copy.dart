import '../../data/models/nutrition_meal_model.dart';
import '../../data/models/nutrition_recommendation_trace_model.dart';
import '../../data/models/nutrition_recommendation_explanation_model.dart';

class NutritionReasonCopy {
  static const menuId = '00000000-0000-0000-0000-000000000000';

  static NutritionRecommendationExplanationModel? aiForMeal(
      NutritionRecommendationTraceModel? trace, NutritionMealModel meal) {
    if (trace == null ||
        !trace.usedAi ||
        meal.recipeVersionId.isEmpty ||
        meal.recipeVersionId == menuId) {
      return null;
    }
    final matches = trace.explanations
        .where((item) => item.recipeVersionId == meal.recipeVersionId)
        .toList();
    if (matches.length != 1) return null;
    final explanation = matches.single;
    final sources = trace.evidence.map((item) => item.id).toSet();
    if (explanation.summary.trim().isEmpty ||
        explanation.summary.length > 300 ||
        explanation.evidenceIds.isEmpty ||
        explanation.evidenceIds
            .any((id) => id.isEmpty || !sources.contains(id))) {
      return null;
    }
    return explanation;
  }

  static List<({String detail, String source})> forMeal(
      NutritionRecommendationTraceModel? trace, NutritionMealModel meal) {
    if (meal.recipeVersionId.isEmpty || meal.recipeVersionId == menuId) {
      return const [];
    }
    final entries = <({String detail, String source})>[];
    for (final reason
        in trace?.verifiedReasons ?? const <Map<String, dynamic>>[]) {
      if (reason['recipeVersionId'] != meal.recipeVersionId) continue;
      var text = detail(reason, meal.name);
      if (text == null) continue;
      final prefix = '${meal.name}: ';
      if (text.startsWith(prefix)) text = text.substring(prefix.length);
      text = text[0].toUpperCase() + text.substring(1);
      entries.add((detail: text, source: source(reason['sourceField'])));
    }
    return entries.toSet().toList(growable: false);
  }

  static String? detail(Map<String, dynamic> reason, String? mealName) {
    final value = reason['detail']?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    final menu = reason['recipeVersionId'] == menuId;
    return switch (reason['code']) {
      'declared_allergy_filter' when mealName != null =>
        '$mealName: đã lọc dị ứng $value theo dữ liệu nguyên liệu và dị nguyên.',
      'dietary_pattern' when mealName != null && value == 'vegetarian' =>
        '$mealName: có nhãn ăn chay trong danh mục, theo kiểu ăn đã chọn.',
      'condition_rule' when menu => value,
      'goal_ranking_signal'
          when menu && const {'lose', 'gain', 'maintain'}.contains(value) =>
        'Mục tiêu ${const {
          'lose': 'giảm cân',
          'gain': 'tăng cân',
          'maintain': 'duy trì'
        }[value]} đã được dùng khi xếp hạng phương án. Chưa xác định nhu cầu năng lượng cá nhân.',
      'preferred_food_signal' when menu =>
        'Ưu tiên “$value” đã được dùng khi xếp hạng; không bảo đảm mọi bữa đều có thực phẩm này.',
      'disliked_food_signal' when menu =>
        'Không thích “$value” đã được dùng để giảm ưu tiên; đây không phải điều kiện loại trừ dị ứng.',
      _ => null,
    };
  }

  static String source(Object? raw) {
    final field = raw?.toString() ?? '';
    if (field.startsWith('allergies')) return 'Dị ứng thực phẩm';
    if (field.startsWith('chronicConditions')) return 'Bệnh lý hiện có';
    return const {
          'generalNote': 'Lưu ý sức khỏe',
          'careInstructions': 'Hướng dẫn chăm sóc',
          'healthHistory/nutrition/dietaryPattern': 'Kiểu ăn',
          'healthHistory/nutrition/nutritionGoal': 'Mục tiêu dinh dưỡng',
          'healthHistory/nutrition/preferredFoods': 'Thực phẩm yêu thích',
          'healthHistory/nutrition/dislikedFoods': 'Thực phẩm không thích',
        }[field] ??
        'Thông tin trong hồ sơ lúc tạo thực đơn';
  }
}
