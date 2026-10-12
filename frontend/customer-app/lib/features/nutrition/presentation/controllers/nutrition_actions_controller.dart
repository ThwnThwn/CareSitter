import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import '../../data/models/nutrition_resource_model.dart';
import '../../data/models/recipe_option_model.dart';
import '../../data/models/meal_plan_summary_model.dart';
import '../../data/repositories/nutrition_repository.dart';

/// Các thao tác dinh dưỡng và khóa retry, độc lập với lifecycle/UI của flow.
class NutritionActionsController {
  NutritionActionsController(this.repository, this.beneficiaryId);
  final NutritionRepository repository;
  final String beneficiaryId;
  final Map<String, String> _keys = {};
  void healthChanged() => _keys.clear();
  Future<NutritionResourceModel> assess(int revision, ApiCancellation token,
      {bool retryFailed = false}) {
    if (retryFailed) {
      _keys.removeWhere((key, _) => key.startsWith('nutrition-assessments:'));
    }
    return _write('nutrition-assessments', revision, token);
  }

  Future<NutritionResourceModel> confirm(
          String assessmentId, int revision, ApiCancellation token) =>
      _write('nutrition-assessments/$assessmentId/confirm', revision, token);
  Future<NutritionResourceModel> recommend(
          String assessmentId, int revision, ApiCancellation token) =>
      _write('meal-recommendations', revision, token,
          {'assessmentId': assessmentId});
  Future<NutritionResourceModel> save(
          String recommendationId, int revision, ApiCancellation token) =>
      _write('meal-plans', revision, token,
          {'recommendationId': recommendationId});
  Future<NutritionResourceModel> replace(
          String recommendationId,
          String recipeVersionId,
          String mealType,
          int revision,
          ApiCancellation token) =>
      _write('meal-recommendations/$recommendationId/replacements', revision,
          token, {'recipeVersionId': recipeVersionId, 'mealType': mealType});
  Future<List<RecipeOptionModel>> options(
          String recommendationId, String mealType, ApiCancellation token) =>
      repository.replacementOptions(
          beneficiaryId, recommendationId, mealType, token);
  Future<List<MealPlanSummaryModel>> plans(ApiCancellation token) =>
      repository.savedPlans(beneficiaryId, token);
  Future<NutritionResourceModel> openPlan(String id, ApiCancellation token) =>
      repository.read(beneficiaryId, 'meal-plans/$id', token);
  Future<NutritionResourceModel> readAssessment(
          String id, ApiCancellation token) =>
      repository.read(beneficiaryId, 'nutrition-assessments/$id', token);
  Future<NutritionResourceModel> _write(
      String route, int revision, ApiCancellation token,
      [Map<String, dynamic> extra = const {}]) {
    final key = _keys.putIfAbsent(
        '$route:$revision:${jsonEncode(extra)}', () => const Uuid().v4());
    return repository.write(
        beneficiaryId,
        route,
        {'expectedHealthRevision': revision, 'idempotencyKey': key, ...extra},
        token);
  }
}
