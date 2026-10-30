class NutritionRecommendationEvidenceModel {
  const NutritionRecommendationEvidenceModel({
    required this.id,
    required this.title,
    required this.reference,
    required this.locator,
    this.chapter,
    this.printedPages,
  });

  factory NutritionRecommendationEvidenceModel.fromJson(
      Map<String, dynamic> json) {
    return NutritionRecommendationEvidenceModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      locator: json['locator']?.toString() ?? '',
      chapter: _optional(json['chapter']),
      printedPages: _optional(json['printedPages']),
    );
  }

  final String id;
  final String title;
  final String reference;
  final String locator;
  final String? chapter;
  final String? printedPages;

  static String? _optional(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
