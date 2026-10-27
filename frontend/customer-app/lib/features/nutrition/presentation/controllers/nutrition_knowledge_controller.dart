import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/nutrition_knowledge_model.dart';
import '../../data/repositories/nutrition_knowledge_repository.dart';

final nutritionKnowledgeControllerProvider = StateNotifierProvider.autoDispose<
    NutritionKnowledgeController, AsyncValue<NutritionKnowledgeSearchModel?>>(
  (ref) {
    ref.watch(authStateProvider.select((state) => state.valueOrNull?.userId));
    return NutritionKnowledgeController(ref.read(nutritionKnowledgeRepositoryProvider));
  },
);

class NutritionKnowledgeController
    extends StateNotifier<AsyncValue<NutritionKnowledgeSearchModel?>> {
  NutritionKnowledgeController(this._repository) : super(const AsyncData(null));

  final NutritionKnowledgeRepository _repository;
  ApiCancellation? _cancellation;

  Future<void> search(String query) async {
    final cleaned = query.trim();
    if (cleaned.length < 3 || cleaned.length > 160) return;
    _cancellation?.cancel();
    final cancellation = ApiCancellation();
    _cancellation = cancellation;
    state = const AsyncLoading();
    try {
      final result = await _repository.search(cleaned, cancellation);
      if (mounted && !cancellation.isCancelled) state = AsyncData(result);
    } catch (error, stack) {
      if (mounted && !cancellation.isCancelled) state = AsyncError(error, stack);
    }
  }

  @override
  void dispose() {
    _cancellation?.cancel();
    super.dispose();
  }
}
