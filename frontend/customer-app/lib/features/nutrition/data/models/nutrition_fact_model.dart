class NutritionFactModel {
  NutritionFactModel.fromJson(Map<String, dynamic> json)
      : _json = Map.unmodifiable(json);
  final Map<String, dynamic> _json;
  String get label => _json['label']?.toString() ?? '';
  String get sourceKey => _json['sourceKey']?.toString() ?? '';
  String get quote => _json['quote']?.toString() ?? '';
  String get subject => _json['subject']?.toString() ?? '';
  String get assertion => _json['assertion']?.toString() ?? '';
  String get temporality => _json['temporality']?.toString() ?? '';

  bool get fromStructuredProfile =>
      sourceKey.startsWith('allergies/') ||
      sourceKey.startsWith('chronicConditions/');

  bool describesSameFact(NutritionFactModel other) =>
      _json['kind'] == other._json['kind'] &&
      _json['code'] == other._json['code'] &&
      subject == other.subject &&
      assertion == other.assertion &&
      temporality == other.temporality;

  Map<String, dynamic> toJson() => Map.of(_json);
}
