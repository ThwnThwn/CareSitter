import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import '../models/meal_feedback_list_model.dart';

final mealFeedbackRepositoryProvider =
    Provider((ref) => MealFeedbackRepository(ref.read(dioClientProvider)));

class MealFeedbackRepository {
  const MealFeedbackRepository(this.api);
  final DioClient api;
  Future<MealFeedbackListModel> load(
          String beneficiaryId, String planId, ApiCancellation token) async =>
      MealFeedbackListModel.fromJson(
          (await api.getCancelable<Map<String, dynamic>>(
                  '/beneficiaries/$beneficiaryId/meal-feedback',
                  query: {'planId': planId},
                  cancelToken: token.transportToken))
              .data!);
  Future<void> submit(String beneficiaryId, String planId, String recipeId,
      String feedback, String key) async {
    await api.postIdempotent<Map<String, dynamic>>(
        '/beneficiaries/$beneficiaryId/meal-feedback',
        idempotencyKey: key,
        data: {
          'planId': planId,
          'recipeVersionId': recipeId,
          'feedback': feedback
        });
  }

  Future<void> review(
      String beneficiaryId, String id, bool approve, int revision) async {
    await api.put<Map<String, dynamic>>(
        '/beneficiaries/$beneficiaryId/meal-feedback/$id/review',
        data: {'approve': approve, 'expectedHealthRevision': revision});
  }
}
