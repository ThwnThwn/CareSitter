import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_cancellation.dart';
import 'auth_notifier.dart';

/// Owns work started by one login, including a later login of the same user.
class AuthSessionScope {
  AuthSessionScope.watch(this._ref) {
    final notifier = _ref.read(authStateProvider.notifier);
    _identity = _ref.watch(authStateProvider.select((value) => (
          value.valueOrNull?.userId,
          value.valueOrNull?.isAuthenticated == true,
          notifier.sessionGeneration,
        )));
    _ref.listen(authStateProvider, (_, __) {
      if (!isCurrent) close();
    });
    _ref.onDispose(close);
  }

  final Ref _ref;
  late final (String?, bool, int) _identity;
  final cancellation = ApiCancellation();
  bool _closed = false;

  bool get isCurrent {
    if (_closed || !_identity.$2 || _identity.$1 == null) return false;
    final auth = _ref.read(authStateProvider).valueOrNull;
    return auth?.isAuthenticated == true &&
        auth?.userId == _identity.$1 &&
        _ref.read(authStateProvider.notifier).sessionGeneration == _identity.$3;
  }

  void requireCurrent() {
    if (!isCurrent) throw StateError('Phiên đăng nhập đã thay đổi.');
  }

  void close() {
    _closed = true;
    cancellation.cancel();
  }
}
