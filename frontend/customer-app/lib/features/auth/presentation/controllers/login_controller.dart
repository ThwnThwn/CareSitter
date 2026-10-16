import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caresitter_customer/core/utils/phone_formatter.dart';
import 'package:caresitter_customer/features/auth/data/services/google_sign_in_gateway.dart';
import 'package:caresitter_customer/features/auth/data/models/auth_models.dart';
import 'package:caresitter_customer/features/auth/presentation/controllers/auth_session_controller.dart';
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
  bool _disposed = false;

  @override
  LoginState build() {
    _disposed = false;
    final googleIdentity = ref.read(googleIdentityGatewayProvider);
    _googleCredentialSubscription = googleIdentity.credentials.listen(
      _handleGoogleCredential,
      onError: _handleGoogleStreamError,
    );
    ref.onDispose(() {
      _disposed = true;
      _googleCredentialSubscription?.cancel();
    });
    return const LoginState();
  }

  void clearError() {
    if (state.errorMessage == null) return;
    state = LoginState(isLoading: state.isLoading);
  }

  Future<bool> login({
    required String email,
    required String password,
    bool rememberSession = true,
  }) async {
    if (state.isLoading) return false;

    state = const LoginState(isLoading: true);
    try {
      final identifier = email.trim();
      final normalizedIdentifier =
          identifier.contains('@') ? identifier : normalizePhone(identifier);
      await ref.read(authSessionControllerProvider).login(
            LoginRequest(
              email: normalizedIdentifier,
              password: password,
            ),
            rememberSession: rememberSession,
          );
      if (_disposed) return false;
      state = const LoginState();
      return true;
    } catch (error) {
      if (_disposed) return false;
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
      if (_disposed) return;
      state = LoginState(errorMessage: AuthErrorMapper.google(error));
    }
  }

  Future<void> _handleGoogleCredential(
    GoogleIdentityCredential credential,
  ) async {
    if (_disposed || _handlingGoogleCredential) return;
    _handlingGoogleCredential = true;
    state = const LoginState(isLoading: true);

    try {
      await ref
          .read(authSessionControllerProvider)
          .loginWithGoogleIdToken(credential.idToken);
      if (_disposed) return;
      state = const LoginState();
    } catch (error) {
      if (_disposed) return;
      state = LoginState(errorMessage: AuthErrorMapper.google(error));
    } finally {
      _handlingGoogleCredential = false;
    }
  }

  void _handleGoogleStreamError(Object error, StackTrace stackTrace) {
    if (_disposed) return;
    state = LoginState(errorMessage: AuthErrorMapper.google(error));
  }
}
