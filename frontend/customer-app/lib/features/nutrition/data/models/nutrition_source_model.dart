class NutritionSourceModel {
  NutritionSourceModel.fromJson(Map<String, dynamic> json)
      : _json = Map.unmodifiable(json);

  final Map<String, dynamic> _json;

  String get id => _json['id']?.toString() ?? '';
  String get title => _json['title']?.toString() ?? '';
  String get organization => _json['organization']?.toString() ?? '';
  int? get year => _json['year'] is num ? (_json['year'] as num).toInt() : null;
  String get edition => _json['edition']?.toString() ?? '';
  String get chapter => _json['chapter']?.toString() ?? '';
  String get printedPages => _json['printedPages']?.toString() ?? '';
  String get pdfPages => _json['pdfPages']?.toString() ?? '';
  String get locator => _json['locator']?.toString() ?? '';
  String get reference => _json['reference']?.toString() ?? '';
  DateTime? get verifiedOn => DateTime.tryParse(
        _json['verifiedOn']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => Map.of(_json);
}
