import 'nutrition_json.dart';
import 'nutrition_recommendation_evidence_model.dart';
import 'nutrition_recommendation_explanation_model.dart';

class NutritionMealGraphStepModel {
  const NutritionMealGraphStepModel(this.nodeId, this.heading, this.pages);

  factory NutritionMealGraphStepModel.fromJson(Map<String, dynamic> json) =>
      NutritionMealGraphStepModel(
        json['nodeId']?.toString() ?? '',
        json['heading']?.toString(),
        json['pages'] is List
            ? (json['pages'] as List).whereType<int>().toList(growable: false)
            : const [],
      );

  final String nodeId;
  final String? heading;
  final List<int> pages;
}

class NutritionMealCitationModel {
  const NutritionMealCitationModel(
      this.title, this.chapter, this.heading, this.pages, this.graphPath);

  factory NutritionMealCitationModel.fromJson(Map<String, dynamic> json) =>
      NutritionMealCitationModel(
        json['title']?.toString() ?? '',
        json['chapter']?.toString(),
        json['heading']?.toString(),
        json['pages']?.toString(),
        nutritionJsonObjects(json['graphPath'])
            .map(NutritionMealGraphStepModel.fromJson)
            .toList(growable: false),
      );

  final String title;
  final String? chapter;
  final String? heading;
  final String? pages;
  final List<NutritionMealGraphStepModel> graphPath;
}

class NutritionRecommendationTraceModel {
  const NutritionRecommendationTraceModel({
    required this.strategy,
    required this.usedAi,
    required this.evidence,
    required this.explanations,
    this.warnings = const [],
    this.model,
    this.promptVersion,
    this.groundingRevision,
    this.groundingStrategy,
    this.releaseStatus = 'demo',
    this.retrievalStrategy,
    this.graphRole = 'none',
    this.citationScope = 'metadata_only',
    this.citations = const [],
    this.verifiedReasons = const [],
    this.disclaimer,
    this.disclaimerVersion,
  });

  factory NutritionRecommendationTraceModel.fromJson(
      Map<String, dynamic> json) {
    return NutritionRecommendationTraceModel(
      strategy: json['strategy']?.toString() ?? '',
      usedAi: json['usedAi'] == true,
      model: _optional(json['model']),
      promptVersion: _optional(json['promptVersion']),
      groundingRevision: _optional(json['groundingRevision']),
      groundingStrategy: _optional(json['groundingStrategy']),
      releaseStatus: _optional(json['releaseStatus']) ?? 'demo',
      retrievalStrategy: _optional(json['retrievalStrategy']),
      graphRole: _optional(json['graphRole']) ?? 'none',
      citationScope: _optional(json['citationScope']) ?? 'metadata_only',
      citations: nutritionJsonObjects(json['citations'])
          .map(NutritionMealCitationModel.fromJson)
          .toList(growable: false),
      verifiedReasons: nutritionJsonObjects(json['verifiedReasons']),
      disclaimer: _optional(json['disclaimer']),
      disclaimerVersion: _optional(json['disclaimerVersion']),
      warnings: json['warnings'] is List
          ? (json['warnings'] as List)
              .whereType<String>()
              .toList(growable: false)
          : const [],
      evidence: nutritionJsonObjects(json['evidence'])
          .map(NutritionRecommendationEvidenceModel.fromJson)
          .toList(growable: false),
      explanations: nutritionJsonObjects(json['explanations'])
          .map(NutritionRecommendationExplanationModel.fromJson)
          .toList(growable: false),
    );
  }

  final String strategy;
  final bool usedAi;
  final String? model;
  final String? promptVersion;
  final String? groundingRevision;
  final String? groundingStrategy;
  final String releaseStatus;
  final String? retrievalStrategy;
  final String graphRole;
  final String citationScope;
  final List<NutritionMealCitationModel> citations;
  final List<Map<String, dynamic>> verifiedReasons;
  final String? disclaimer;
  final String? disclaimerVersion;
  final List<NutritionRecommendationEvidenceModel> evidence;
  final List<NutritionRecommendationExplanationModel> explanations;
  final List<String> warnings;

  bool get isGrounded =>
      {'demo', 'reference', 'released'}.contains(releaseStatus) &&
      evidence.isNotEmpty &&
      groundingRevision != null;
  bool get isGraphDemo =>
      groundingStrategy == 'owner_authorized_graph_demo' && isGrounded;
  bool get isDemo =>
      releaseStatus == 'demo' ||
      !{'reference', 'released', 'ungrounded'}.contains(releaseStatus) ||
      isGraphDemo ||
      groundingStrategy == 'owner_authorized_corpus_demo' ||
      warnings.contains('academic_demo_owner_authorized');
  bool get isReviewedRelease => releaseStatus == 'released';
  bool get isReference => releaseStatus == 'reference';
  bool get hasGraphExplanation =>
      (isReference || isReviewedRelease) &&
      graphRole == 'explanation' &&
      citations.any((citation) => citation.graphPath.isNotEmpty);
  bool get usesGraphRetrieval =>
      (isReference || isReviewedRelease) &&
      graphRole == 'retrieval' &&
      retrievalStrategy == 'graph';

  static String? _optional(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
