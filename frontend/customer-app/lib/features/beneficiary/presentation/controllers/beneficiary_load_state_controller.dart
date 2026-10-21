import 'package:flutter_riverpod/flutter_riverpod.dart';

final beneficiaryLoadStateProvider =
    NotifierProvider<BeneficiaryLoadStateController, AsyncValue<void>>(
  BeneficiaryLoadStateController.new,
);

class BeneficiaryLoadStateController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncLoading();

  void setLoading() => state = const AsyncLoading();

  void setLoaded() => state = const AsyncData(null);

  void setError(Object error, StackTrace stackTrace) {
    state = AsyncError(error, stackTrace);
  }
}
