import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_session_scope.dart';
import 'package:caresitter_customer/features/refunds/data/models/refund_record.dart';
import 'package:caresitter_customer/features/refunds/data/repositories/refund_repository.dart';

export 'package:caresitter_customer/features/refunds/data/models/refund_record.dart';

final refundsProvider =
    AsyncNotifierProvider.autoDispose<RefundsNotifier, List<RefundRecord>>(
  RefundsNotifier.new,
);

class RefundsNotifier extends AutoDisposeAsyncNotifier<List<RefundRecord>> {
  late AuthSessionScope _session;

  RefundRepository get _repository => ref.read(refundRepositoryProvider);

  @override
  Future<List<RefundRecord>> build() async {
    _session = AuthSessionScope.watch(ref);
    final session = _session;
    ref.listen(authStateProvider, (_, next) {
      if (!session.isCurrent) {
        state = next.valueOrNull?.isAuthenticated == true
            ? const AsyncLoading()
            : const AsyncData([]);
      }
    });
    if (!session.isCurrent) return const [];
    return _fetch(session);
  }

  Future<void> refresh() async {
    final session = _session..requireCurrent();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(session));
  }

  Future<List<RefundRecord>> _fetch(AuthSessionScope session) async {
    final items = await _repository.getMyRefunds(
      cancellation: session.cancellation,
    );
    session.requireCurrent();
    return items;
  }
}
