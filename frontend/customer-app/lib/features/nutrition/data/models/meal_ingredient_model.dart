class MealIngredientModel {
  MealIngredientModel.fromJson(Map<String, dynamic> json)
      : _json = Map.unmodifiable(json);
  final Map<String, dynamic> _json;
  String get name => _json['name']?.toString() ?? '';
  num? get amount => _json['amount'] is num ? _json['amount'] as num : null;
  String get unit => _json['unit']?.toString() ?? '';
  String get basis => _json['basis']?.toString() ?? '';
  Map<String, dynamic> toJson() => Map.of(_json);
}
