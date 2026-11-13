import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import '../../data/repositories/nutrition_repository.dart';
import '../../data/models/nutrition_capabilities_model.dart';

final nutritionCapabilitiesProvider =
    FutureProvider.autoDispose<NutritionCapabilitiesModel?>((ref) async {
  final session = ref.watch(authStateProvider
      .select((s) => (s.valueOrNull?.userId, s.valueOrNull?.isAuthenticated)));
  if (session.$2 != true) return null;
  final token = ApiCancellation();
  ref.onDispose(token.cancel);
  try {
    return await ref.read(nutritionRepositoryProvider).capabilities(token);
  } catch (_) {
    return null;
  }
});

final nutritionEntryProvider = FutureProvider.autoDispose<bool>((ref) async {
  return (await ref.watch(nutritionCapabilitiesProvider.future))?.enabled ==
      true;
});

final nutritionSelectedBeneficiaryProvider = StateNotifierProvider.autoDispose<
    NutritionSelectedBeneficiaryController,
    AsyncValue<String?>>((ref) => NutritionSelectedBeneficiaryController());

class NutritionSelectedBeneficiaryController
    extends StateNotifier<AsyncValue<String?>> {
  NutritionSelectedBeneficiaryController() : super(const AsyncData(null));

  void select(String beneficiaryId) {
    state = AsyncData(beneficiaryId);
  }

  void clear() {
    state = const AsyncData(null);
  }
}
