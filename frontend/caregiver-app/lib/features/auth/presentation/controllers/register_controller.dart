import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caregiver_app/features/auth/data/repositories/auth_repository.dart';

final registerControllerProvider = Provider<RegisterController>((ref) {
  return RegisterController(ref.read(authRepositoryProvider));
});

class RegisterController {
  final AuthRepository _repository;

  const RegisterController(this._repository);

  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
  }) {
    return _repository.register(
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
      confirmPassword: confirmPassword,
    );
  }
}
