import 'nutrition_knowledge_answer_block_model.dart';

class NutritionKnowledgeHitModel {
  const NutritionKnowledgeHitModel({
    required this.chunkId,
    required this.heading,
    required this.pdfPage,
    required this.printedPage,
    required this.sourceTitle,
    required this.sourceRevisionId,
    this.excerpt,
  });

  final String chunkId;
  final String heading;
  final int pdfPage;
  final String? printedPage;
  final String sourceTitle;
  final String sourceRevisionId;
  final String? excerpt;

  factory NutritionKnowledgeHitModel.fromJson(Map<String, dynamic> json) =>
      NutritionKnowledgeHitModel(
        chunkId: json['chunkId'] as String? ?? '',
        heading: json['heading'] as String? ?? '',
        pdfPage: json['pdfPage'] as int? ?? 0,
        printedPage: json['printedPage']?.toString(),
        sourceTitle: json['sourceTitle'] as String? ?? '',
        sourceRevisionId: json['sourceRevisionId'] as String? ?? '',
        excerpt: json['excerpt'] as String?,
      );
}

class NutritionKnowledgeSearchModel {
  const NutritionKnowledgeSearchModel({
    required this.query,
    required this.results,
    this.localDemo = false,
    this.answerChunkId,
    this.answerChunkIds = const [],
    this.answerStatus,
    this.answerBlocks = const [],
    this.answerProvider,
  });

  final String query;
  final List<NutritionKnowledgeHitModel> results;
  final bool localDemo;
  final String? answerChunkId;
  final List<String> answerChunkIds;
  final String? answerStatus;
  final List<NutritionKnowledgeAnswerBlockModel> answerBlocks;
  final String? answerProvider;

  bool get isAiSuggestion =>
      localDemo &&
      answerProvider == 'Gemini' &&
      answerStatus == 'ai_suggestion' &&
      answerChunkId == null &&
      answerChunkIds.isEmpty &&
      answerBlocks.isNotEmpty &&
      answerBlocks.length <= 4 &&
      answerBlocks.every((block) =>
          block.text.trim().length >= 10 &&
          block.text.length <= 1200 &&
          block.chunkIds.isEmpty);

  List<NutritionKnowledgeAnswerBlockModel> get groundedAnswerBlocks {
    if (!localDemo || answerBlocks.length > 4) return const [];
    final ids = answerSources.map((hit) => hit.chunkId).toSet();
    if (answerBlocks.any((block) =>
        block.text.trim().isEmpty ||
        block.text.length > 1200 ||
        block.chunkIds.isEmpty ||
        block.chunkIds.any((id) => !ids.contains(id)))) {
      return const [];
    }
    return answerBlocks;
  }

  List<NutritionKnowledgeHitModel> get answerSources {
    if (!localDemo) return const [];
    final ids = answerChunkIds.isNotEmpty
        ? answerChunkIds
        : [if (answerChunkId != null) answerChunkId!];
    final byId = {for (final hit in results) hit.chunkId: hit};
    return ids
        .toSet()
        .take(5)
        .map((id) => byId[id])
        .whereType<NutritionKnowledgeHitModel>()
        .where((hit) => hit.excerpt?.trim().isNotEmpty ?? false)
        .toList(growable: false);
  }

  NutritionKnowledgeHitModel? get answer {
    final sources = answerSources;
    return sources.isEmpty ? null : sources.first;
  }

  factory NutritionKnowledgeSearchModel.fromJson(Map<String, dynamic> json) =>
      NutritionKnowledgeSearchModel(
        query: json['query'] as String? ?? '',
        localDemo: json['localDemo'] == true,
        answerChunkId: json['answerChunkId'] as String?,
        answerChunkIds: (json['answerChunkIds'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        answerStatus: json['answerStatus'] as String?,
        answerProvider: json['answerProvider'] as String?,
        answerBlocks: (json['answerBlocks'] as List<dynamic>? ?? const [])
            .map((item) => NutritionKnowledgeAnswerBlockModel.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(growable: false),
        results: (json['results'] as List<dynamic>? ?? const [])
            .map((item) => NutritionKnowledgeHitModel.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(growable: false),
      );
}
