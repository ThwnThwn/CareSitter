class NutritionKnowledgeHitModel {
  const NutritionKnowledgeHitModel({
    required this.chunkId,
    required this.heading,
    required this.excerpt,
    required this.pdfPage,
    required this.printedPage,
    required this.sourceTitle,
  });

  final String chunkId;
  final String heading;
  final String excerpt;
  final int pdfPage;
  final String? printedPage;
  final String sourceTitle;

  factory NutritionKnowledgeHitModel.fromJson(Map<String, dynamic> json) =>
      NutritionKnowledgeHitModel(
        chunkId: json['chunkId'] as String? ?? '',
        heading: json['heading'] as String? ?? '',
        excerpt: json['excerpt'] as String? ?? '',
        pdfPage: json['pdfPage'] as int? ?? 0,
        printedPage: json['printedPage']?.toString(),
        sourceTitle: json['sourceTitle'] as String? ?? '',
      );
}

class NutritionKnowledgeSearchModel {
  const NutritionKnowledgeSearchModel({required this.query, required this.results});

  final String query;
  final List<NutritionKnowledgeHitModel> results;

  factory NutritionKnowledgeSearchModel.fromJson(Map<String, dynamic> json) =>
      NutritionKnowledgeSearchModel(
        query: json['query'] as String? ?? '',
        results: (json['results'] as List<dynamic>? ?? const [])
            .map((item) => NutritionKnowledgeHitModel.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(growable: false),
      );
}
