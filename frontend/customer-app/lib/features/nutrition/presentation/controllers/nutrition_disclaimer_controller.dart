import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sources/nutrition_disclaimer_ack_store.dart';

typedef NutritionDisclaimerKey = ({String? userId, String version});

enum NutritionDisclaimerState { loading, needsAck, acknowledged, unavailable }

enum NutritionDisclaimerAckResult { saved, savedInMemoryOnly, stale }

final nutritionDisclaimerControllerProvider = NotifierProvider.autoDispose
    .family<NutritionDisclaimerController, NutritionDisclaimerState,
        NutritionDisclaimerKey>(NutritionDisclaimerController.new);

class NutritionDisclaimerController extends AutoDisposeFamilyNotifier<
    NutritionDisclaimerState, NutritionDisclaimerKey> {
  bool _active = false;
  bool _saving = false;

  @override
  NutritionDisclaimerState build(NutritionDisclaimerKey arg) {
    _active = true;
    ref.onDispose(() => _active = false);
    if (arg.userId == null || arg.userId!.trim().isEmpty) {
      return NutritionDisclaimerState.unavailable;
    }
    final store = ref.read(nutritionDisclaimerAckStoreProvider);
    Future.microtask(() => _load(store, arg));
    return NutritionDisclaimerState.loading;
  }

  Future<void> _load(
      NutritionDisclaimerAckStore store, NutritionDisclaimerKey key) async {
    bool acknowledged;
    try {
      acknowledged = await store.isAcknowledged(key.userId!, key.version);
    } catch (_) {
      // Storage failure must still require the warning to be acknowledged.
      acknowledged = false;
    }
    if (!_active) return;
    state = acknowledged
        ? NutritionDisclaimerState.acknowledged
        : NutritionDisclaimerState.needsAck;
  }

  Future<NutritionDisclaimerAckResult> acknowledge() async {
    if (!_active ||
        _saving ||
        state == NutritionDisclaimerState.unavailable ||
        state == NutritionDisclaimerState.loading) {
      return NutritionDisclaimerAckResult.stale;
    }
    if (state == NutritionDisclaimerState.acknowledged) {
      return NutritionDisclaimerAckResult.saved;
    }
    _saving = true;
    var result = NutritionDisclaimerAckResult.saved;
    try {
      await ref
          .read(nutritionDisclaimerAckStoreProvider)
          .acknowledge(arg.userId!, arg.version);
    } catch (_) {
      result = NutritionDisclaimerAckResult.savedInMemoryOnly;
    }
    if (!_active) return NutritionDisclaimerAckResult.stale;
    _saving = false;
    state = NutritionDisclaimerState.acknowledged;
    return result;
  }
}
