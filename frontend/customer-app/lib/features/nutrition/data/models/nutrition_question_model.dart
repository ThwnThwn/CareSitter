import 'nutrition_json.dart';

class NutritionQuestionModel {
  NutritionQuestionModel.fromJson(Map<String, dynamic> json)
      : _json = Map.unmodifiable(json);
  final Map<String, dynamic> _json;

  String get id => _json['id']?.toString() ?? '';
  String get sourceField => _json['sourceField']?.toString() ?? '';
  String get inputType => _json['inputType']?.toString() ?? '';
  List<String> get options => nutritionJsonStrings(_json['options']);
  bool get required => _json['required'] == true;
  String get purpose => _json['purpose']?.toString() ?? '';
  Map<String, dynamic> toJson() => Map.of(_json);
}
