import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'nutrition_session_controller.dart';
import 'nutrition_snapshot.dart';

final nutritionSnapshotProvider = StateNotifierProvider.autoDispose
    .family<NutritionSnapshotStore, NutritionSnapshot, String>((ref, id) {
  ref.watch(nutritionSessionProvider);
  ref.watch(authStateProvider.select((s) => s.valueOrNull?.userId));
  return NutritionSnapshotStore();
});

class NutritionSnapshotStore extends StateNotifier<NutritionSnapshot> {
  NutritionSnapshotStore() : super(const NutritionSnapshot());
  void replace(NutritionSnapshot snapshot) {
    if (mounted) state = snapshot;
  }
}
