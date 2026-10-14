import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/error/failure.dart';
import 'register_controller.dart';
import 'registration_state.dart';

export 'registration_state.dart';

typedef RegistrationWrite = Future<void> Function({
  required String fullName,
  required String email,
  required String phone,
  required String password,
  required String confirmPassword,
});

final registrationControllerProvider =
    StateNotifierProvider.autoDispose<RegistrationController, RegistrationState>(
        (ref) {
  ref.watch(authStateProvider.select(
      (value) => (value.valueOrNull?.userId, value.valueOrNull?.isAuthenticated)));
  return RegistrationController(ref.read(registerControllerProvider).register);
});

class RegistrationController extends StateNotifier<RegistrationState> {
  RegistrationController(this._write) : super(const RegistrationState());
  final RegistrationWrite _write;

  void setAgreement(bool value) {
    if (mounted && !state.busy) state = RegistrationState(agreed: value);
  }

  Future<bool> submit({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
  }) async {
    if (!mounted || state.busy) return false;
    if (!state.agreed) {
      state =
          const RegistrationState(error: 'Vui lòng đồng ý với điều khoản sử dụng.');
      return false;
    }
    state = const RegistrationState(busy: true, agreed: true);
    try {
      await _write(
          fullName: fullName,
          email: email,
          phone: phone,
          password: password,
          confirmPassword: confirmPassword);
      if (!mounted) return false;
      state = const RegistrationState(agreed: true);
      return true;
    } catch (error) {
      if (mounted) {
        state = RegistrationState(agreed: true, error: apiErrorMessage(error));
      }
      return false;
    }
  }
}
