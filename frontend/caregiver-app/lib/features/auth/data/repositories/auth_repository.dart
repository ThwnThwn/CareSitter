import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/features/auth/data/models/auth_user_model.dart';

const _requiredRole = 'CAREGIVER';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.read(dioClientProvider)),
);

class AuthRepository {
  final DioClient _dio;

  AuthRepository(this._dio);

  /// Tạo tài khoản dành riêng cho ứng dụng Caregiver.
  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String confirmPassword,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'fullName': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'phone': phone.trim(),
        'password': password,
        'confirmPassword': confirmPassword,
        'roles': const [_requiredRole],
      },
    );
  }

  /// Đăng nhập bằng Email hoặc SĐT + Password → POST /auth/login/password
  Future<AuthUserModel> loginWithPassword(
    String identifier,
    String password,
  ) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/auth/login/password',
      data: {
        'email': identifier,
        'password': password,
        'requiredRole': _requiredRole,
      },
    );
    final user = AuthUserModel.fromJson(
      resp.data ?? {},
      fallbackDisplayName: identifier,
    );
    return user;
  }

  /// Gửi OTP xác thực → POST /auth/send-otp
  Future<void> sendOtp(String identifier) async {
    await _dio.post<dynamic>(
      '/auth/send-otp',
      data: {'email': identifier},
    );
  }

  /// Alias dùng bởi màn hình đăng nhập OTP.
  Future<void> requestOtp(String email) => sendOtp(email);

  /// Đăng nhập bằng OTP → POST /auth/login
  Future<AuthUserModel> loginWithOtp(
    String identifier,
    String otp,
  ) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': identifier,
        'otp': otp,
        'requiredRole': _requiredRole,
      },
    );
    final user = AuthUserModel.fromJson(
      resp.data ?? {},
      fallbackDisplayName: identifier,
    );
    return user;
  }

  Future<AuthUserModel> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>('/auth/refresh',
        data: {'refreshToken': refreshToken});
    return AuthUserModel.fromJson(response.data ?? {}, fallbackDisplayName: '');
  }

  Future<void> logout({String? refreshToken}) async {
    await _dio.post<dynamic>('/auth/logout',
        data: refreshToken == null ? null : {'refreshToken': refreshToken});
  }
}
