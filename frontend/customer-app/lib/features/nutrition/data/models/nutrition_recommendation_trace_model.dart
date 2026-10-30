import 'nutrition_json.dart';
import 'nutrition_recommendation_evidence_model.dart';
import 'nutrition_recommendation_explanation_model.dart';

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
  final List<NutritionRecommendationEvidenceModel> evidence;
  final List<NutritionRecommendationExplanationModel> explanations;
  final List<String> warnings;

  bool get isGrounded => evidence.isNotEmpty && groundingRevision != null;
  bool get isGraphDemo => groundingStrategy == 'owner_authorized_graph_demo';
  bool get isDemo =>
      isGraphDemo ||
      groundingStrategy == 'owner_authorized_corpus_demo' ||
      warnings.contains('academic_demo_owner_authorized');

  static String? _optional(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
