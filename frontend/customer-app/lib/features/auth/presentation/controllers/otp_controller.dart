import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'auth_session_controller.dart';
import 'otp_state.dart';
export 'otp_state.dart';

final otpControllerProvider = StateNotifierProvider.autoDispose
    .family<OtpController, OtpState, String>((ref, email) {
  ref.watch(authStateProvider.select((s) => s.valueOrNull?.userId));
  final auth = ref.read(authSessionControllerProvider);
  return OtpController(
      send: () => auth.sendOtp(email),
      verify: (code) => auth.loginWithOtp(email, code));
});

class OtpController extends StateNotifier<OtpState> {
  OtpController({required this.send, required this.verify})
      : super(const OtpState()) {
    _startCountdown();
  }
  final Future<void> Function() send;
  final Future<void> Function(String) verify;
  Timer? _timer;
  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = state.countdown - 1;
      state = OtpState(
          countdown: next.clamp(0, 60),
          verifying: state.verifying,
          resending: state.resending,
          error: state.error);
      if (next <= 0) _timer?.cancel();
    });
  }

  Future<bool> resend() async {
    if (!mounted || state.verifying || state.resending || state.countdown > 0) {
      return false;
    }
    state = const OtpState(countdown: 0, resending: true);
    try {
      await send();
      if (!mounted) return false;
      state = const OtpState();
      _startCountdown();
      return true;
    } catch (_) {
      if (mounted) {
        state = const OtpState(
            countdown: 0,
            error: 'Không thể gửi lại mã OTP. Vui lòng thử lại sau.');
      }
      return false;
    }
  }

  Future<bool> submit(String code) async {
    if (!mounted ||
        state.verifying ||
        state.resending ||
        !RegExp(r'^\d{6}$').hasMatch(code)) {
      return false;
    }
    state = OtpState(countdown: state.countdown, verifying: true);
    try {
      await verify(code);
      if (!mounted) return true;
      state = OtpState(countdown: state.countdown);
      return true;
    } catch (_) {
      if (mounted) {
        state = OtpState(
            countdown: state.countdown,
            error: 'Mã OTP không đúng hoặc đã hết hạn. Vui lòng thử lại.');
      }
      return false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
