class NutritionFactModel {
  NutritionFactModel.fromJson(Map<String, dynamic> json)
      : _json = Map.unmodifiable(json);
  final Map<String, dynamic> _json;
  String get label => _json['label']?.toString() ?? '';
  String get sourceKey => _json['sourceKey']?.toString() ?? '';
  String get assertion => _json['assertion']?.toString() ?? '';
  String get temporality => _json['temporality']?.toString() ?? '';
  Map<String, dynamic> toJson() => Map.of(_json);
}
