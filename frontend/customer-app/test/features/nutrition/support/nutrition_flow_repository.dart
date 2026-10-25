import 'dart:async';

import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/nutrition/data/models/health_profile_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/meal_plan_summary_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_capabilities_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/nutrition_resource_model.dart';
import 'package:caresitter_customer/features/nutrition/data/models/recipe_option_model.dart';
import 'package:caresitter_customer/features/nutrition/data/repositories/nutrition_repository.dart';

class NutritionFlowRepository extends NutritionRepository {
  NutritionFlowRepository() : super(_UnusedDio());

  final writes = <({String route, Map<String, dynamic> data})>[];
  final _responses = <String, NutritionResourceModel>{};
  String assessmentStatus = 'awaiting_confirmation';
  bool assessmentRetryable = true;
  bool loseAssessmentResponse = false;
  bool loseRecommendationResponse = false;
  bool catalogChanged = false;
  AppApiException? planReadError;
  Completer<NutritionResourceModel>? pendingAssessmentRead;
  NutritionResourceModel? recommendation;
  NutritionResourceModel? saved;
  int healthCalls = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<NutritionCapabilitiesModel> capabilities(
          ApiCancellation token) async =>
      const NutritionCapabilitiesModel(
        enabled: true,
        assessmentsEnabled: true,
        recommendationsEnabled: true,
      );

  @override
  Future<HealthProfileModel> health(String id, ApiCancellation token) async {
    healthCalls++;
    return HealthProfileModel.fromJson({
      'revision': 7,
      'allergyStatus': 'reported_none',
      'healthHistory': {
        'nutrition': {
          'schemaVersion': 1,
          'conditionsStatus': 'reported_none',
          'medicationsStatus': 'reported_none',
          'feedingRoute': 'oral',
          'swallowingStatus': 'normal',
          'fluidRestriction': 'none',
          'electrolyteRestriction': 'none',
        },
      },
    });
  }

  @override
  Future<List<MealPlanSummaryModel>> savedPlans(
    String id,
    ApiCancellation token,
  ) async =>
      [
        if (saved != null) MealPlanSummaryModel.fromJson(saved!.toJson()),
      ];

  @override
  Future<NutritionResourceModel> read(
    String id,
    String route,
    ApiCancellation token,
  ) async {
    if (route.startsWith('nutrition-assessments/')) {
      return pendingAssessmentRead == null
          ? resource('assessment', 'awaiting_confirmation')
          : await pendingAssessmentRead!.future;
    }
    if (route.startsWith('meal-plans/')) {
      if (planReadError != null) throw planReadError!;
      if (saved != null) return saved!;
    }
    throw StateError('Unexpected read: $route');
  }

  @override
  Future<List<RecipeOptionModel>> replacementOptions(
          String id,
          String recommendationId,
          String mealType,
          ApiCancellation token) async =>
      [
        RecipeOptionModel.fromJson({
          'versionId': 'replacement-recipe',
          'name': 'Súp bí đỏ',
          'servings': 1,
        }),
      ];

  @override
  Future<NutritionResourceModel> write(String id, String route,
      Map<String, dynamic> data, ApiCancellation token) async {
    writes.add((route: route, data: Map.of(data)));
    final key = '$route:${data['idempotencyKey']}';
    final cached = _responses[key];
    if (cached != null) {
      return catalogChanged ? cached.withStatus('stale') : cached;
    }
    final NutritionResourceModel response;
    if (route == 'nutrition-assessments') {
      response = resource('assessment-${_responses.length}', assessmentStatus,
          data: {
            if (assessmentStatus == 'failed') 'retryable': assessmentRetryable
          });
    } else if (route.endsWith('/confirm')) {
      response =
          resource(route.split('/')[1], 'confirmed', decision: 'eligible');
    } else if (route == 'meal-recommendations') {
      response =
          resource('recommendation-${_responses.length}', 'suggested', data: {
        'plannedDate': data['plannedDate'] ?? '2026-01-01',
        'meals': [meal('breakfast', 'Cháo yến mạch')],
      });
      recommendation = response;
    } else if (route.endsWith('/replacements')) {
      response =
          resource('replacement-${_responses.length}', 'suggested', data: {
        'plannedDate': recommendation!.result.plannedDate,
        'meals': [meal('breakfast', 'Súp bí đỏ')],
      });
      recommendation = response;
    } else if (route == 'meal-plans') {
      response = resource('plan-${_responses.length}', 'saved',
          decision: 'suggested',
          data: recommendation!.payload.cast<String, dynamic>());
      saved = response;
    } else {
      throw StateError('Unexpected write: $route');
    }
    _responses[key] = response;
    if (route == 'nutrition-assessments' && loseAssessmentResponse) {
      loseAssessmentResponse = false;
      throw const AppApiException(message: 'Mất kết nối', statusCode: 503);
    }
    if (route == 'meal-recommendations' && loseRecommendationResponse) {
      loseRecommendationResponse = false;
      throw const AppApiException(message: 'Mất kết nối', statusCode: 503);
    }
    return response;
  }

  static NutritionResourceModel resource(String id, String status,
          {String? decision, Map<String, dynamic> data = const {}}) =>
      NutritionResourceModel.fromJson({
        'id': id,
        'status': status,
        'healthRevision': 7,
        'data': {
          'decision': {'state': decision ?? status},
          ...data,
        },
      });

  static Map<String, dynamic> meal(String type, String name) => {
        'versionId': 'recipe-$type',
        'mealType': type,
        'name': name,
        'servings': 1,
        'nutrients': {'energy_kcal': 300},
      };
}

class _UnusedDio implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
