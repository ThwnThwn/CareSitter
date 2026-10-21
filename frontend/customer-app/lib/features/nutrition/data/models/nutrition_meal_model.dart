import 'meal_ingredient_model.dart';
import 'nutrition_json.dart';
import 'nutrition_source_model.dart';

class NutritionMealModel {
  NutritionMealModel.fromJson(Map<String, dynamic> json)
      : _json = Map.unmodifiable(json);
  final Map<String, dynamic> _json;
  String get name => _json['name']?.toString() ?? '';
  String get mealType => _json['mealType']?.toString() ?? '';
  String get recipeVersionId => _json['recipeVersionId']?.toString() ?? '';
  String? get imageUrl => _optionalString('imageUrl');
  String? get imageAlt => _optionalString('imageAlt');
  num? get servings =>
      _json['servings'] is num ? _json['servings'] as num : null;
  List<MealIngredientModel> get ingredients =>
      nutritionJsonObjects(_json['ingredients'])
          .map(MealIngredientModel.fromJson)
          .toList();
  List<String> get preparationSteps =>
      nutritionJsonStrings(_json['preparationSteps']);
  List<String> get sources => nutritionJsonStrings(_json['sources']);
  List<NutritionSourceModel> get sourceDetails =>
      nutritionJsonObjects(_json['sourceDetails'])
          .map(NutritionSourceModel.fromJson)
          .toList();
  Map<String, dynamic>? get nutrients =>
      _json['nutrients'] is Map ? nutritionJsonMap(_json['nutrients']) : null;
  Map<String, dynamic> toJson() => Map.of(_json);

  String? _optionalString(String key) {
    final value = _json[key]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }
}
