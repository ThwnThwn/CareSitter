import 'nutrition_json.dart';
import 'nutrition_question_model.dart';

class NutritionDecisionModel {
  NutritionDecisionModel.fromJson(Map<String, dynamic> json)
      : _json = Map.unmodifiable(json);
  final Map<String, dynamic> _json;
  String? get state => _json['state']?.toString();
  List<String> get missingFields =>
      nutritionJsonStrings(_json['missingFields']);
  List<Object?> get conflicts => _json['conflicts'] is List
      ? List<Object?>.of(_json['conflicts'] as List)
      : const [];
  List<String> get allowedActions =>
      nutritionJsonStrings(_json['allowedActions']);
  bool allows(String action) =>
      _json['allowedActions'] is! List || allowedActions.contains(action);
  List<NutritionQuestionModel> get questions =>
      nutritionJsonObjects(_json['questions'])
          .map(NutritionQuestionModel.fromJson)
          .toList();
  Map<String, dynamic> toJson() => Map.of(_json);
}
