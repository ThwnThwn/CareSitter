import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'recovery_controller.dart';
import 'recovery_email_state.dart';
export 'recovery_email_state.dart';

enum RecoveryEmailResult { confirmed, signIn, ignored }

final recoveryEmailControllerProvider = StateNotifierProvider.autoDispose<
    RecoveryEmailController, RecoveryEmailState>((ref) {
  ref.watch(authStateProvider
      .select((s) => (s.valueOrNull?.userId, s.valueOrNull?.isAuthenticated)));
  final controller = RecoveryEmailController(
      ref.read(recoveryControllerProvider),
      logout: () => ref.read(authStateProvider.notifier).logout());
  Future.microtask(controller.load);
  return controller;
});

class RecoveryEmailController extends StateNotifier<RecoveryEmailState> {
  RecoveryEmailController(this.actions,
      {required this.logout, DateTime Function()? clock})
      : clock = clock ?? DateTime.now,
        super(const RecoveryEmailState());
  final RecoveryController actions;
  final Future<void> Function() logout;
  final DateTime Function() clock;
  Timer? _timer;
  int _generation = 0;
  bool _loading = false;
  bool _current(int generation) => mounted && generation == _generation;

  Future<void> load() async {
    if (!mounted || _loading) return;
    _loading = true;
    final generation = _generation;
    state = state.copy(loading: true);
    try {
      final profile = await actions.emailProfile();
      if (!_current(generation)) return;
      state = state.copy(
          currentEmail: profile.email,
          verified: profile.verified,
          hasPassword: profile.hasPassword,
          loading: false);
    } catch (error) {
      if (_current(generation)) {
        state = state.copy(loading: false, error: recoveryError(error));
      }
    } finally {
      if (_current(generation)) _loading = false;
    }
  }

  void changeInfo() {
    _generation++;
    _timer?.cancel();
    state = state.copy(clearChallenge: true, busy: false);
  }

  void dismissMessage() {
    state = state.copy(error: state.error);
  }

  Future<bool> request(String email, String password,
      {bool resend = false}) async {
    if (!mounted || state.busy || (resend && state.remaining > 0)) return false;
    final generation = _generation;
    final changing = state.currentEmail != null &&
        email.trim().toLowerCase() != state.currentEmail;
    state = state.copy(busy: true);
    try {
      final challenge =
          await actions.requestEmail(email, changing ? password : null);
      if (!_current(generation)) return false;
      state = state.copy(
          busy: false,
          challengeId: challenge.id,
          now: clock(),
          resendAt: clock().add(Duration(seconds: challenge.resendAfter)),
          expiresAt: clock().add(Duration(seconds: challenge.expiresIn)));
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          state = state.copy(
              now: clock(), error: state.error, message: state.message);
        }
      });
      return true;
    } catch (error) {
      if (_current(generation)) {
        state = state.copy(busy: false, error: recoveryError(error));
      }
      return false;
    }
  }

  Future<RecoveryEmailResult> confirm(String code) async {
    if (!mounted || state.busy || state.challengeId == null) {
      return RecoveryEmailResult.ignored;
    }
    if (state.expiresAt != null && !clock().isBefore(state.expiresAt!)) {
      state = state.copy(error: 'Mã đã hết hạn. Hãy gửi lại mã.');
      return RecoveryEmailResult.ignored;
    }
    final generation = _generation;
    state = state.copy(busy: true);
    try {
      final response =
          await actions.confirmEmailProfile(state.challengeId!, code);
      if (!_current(generation)) return RecoveryEmailResult.ignored;
      _timer?.cancel();
      if (response.sessionsRevoked) {
        await logout();
        return RecoveryEmailResult.signIn;
      }
      state = state.copy(
          currentEmail: response.email,
          verified: true,
          clearChallenge: true,
          busy: false,
          message:
              'Email đã được xác minh. Bạn có thể dùng email này để khôi phục mật khẩu.');
      return RecoveryEmailResult.confirmed;
    } catch (error) {
      if (_current(generation)) {
        state = state.copy(busy: false, error: recoveryError(error));
      }
      return RecoveryEmailResult.ignored;
    }
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
