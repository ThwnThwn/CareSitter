import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import '../data/mappers/auth_error_mapper.dart';

final loginControllerProvider =
    AutoDisposeNotifierProvider<LoginController, LoginState>(
  LoginController.new,
);

class LoginState {
  const LoginState({
    this.isLoading = false,
    this.errorMessage,
  });

  final bool isLoading;
  final String? errorMessage;
}

class LoginController extends AutoDisposeNotifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  void clearError() {
    if (state.errorMessage == null) return;
    state = LoginState(isLoading: state.isLoading);
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    if (state.isLoading) return false;

    state = const LoginState(isLoading: true);
    try {
      await ref.read(authRepositoryProvider).login(
            LoginRequest(
              email: email.trim(),
              password: password,
            ),
          );
      state = const LoginState();
      return true;
    } catch (error) {
      state = LoginState(errorMessage: AuthErrorMapper.login(error));
      return false;
    }
  }
}
