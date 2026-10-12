class RecipeOptionModel {
  RecipeOptionModel.fromJson(Map<String, dynamic> json)
      : _json = Map.unmodifiable(json);
  final Map<String, dynamic> _json;
  String get versionId => _json['versionId']?.toString() ?? '';
  String get name => _json['name']?.toString() ?? '';
  num? get servings =>
      _json['servings'] is num ? _json['servings'] as num : null;
  Map<String, dynamic> toJson() => Map.of(_json);
}
