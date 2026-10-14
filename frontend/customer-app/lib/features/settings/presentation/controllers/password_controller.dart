import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/core/auth/auth_session_scope.dart';
import '../../data/repositories/settings_repository.dart';

typedef PasswordWrite = Future<bool> Function(
    {required String currentPassword,
    required String newPassword,
    ApiCancellation? cancellation});

final passwordControllerProvider =
    StateNotifierProvider.autoDispose<PasswordController, bool>((ref) {
  final session = AuthSessionScope.watch(ref);
  return PasswordController(
      write: ref.read(settingsRepositoryProvider).changePassword,
      isCurrent: () => session.isCurrent,
      cancellation: session.cancellation);
});

class PasswordController extends StateNotifier<bool> {
  PasswordController(
      {required PasswordWrite write,
      required bool Function() isCurrent,
      ApiCancellation? cancellation})
      : _write = write,
        _isCurrent = isCurrent,
        _cancellation = cancellation ?? ApiCancellation(),
        super(false);
  final PasswordWrite _write;
  final bool Function() _isCurrent;
  final ApiCancellation _cancellation;
  bool get isCurrent => mounted && _isCurrent();
  @override
  void dispose() {
    _cancellation.cancel();
    super.dispose();
  }

  Future<bool> changePassword(
      {required String currentPassword, required String newPassword}) async {
    if (!isCurrent || state) return false;
    state = true;
    var changed = false;
    try {
      changed = await _write(
          currentPassword: currentPassword,
          newPassword: newPassword,
          cancellation: _cancellation);
      return isCurrent && changed;
    } catch (_) {
      if (!isCurrent) return false;
      rethrow;
    } finally {
      if (isCurrent && !changed) state = false;
    }
  }
}
