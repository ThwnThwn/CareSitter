import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import '../../data/models/auth_models.dart';
import '../../data/mappers/auth_error_mapper.dart';
import 'auth_session_controller.dart';
import 'registration_state.dart';
export 'registration_state.dart';

final registrationControllerProvider = StateNotifierProvider.autoDispose<
    RegistrationController, RegistrationState>((ref) {
  ref.watch(authStateProvider.select((s) => s.valueOrNull?.userId));
  return RegistrationController(
      ref.read(authSessionControllerProvider).register);
});

class RegistrationController extends StateNotifier<RegistrationState> {
  RegistrationController(this.register) : super(const RegistrationState());
  final Future<void> Function(RegisterRequest) register;
  void setAgreement(bool agreed) {
    if (!state.busy) state = RegistrationState(agreed: agreed);
  }

  Future<bool> submit(RegisterRequest request) async {
    if (!mounted || state.busy) return false;
    if (!state.agreed) {
      state = const RegistrationState(
          error: 'Vui lòng đồng ý với điều khoản sử dụng');
      return false;
    }
    state = const RegistrationState(busy: true, agreed: true);
    try {
      await register(request);
      if (!mounted) return false;
      state = const RegistrationState(agreed: true);
      return true;
    } catch (error) {
      if (mounted) {
        state = RegistrationState(
            agreed: true, error: AuthErrorMapper.registration(error));
      }
      return false;
    }
  }
}
