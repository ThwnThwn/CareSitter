import 'dart:collection';
import 'nutrition_result_model.dart';
import 'nutrition_json.dart';

/// DTO chung của assessment/recommendation/plan và danh sách lựa chọn.
class NutritionResourceModel extends UnmodifiableMapView<String, dynamic> {
  NutritionResourceModel.fromJson(Map<String, dynamic> json)
      : super(Map.of(json));
  String get id => this['id']?.toString() ?? '';
  String get status => this['status']?.toString() ?? '';
  int get healthRevision => (this['healthRevision'] as num?)?.toInt() ?? 0;
  Map get payload => this['data'] is Map ? this['data'] as Map : const {};
  NutritionResultModel get result =>
      NutritionResultModel.fromJson(nutritionJsonMap(this['data']));
  NutritionResourceModel withStatus(String status) =>
      NutritionResourceModel.fromJson({...this, 'status': status});
  Map<String, dynamic> toJson() => Map.of(this);
}
