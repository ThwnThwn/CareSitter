import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import '../../data/models/shift_model.dart';
import '../../data/repositories/shift_repository.dart';

final shiftHistoryProvider = FutureProvider.autoDispose
    .family<({List<ShiftModel> items, bool hasMore}), int>((ref, page) {
  final session = ref.watch(authStateProvider.select((state) =>
      (state.valueOrNull?.userId, state.valueOrNull?.isAuthenticated)));
  if (session.$2 != true) return (items: const <ShiftModel>[], hasMore: false);
  final token = ApiCancellation();
  ref.onDispose(token.cancel);
  return ref.watch(shiftRepositoryProvider).loadHistory(page, token: token);
});
