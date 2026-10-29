import 'nutrition_json.dart';

class NutritionRecommendationExplanationModel {
  const NutritionRecommendationExplanationModel({
    required this.recipeVersionId,
    required this.summary,
    required this.evidenceIds,
  });

  factory NutritionRecommendationExplanationModel.fromJson(
      Map<String, dynamic> json) {
    return NutritionRecommendationExplanationModel(
      recipeVersionId: json['recipeVersionId']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      evidenceIds: nutritionJsonStrings(json['evidenceIds']),
    );
  }

  final String recipeVersionId;
  final String summary;
  final List<String> evidenceIds;
}
