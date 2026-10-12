import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/api/api_constants.dart';
import 'package:caresitter_customer/features/auth/data/models/auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.read(dioClientProvider)),
);

class AuthRepository {
  final DioClient _dio;

  AuthRepository(this._dio);

  // ── Đăng nhập bằng Email + Password → POST /auth/login/password ────────────
  Future<AuthResponse> loginWithPassword(LoginRequest request) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/auth/login/password',
      data: request.toJson(),
    );
    return AuthResponse.fromJson(resp.data ?? {});
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
    return AuthResponse.fromJson(resp.data ?? {});
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
    return AuthResponse.fromJson(resp.data ?? {});
  }

  Future<AuthResponse> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>('/auth/refresh',
        data: {'refreshToken': refreshToken});
    return AuthResponse.fromJson(response.data ?? {});
  }

  Future<void> logout({String? refreshToken}) async {
    await _dio.post<dynamic>('/auth/logout',
        data: refreshToken == null ? null : {'refreshToken': refreshToken});
  }
}
