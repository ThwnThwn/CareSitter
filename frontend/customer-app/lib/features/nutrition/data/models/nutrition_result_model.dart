import 'nutrition_json.dart';
import 'nutrition_decision_model.dart';
import 'nutrition_fact_model.dart';
import 'nutrition_meal_model.dart';

/// Truy cập có kiểu cho các trường đã biết; toJson giữ nguyên phần mở rộng.
class NutritionResultModel {
  NutritionResultModel.fromJson(Map<String, dynamic> json)
      : _json = Map.unmodifiable(json);
  final Map<String, dynamic> _json;
  NutritionDecisionModel get decision =>
      NutritionDecisionModel.fromJson(nutritionJsonMap(_json['decision']));
  List<NutritionFactModel> get facts => nutritionJsonObjects(_json['facts'])
      .map(NutritionFactModel.fromJson)
      .toList();
  List<NutritionMealModel> get meals => nutritionJsonObjects(_json['meals'])
      .map(NutritionMealModel.fromJson)
      .toList();
  bool get retryable => _json['retryable'] == true;
  String? get errorCode => _json['errorCode']?.toString();
  String? get plannedDate => _json['plannedDate']?.toString();
  Map<String, dynamic> toJson() => Map.of(_json);
}
