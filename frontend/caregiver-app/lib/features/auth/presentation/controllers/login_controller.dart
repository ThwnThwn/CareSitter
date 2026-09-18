import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/features/auth/data/repositories/auth_repository.dart';

final loginControllerProvider = Provider<LoginController>((ref) {
  return LoginController(ref.read(authRepositoryProvider));
});

class LoginController {
  final AuthRepository _repository;

  const LoginController(this._repository);

  Future<void> loginWithPassword(String identifier, String password) async {
    await _repository.loginWithPassword(identifier.trim(), password);
  }

  Future<void> requestOtp(String email) async {
    await _repository.requestOtp(email.trim().toLowerCase());
  }

  Future<void> logout() => _repository.logout();
}
