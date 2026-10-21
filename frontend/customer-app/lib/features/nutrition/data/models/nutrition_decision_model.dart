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
  bool allows(String action) {
    if (_json['allowedActions'] is List) {
      return allowedActions.contains(action);
    }
    // Older responses did not include allowedActions. Preserve only the
    // actions defined by their state instead of allowing every action.
    return switch (state) {
      'needs_information' ||
      'needs_professional_guidance' =>
        action == 'edit_health',
      'awaiting_confirmation' => action == 'edit_health' || action == 'confirm',
      'eligible' => action == 'recommend',
      'suggested' => action == 'replace' || action == 'save',
      'failed' => action == 'retry' || action == 'edit_health',
      'stale' => action == 'reload',
      _ => false,
    };
  }

  List<NutritionQuestionModel> get questions =>
      nutritionJsonObjects(_json['questions'])
          .map(NutritionQuestionModel.fromJson)
          .toList();
  Map<String, dynamic> toJson() => Map.of(_json);
}
