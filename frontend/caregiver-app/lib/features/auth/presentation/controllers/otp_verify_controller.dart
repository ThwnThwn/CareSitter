import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/features/auth/presentation/controllers/auth_session_controller.dart';

final otpVerifyControllerProvider = Provider<OtpVerifyController>((ref) {
  return OtpVerifyController(ref.read(authSessionControllerProvider));
});

class OtpVerifyController {
  final AuthSessionController _repository;

  const OtpVerifyController(this._repository);

  Future<void> verify(String email, String otp) async {
    await _repository.loginWithOtp(email.trim().toLowerCase(), otp.trim());
  }

  Future<void> resend(String email) async {
    await _repository.requestOtp(email.trim().toLowerCase());
  }
}
