import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import '../../data/models/auth_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/services/google_sign_in_gateway.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';

final authSessionControllerProvider = Provider(AuthSessionController.new);

/// Điều phối phiên ở presentation; repository chỉ trao đổi DTO với server.
class AuthSessionController {
  AuthSessionController(this.ref);
  final Ref ref;
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<AuthResponse> login(LoginRequest request) async {
    final generation = ref.read(authStateProvider.notifier).sessionGeneration;
    return _accept(await _repository.login(request), generation);
  }

  Future<AuthResponse> loginWithOtp(String email, String otp) async {
    final generation = ref.read(authStateProvider.notifier).sessionGeneration;
    return _accept(await _repository.loginWithOtp(email, otp), generation);
  }

  Future<AuthResponse> loginWithGoogleIdToken(String token) async {
    final generation = ref.read(authStateProvider.notifier).sessionGeneration;
    final response = await _repository.loginWithGoogleIdToken(token);
    if (ref.read(authStateProvider.notifier).sessionGeneration != generation) {
      throw StateError('Phiên đăng nhập đã thay đổi.');
    }
    await ref.read(googleIdentityGatewayProvider).clearLocalSelection();
    return _accept(response, generation);
  }

  Future<AuthResponse> register(RegisterRequest request) =>
      _repository.register(request);
  Future<void> sendOtp(String email) => _repository.sendOtp(email);
  Future<void> requestOtp(String email) => sendOtp(email);

  Future<AuthResponse> _accept(AuthResponse response, int generation) async {
    final auth = ref.read(authStateProvider.notifier);
    if (auth.sessionGeneration != generation) {
      throw StateError('Phiên đăng nhập đã thay đổi.');
    }
    await auth.login(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        userId: response.userId,
        phone: response.displayName ?? response.userId);
    if (auth.sessionGeneration != generation + 1 ||
        ref.read(authStateProvider).valueOrNull?.userId != response.userId) {
      throw StateError('Phiên đăng nhập đã thay đổi.');
    }
    ref
        .read(profileStoreProvider.notifier)
        .setFromAuth(name: response.displayName);
    unawaited(ref.read(profileStoreProvider.notifier).fetchProfile());
    return response;
  }

  Future<void> logout() async {
    final auth = ref.read(authStateProvider.notifier);
    final generation = auth.sessionGeneration;
    bool current() => auth.sessionGeneration == generation;
    var token = auth.refreshToken;
    try {
      if (token != null && token.isNotEmpty) {
        try {
          final refreshed = await _repository.refresh(token);
          if (!current()) return;
          if (refreshed.accessToken.isNotEmpty &&
              refreshed.refreshToken.isNotEmpty) {
            await auth.updateTokens(
                accessToken: refreshed.accessToken,
                refreshToken: refreshed.refreshToken);
            token = refreshed.refreshToken;
          }
        } catch (_) {/* Phiên hết hạn vẫn phải được dọn local. */}
      }
      if (current()) await _repository.logout(refreshToken: token);
    } catch (_) {
      /* Server không khả dụng vẫn cho phép đăng xuất local. */
    } finally {
      if (current()) {
        try {
          await ref.read(googleIdentityGatewayProvider).clearLocalSelection();
        } finally {
          if (current()) {
            await auth.logout();
            if (ref.read(authStateProvider).valueOrNull?.isAuthenticated !=
                true) {
              ref.read(profileStoreProvider.notifier).reset();
            }
          }
        }
      }
    }
  }
}
