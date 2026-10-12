import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/core/api/api_constants.dart';
import '../models/health_profile_model.dart';
import '../models/nutrition_resource_model.dart';
import '../models/nutrition_capabilities_model.dart';
import '../models/recipe_option_model.dart';
import '../models/meal_plan_summary_model.dart';

final nutritionRepositoryProvider = Provider((ref) => NutritionRepository(
    ref.read(dioClientProvider), ref.read(dioClientProvider)));

class NutritionRepository {
  final DioClient people, nutrition;
  NutritionRepository(this.people, this.nutrition);
  bool get isConfigured => kBaseUrl.isNotEmpty;
  Future<List<RecipeOptionModel>> replacementOptions(
          String id,
          String recommendationId,
          String mealType,
          ApiCancellation token) async =>
      (await list(
              id,
              'meal-recommendations/$recommendationId/replacement-options?mealType=$mealType',
              token))
          .map(RecipeOptionModel.fromJson)
          .toList();
  Future<List<MealPlanSummaryModel>> savedPlans(
          String id, ApiCancellation token) async =>
      (await list(id, 'meal-plans', token))
          .map(MealPlanSummaryModel.fromJson)
          .toList();
  Future<HealthProfileModel> health(String id, ApiCancellation token) async =>
      HealthProfileModel.fromJson(
          (await people.getCancelable<Map<String, dynamic>>(
                  '/beneficiaries/$id/health-profile',
                  cancelToken: token.transportToken))
              .data!);
  Future<HealthProfileModel> patch(String id, int revision,
          Map<String, dynamic> changes, ApiCancellation token) async =>
      HealthProfileModel.fromJson(
          (await people.patchCancelable<Map<String, dynamic>>(
                  '/beneficiaries/$id/health-profile',
                  data: {
                    'expectedHealthRevision': revision,
                    'changes': changes
                  },
                  cancelToken: token.transportToken))
              .data!);
  Future<NutritionCapabilitiesModel> capabilities(
          ApiCancellation token) async =>
      NutritionCapabilitiesModel.fromJson((await nutrition
              .getCancelable<Map<String, dynamic>>('/nutrition/capabilities',
                  cancelToken: token.transportToken))
          .data!);
  Future<NutritionResourceModel> write(String id, String route,
          Map<String, dynamic> data, ApiCancellation token) async =>
      NutritionResourceModel.fromJson((await nutrition
              .postCancelable<Map<String, dynamic>>('/beneficiaries/$id/$route',
                  data: data, cancelToken: token.transportToken))
          .data!);
  Future<NutritionResourceModel> read(
          String id, String route, ApiCancellation token) async =>
      NutritionResourceModel.fromJson((await nutrition
              .getCancelable<Map<String, dynamic>>('/beneficiaries/$id/$route',
                  cancelToken: token.transportToken))
          .data!);
  Future<List<Map<String, dynamic>>> list(
          String id, String route, ApiCancellation token) async =>
      ((await nutrition.getCancelable<List<dynamic>>(
                      '/beneficiaries/$id/$route',
                      cancelToken: token.transportToken))
                  .data ??
              [])
          .map((item) => NutritionResourceModel.fromJson(
              Map<String, dynamic>.from(item as Map)))
          .toList();
}
