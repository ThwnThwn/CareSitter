import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/nutrition_knowledge_model.dart';

final nutritionKnowledgeRepositoryProvider = Provider(
    (ref) => NutritionKnowledgeRepository(ref.read(dioClientProvider)));

class NutritionKnowledgeRepository {
  const NutritionKnowledgeRepository(this.api);

  final DioClient api;

  Future<NutritionKnowledgeSearchModel> search(
      String query, ApiCancellation cancellation) async {
    final response = await api.getCancelable<Map<String, dynamic>>(
      '/nutrition/knowledge',
      query: {'q': query},
      cancelToken: cancellation.transportToken,
    );
    return NutritionKnowledgeSearchModel.fromJson(response.data!);
  }
}
