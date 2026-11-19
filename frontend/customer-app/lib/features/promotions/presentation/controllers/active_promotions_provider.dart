import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/promotion_model.dart';
import '../../data/repositories/promotion_repository.dart';

final activePromotionsProvider =
    FutureProvider.autoDispose<List<PromotionModel>>((ref) {
  final cancellation = ApiCancellation();
  ref.onDispose(cancellation.cancel);
  return ref.watch(promotionRepositoryProvider).listActive(cancellation);
});
