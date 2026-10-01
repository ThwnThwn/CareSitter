import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/features/auth/data/services/google_sign_in_gateway.dart';
import 'package:caresitter_customer/features/auth/data/models/auth_models.dart';
import 'package:caresitter_customer/features/auth/data/repositories/auth_repository.dart';
import 'package:caresitter_customer/features/auth/data/mappers/auth_error_mapper.dart';
import 'package:caresitter_customer/features/auth/domain/google_identity_gateway.dart';

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
  StreamSubscription<GoogleIdentityCredential>? _googleCredentialSubscription;
  bool _handlingGoogleCredential = false;

  @override
  LoginState build() {
    final googleIdentity = ref.read(googleIdentityGatewayProvider);
    _googleCredentialSubscription = googleIdentity.credentials.listen(
      _handleGoogleCredential,
      onError: _handleGoogleStreamError,
    );
    ref.onDispose(() => _googleCredentialSubscription?.cancel());
    return const LoginState();
  }

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

  Future<void> loginWithGoogle() async {
    if (state.isLoading) return;

    state = const LoginState(isLoading: true);
    try {
      await ref.read(googleIdentityGatewayProvider).authenticate();
    } catch (error) {
      state = LoginState(errorMessage: AuthErrorMapper.google(error));
    }
  }

  Future<void> _handleGoogleCredential(
    GoogleIdentityCredential credential,
  ) async {
    if (_handlingGoogleCredential) return;
    _handlingGoogleCredential = true;
    state = const LoginState(isLoading: true);

    try {
      await ref
          .read(authRepositoryProvider)
          .loginWithGoogleIdToken(credential.idToken);
      state = const LoginState();
    } catch (error) {
      state = LoginState(errorMessage: AuthErrorMapper.google(error));
    } finally {
      _handlingGoogleCredential = false;
    }
  }

  void _handleGoogleStreamError(Object error, StackTrace stackTrace) {
    state = LoginState(errorMessage: AuthErrorMapper.google(error));
  }
}
