import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'recovery_controller.dart';
import 'password_recovery_state.dart';
export 'password_recovery_state.dart';

final passwordRecoveryControllerProvider = StateNotifierProvider.autoDispose<
    PasswordRecoveryController, PasswordRecoveryState>((ref) {
  ref.watch(authStateProvider
      .select((s) => (s.valueOrNull?.userId, s.valueOrNull?.isAuthenticated)));
  return PasswordRecoveryController(ref.read(recoveryControllerProvider));
});

class PasswordRecoveryController extends StateNotifier<PasswordRecoveryState> {
  PasswordRecoveryController(this.actions, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now,
        super(const PasswordRecoveryState());
  final RecoveryController actions;
  final DateTime Function() clock;
  Timer? _timer;
  String? _grantToken;
  int _generation = 0;
  bool _current(int generation) => mounted && generation == _generation;

  void restart() {
    _generation++;
    _timer?.cancel();
    _grantToken = null;
    state = const PasswordRecoveryState();
  }

  void _tick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) state = state.copy(now: clock(), error: state.error);
    });
  }

  Future<bool> request(String email, {bool resend = false}) async {
    if (!mounted || state.busy || (resend && state.remaining > 0)) return false;
    final generation = _generation;
    state = state.copy(busy: true);
    try {
      final challenge = await actions.request(email);
      if (!_current(generation)) return false;
      _grantToken = null;
      state = PasswordRecoveryState(
          step: 1,
          challengeId: challenge.id,
          message: challenge.message,
          expiresIn: challenge.expiresIn,
          now: clock(),
          resendAt: clock().add(Duration(seconds: challenge.resendAfter)),
          codeExpiresAt: clock().add(Duration(seconds: challenge.expiresIn)));
      _tick();
      return true;
    } catch (error) {
      if (_current(generation)) {
        state = state.copy(busy: false, error: recoveryError(error));
      }
      return false;
    }
  }

  Future<bool> submit(
      {required String code,
      required String password,
      required String confirmation}) async {
    if (!mounted || state.busy || state.step == 0 || state.step == 3) {
      return false;
    }
    if (state.step == 1 &&
        state.codeExpiresAt != null &&
        !clock().isBefore(state.codeExpiresAt!)) {
      state = state.copy(error: 'Mã đã hết hạn. Hãy gửi lại mã.');
      return false;
    }
    if (state.step == 2 &&
        (_grantToken == null ||
            state.grantExpiresAt == null ||
            !clock().isBefore(state.grantExpiresAt!))) {
      state =
          state.copy(error: 'Thời gian đặt mật khẩu đã hết. Hãy bắt đầu lại.');
      return false;
    }
    final generation = _generation;
    final step = state.step;
    state = state.copy(busy: true);
    try {
      if (step == 1) {
        final grant = await actions.verify(state.challengeId!, code.trim());
        if (!_current(generation)) return false;
        _grantToken = grant.token;
        state = state.copy(
            step: 2,
            busy: false,
            grantExpiresAt: clock().add(Duration(seconds: grant.expiresIn)));
      } else {
        await actions.reset(_grantToken!, password, confirmation);
        if (!_current(generation)) return false;
        _grantToken = null;
        _timer?.cancel();
        state = const PasswordRecoveryState(step: 3);
      }
      return true;
    } catch (error) {
      if (_current(generation)) {
        state = state.copy(busy: false, error: recoveryError(error));
      }
      return false;
    }
  }

  @override
  void dispose() {
    _generation++;
    _grantToken = null;
    _timer?.cancel();
    super.dispose();
  }
}
