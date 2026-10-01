import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/api/api_constants.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/profile_controller.dart';
import 'package:caresitter_customer/features/auth/data/models/auth_models.dart';
import 'package:caresitter_customer/features/auth/data/services/google_sign_in_gateway.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.read(dioClientProvider), ref),
);

class AuthRepository {
  final DioClient _dio;
  final Ref _ref;

  AuthRepository(this._dio, this._ref);

  // ── Đăng nhập bằng Email + Password → POST /auth/login/password ────────────
  Future<AuthResponse> loginWithPassword(LoginRequest request) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/auth/login/password',
      data: request.toJson(),
    );
    return _saveAndReturn(AuthResponse.fromJson(resp.data ?? {}));
  }

  /// Alias để tương thích với login_screen.dart đang gọi `.login(...)`
  Future<AuthResponse> login(LoginRequest request) =>
      loginWithPassword(request);

  // ── Google ID Token → CareSitter JWT + refresh token ─────────────────────
  Future<AuthResponse> loginWithGoogleIdToken(String idToken) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiPaths.googleCustomer,
      data: {'idToken': idToken},
    );
    final authResponse = AuthResponse.fromJson(resp.data ?? {});
    await _ref.read(googleIdentityGatewayProvider).clearLocalSelection();
    return _saveAndReturn(authResponse);
  }

  // ── Đăng ký tài khoản mới → POST /auth/register ───────────────────────────
  Future<AuthResponse> register(RegisterRequest request) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiPaths.register,
      data: request.toJson(),
    );
    // Không tự động đăng nhập, trả về AuthResponse để giao diện chuyển về /auth/login
    return AuthResponse.fromJson(resp.data ?? {});
  }

  // ── Gửi OTP tới email → POST /auth/send-otp ───────────────────────────────
  Future<void> sendOtp(String email) async {
    await _dio.post<dynamic>(
      '/auth/send-otp',
      data: OtpSendRequest(email: email).toJson(),
    );
  }

  /// Alias tương thích
  Future<void> requestOtp(String email) => sendOtp(email);

  // ── Đăng nhập bằng OTP → POST /auth/login ────────────────────────────────
  Future<AuthResponse> loginWithOtp(String email, String otp) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      ApiPaths.login,
      data: OtpVerifyRequest(email: email, otp: otp).toJson(),
    );
    return _saveAndReturn(AuthResponse.fromJson(resp.data ?? {}));
  }

  // ── Đăng xuất ─────────────────────────────────────────────────────────────
  Future<void> logout() async {
    final authNotifier = _ref.read(authStateProvider.notifier);
    var refreshToken = authNotifier.refreshToken;
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          final refreshResp = await _dio.post<Map<String, dynamic>>(
            '/auth/refresh',
            data: {'refreshToken': refreshToken},
          );
          final refreshed = AuthResponse.fromJson(refreshResp.data ?? {});
          if (refreshed.accessToken.isNotEmpty &&
              refreshed.refreshToken.isNotEmpty) {
            await authNotifier.updateTokens(
              accessToken: refreshed.accessToken,
              refreshToken: refreshed.refreshToken,
            );
            refreshToken = refreshed.refreshToken;
          }
        } catch (_) {
          // Refresh token đã invalid/expired thì chỉ cần xóa local session.
        }
      }

      // Gửi refreshToken mới nhất để server revoke session trong PostgreSQL.
      await _dio.post<dynamic>(
        '/auth/logout',
        data: refreshToken != null ? {'refreshToken': refreshToken} : null,
      );
    } catch (_) {
      // Vẫn xóa local token dù server lỗi
    } finally {
      await _ref.read(googleIdentityGatewayProvider).clearLocalSelection();
      await authNotifier.logout();
      _ref.read(profileStoreProvider.notifier).reset();
    }
  }

  // ── Private helper ────────────────────────────────────────────────────────
  Future<AuthResponse> _saveAndReturn(AuthResponse authResp) async {
    await _ref.read(authStateProvider.notifier).login(
          accessToken: authResp.accessToken,
          refreshToken: authResp.refreshToken,
          userId: authResp.userId,
          phone: authResp.displayName ?? authResp.userId,
        );
    _ref.read(profileStoreProvider.notifier).setFromAuth(
          name: authResp.displayName,
        );
    unawaited(_ref.read(profileStoreProvider.notifier).fetchProfile());
    return authResp;
  }
}
