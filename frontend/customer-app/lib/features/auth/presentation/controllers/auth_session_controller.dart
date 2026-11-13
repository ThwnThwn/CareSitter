import 'package:caresitter_customer/core/analytics/app_analytics.dart';
import '../../data/services/firebase_identity_bridge.dart';
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
  int _attempt = 0;
  bool _googleBusy = false;
  bool _loggingOut = false;
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<AuthResponse> login(
    LoginRequest request, {
    bool rememberSession = true,
  }) async {
    if (_loggingOut) throw StateError('Đang đăng xuất.');
    final attempt = ++_attempt;
    final generation = ref.read(authStateProvider.notifier).sessionGeneration;
    return _accept(
      await _repository.login(request),
      generation,
      rememberSession: rememberSession,
      expectedAttempt: attempt,
    );
  }

  Future<AuthResponse> loginWithOtp(String email, String otp) async {
    if (_loggingOut) throw StateError('Đang đăng xuất.');
    final attempt = ++_attempt;
    final generation = ref.read(authStateProvider.notifier).sessionGeneration;
    return _accept(await _repository.loginWithOtp(email, otp), generation,
        method: 'otp', expectedAttempt: attempt);
  }

  Future<AuthResponse> loginWithGoogleIdToken(String token) async {
    if (_loggingOut) throw StateError('Đang đăng xuất.');
    if (_googleBusy) throw StateError('Đang đăng nhập Google.');
    _googleBusy = true;
    final attempt = ++_attempt;
    final auth = ref.read(authStateProvider.notifier);
    final generation = auth.sessionGeneration;
    final bridge = ref.read(firebaseIdentityBridgeProvider);
    AuthResponse? response;
    bool current() =>
        attempt == _attempt && auth.sessionGeneration == generation;
    try {
      final firebaseToken = await bridge.exchangeGoogleToken(token);
      if (!current()) throw StateError('Phiên đăng nhập đã thay đổi.');
      response = firebaseToken == null
          ? await _repository.loginWithGoogleIdToken(token)
          : await _repository.loginWithFirebaseGoogleToken(firebaseToken);
      if (!current()) throw StateError('Phiên đăng nhập đã thay đổi.');
      if (firebaseToken != null) await bridge.bindOwner(response.userId);
      if (!current()) throw StateError('Phiên đăng nhập đã thay đổi.');
      final accepted = await _accept(response, generation,
          method: 'google', expectedAttempt: attempt);
      await ref.read(googleIdentityGatewayProvider).clearLocalSelection();
      return accepted;
    } catch (error) {
      if (response != null) {
        try {
          await _repository.revokeDetachedSession(response);
        } catch (_) {}
      }
      await bridge.signOut();
      rethrow;
    } finally {
      _googleBusy = false;
    }
  }

  Future<AuthResponse> register(RegisterRequest request) =>
      _repository.register(request);
  Future<void> sendOtp(String email) => _repository.sendOtp(email);
  Future<void> requestOtp(String email) => sendOtp(email);

  Future<AuthResponse> _accept(
    AuthResponse response,
    int generation, {
    bool rememberSession = true,
    String method = 'password',
    int? expectedAttempt,
  }) async {
    final auth = ref.read(authStateProvider.notifier);
    if (auth.sessionGeneration != generation ||
        (expectedAttempt != null && expectedAttempt != _attempt)) {
      throw StateError('Phiên đăng nhập đã thay đổi.');
    }
    await auth.login(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        userId: response.userId,
        phone: response.displayName ?? response.userId,
        rememberSession: rememberSession);
    if ((expectedAttempt != null && expectedAttempt != _attempt) ||
        auth.sessionGeneration != generation + 1 ||
        ref.read(authStateProvider).valueOrNull?.userId != response.userId) {
      throw StateError('Phiên đăng nhập đã thay đổi.');
    }
    ref
        .read(profileStoreProvider.notifier)
        .setFromAuth(name: response.displayName);
    unawaited(ref.read(profileStoreProvider.notifier).fetchProfile());
    final analytics = ref.read(appAnalyticsProvider);
    analytics.identify(response.userId);
    analytics
        .log(AnalyticsEvent.login, {'method': method, 'app_role': 'customer'});
    return response;
  }

  Future<void> logout() async {
    if (_loggingOut) return;
    _loggingOut = true;
    _attempt++;
    final analytics = ref.read(appAnalyticsProvider);
    if (ref.read(authStateProvider).valueOrNull?.isAuthenticated == true) {
      analytics.log(
          AnalyticsEvent.logout, {'method': 'user', 'app_role': 'customer'});
    }
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
      try {
        if (current()) {
          try {
            await ref.read(firebaseIdentityBridgeProvider).signOut();
            await ref.read(googleIdentityGatewayProvider).clearLocalSelection();
          } finally {
            if (current()) {
              await auth.logout();
              analytics.identify(null);
              if (ref.read(authStateProvider).valueOrNull?.isAuthenticated !=
                  true) {
                ref.read(profileStoreProvider.notifier).reset();
              }
            }
          }
        }
      } finally {
        _loggingOut = false;
      }
    }
  }
}
