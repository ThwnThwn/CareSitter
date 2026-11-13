class RecipeOptionModel {
  RecipeOptionModel.fromJson(Map<String, dynamic> json)
      : _json = Map.unmodifiable(json);
  final Map<String, dynamic> _json;
  String get versionId => _json['versionId']?.toString() ?? '';
  String get name => _json['name']?.toString() ?? '';
  num? get servings =>
      _json['servings'] is num ? _json['servings'] as num : null;
  num? get energyKcal {
    final nutrients = _json['nutrients'];
    final value = nutrients is Map ? nutrients['energy_kcal'] : null;
    return value is num ? value : null;
  }

  Map<String, dynamic> toJson() => Map.of(_json);
}
