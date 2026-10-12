class MealPlanSummaryModel {
  MealPlanSummaryModel.fromJson(Map<String, dynamic> json)
      : _json = Map.unmodifiable(json);
  final Map<String, dynamic> _json;
  String get id => _json['id']?.toString() ?? '';
  String get status => _json['status']?.toString() ?? '';
  String get plannedDate {
    final data = _json['data'];
    return data is Map ? data['plannedDate']?.toString() ?? '' : '';
  }

  Map<String, dynamic> toJson() => Map.of(_json);
}
