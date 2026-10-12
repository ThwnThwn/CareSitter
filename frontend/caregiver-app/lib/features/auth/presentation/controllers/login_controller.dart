import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/features/auth/presentation/controllers/auth_session_controller.dart';

final loginControllerProvider = Provider<LoginController>((ref) {
  return LoginController(ref.read(authSessionControllerProvider));
});

class LoginController {
  final AuthSessionController _repository;

  const LoginController(this._repository);

  Future<void> loginWithPassword(String identifier, String password) async {
    await _repository.loginWithPassword(identifier.trim(), password);
  }

  Future<void> requestOtp(String email) async {
    await _repository.requestOtp(email.trim().toLowerCase());
  }

  Future<void> logout() => _repository.logout();
}
