class NutritionKnowledgeAnswerBlockModel {
  const NutritionKnowledgeAnswerBlockModel(
      {required this.text, required this.chunkIds});

  final String text;
  final List<String> chunkIds;

  factory NutritionKnowledgeAnswerBlockModel.fromJson(
          Map<String, dynamic> json) =>
      NutritionKnowledgeAnswerBlockModel(
        text: json['text'] as String? ?? '',
        chunkIds: (json['chunkIds'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );
}
