import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import '../../data/repositories/nutrition_repository.dart';
import '../../data/repositories/nutrition_entry_preference_store.dart';

final nutritionEntryProvider = FutureProvider.autoDispose<bool>((ref) async {
  final session = ref.watch(authStateProvider
      .select((s) => (s.valueOrNull?.userId, s.valueOrNull?.isAuthenticated)));
  if (session.$2 != true) return false;
  final token = ApiCancellation();
  ref.onDispose(token.cancel);
  try {
    return (await ref.read(nutritionRepositoryProvider).capabilities(token))
        .enabled;
  } catch (_) {
    return false;
  }
});

final nutritionSelectedBeneficiaryProvider = StateNotifierProvider.autoDispose<
    NutritionSelectedBeneficiaryController, AsyncValue<String?>>((ref) {
  final userId =
      ref.watch(authStateProvider.select((s) => s.valueOrNull?.userId));
  return NutritionSelectedBeneficiaryController(
    ref.read(nutritionEntryPreferenceStoreProvider),
    userId,
  );
});

class NutritionSelectedBeneficiaryController
    extends StateNotifier<AsyncValue<String?>> {
  NutritionSelectedBeneficiaryController(this._store, this._userId)
      : super(const AsyncLoading()) {
    Future.microtask(_load);
  }

  final NutritionEntryPreferenceStore _store;
  final String? _userId;

  Future<void> _load() async {
    final userId = _userId;
    if (!mounted) return;
    if (userId == null) {
      state = const AsyncData(null);
      return;
    }
    try {
      final selected = await _store.read(userId);
      if (mounted) state = AsyncData(selected);
    } catch (error, stackTrace) {
      if (mounted) state = AsyncError(error, stackTrace);
    }
  }

  Future<void> select(String beneficiaryId) async {
    final userId = _userId;
    state = AsyncData(beneficiaryId);
    if (userId == null) return;
    try {
      await _store.write(userId, beneficiaryId);
    } catch (_) {
      // Vẫn dùng lựa chọn trong bộ nhớ cho phiên hiện tại.
    }
  }

  Future<void> clear() async {
    final userId = _userId;
    state = const AsyncData(null);
    if (userId == null) return;
    try {
      await _store.clear(userId);
    } catch (_) {
      // Việc quay lại màn chọn không phụ thuộc vào lưu trữ local.
    }
  }
}
