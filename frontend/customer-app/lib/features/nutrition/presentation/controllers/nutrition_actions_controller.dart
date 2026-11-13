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
  static const planLoadTimeout = Duration(seconds: 10);
  final NutritionRepository repository;
  final String beneficiaryId;
  final Map<String, String> _keys = {};
  String? _retriedAssessmentId;
  void healthChanged() {
    _keys.clear();
    _retriedAssessmentId = null;
  }

  Future<NutritionResourceModel> assess(int revision, ApiCancellation token,
      {String? retryOf}) {
    // Rotate once per known failed assessment; a lost retry response keeps its key.
    if (retryOf != null && retryOf != _retriedAssessmentId) {
      _keys.removeWhere((key, _) => key.startsWith('nutrition-assessments:'));
      _retriedAssessmentId = retryOf;
    }
    return _write('nutrition-assessments', revision, token);
  }

  Future<NutritionResourceModel> confirm(
          String assessmentId, int revision, ApiCancellation token) =>
      _write('nutrition-assessments/$assessmentId/confirm', revision, token);
  Future<NutritionResourceModel> recommend(
          String assessmentId, int revision, ApiCancellation token,
          {required DateTime plannedDate}) =>
      _write('meal-recommendations', revision, token, {
        'assessmentId': assessmentId,
        'plannedDate':
            DateTime(plannedDate.year, plannedDate.month, plannedDate.day)
                .toIso8601String()
                .split('T')
                .first,
      });
  Future<NutritionResourceModel> save(
          String recommendationId, int revision, ApiCancellation token,
          {DateTime? plannedDate}) =>
      _write('meal-plans', revision, token, {
        'recommendationId': recommendationId,
        if (plannedDate != null)
          'plannedDate': plannedDate.toIso8601String().split('T').first,
      });
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
  Future<List<MealPlanSummaryModel>> plans(ApiCancellation token,
          {DateTime? weekStart}) =>
      repository
          .savedPlans(beneficiaryId, token, weekStart: weekStart)
          .timeout(planLoadTimeout);
  Future<NutritionResourceModel?> latestPlan(ApiCancellation token) async {
    final saved = await plans(token);
    if (saved.isEmpty || saved.first.id.isEmpty) return null;
    final now = DateTime.now();
    for (final plan in saved) {
      final date = DateTime.tryParse(plan.plannedDate);
      if (date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day &&
          plan.id.isNotEmpty) {
        return openPlan(plan.id, token);
      }
    }
    return openPlan(saved.first.id, token);
  }

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
