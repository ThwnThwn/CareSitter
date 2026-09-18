import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/features/auth/data/repositories/auth_repository.dart';

final otpVerifyControllerProvider = Provider<OtpVerifyController>((ref) {
  return OtpVerifyController(ref.read(authRepositoryProvider));
});

class OtpVerifyController {
  final AuthRepository _repository;

  const OtpVerifyController(this._repository);

  Future<void> verify(String email, String otp) async {
    await _repository.loginWithOtp(email.trim().toLowerCase(), otp.trim());
  }

  Future<void> resend(String email) async {
    await _repository.requestOtp(email.trim().toLowerCase());
  }
}
