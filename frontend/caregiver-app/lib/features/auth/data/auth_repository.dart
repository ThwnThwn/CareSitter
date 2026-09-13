import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/dio_client.dart';
import '../../../core/auth/auth_notifier.dart';

const _requiredRole = 'CAREGIVER';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.read(dioClientProvider), ref),
);

class AuthRepository {
  final DioClient _dio;
  final Ref _ref;

  AuthRepository(this._dio, this._ref);

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
  Future<Map<String, dynamic>> loginWithPassword(
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
    final data = resp.data ?? {};
    await _saveAuthData(data, identifier);
    return data;
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
  Future<Map<String, dynamic>> loginWithOtp(
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
    final data = resp.data ?? {};
    await _saveAuthData(data, identifier);
    return data;
  }

  /// Đăng xuất → POST /auth/logout để revoke refresh session trong PostgreSQL.
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
          final data = refreshResp.data ?? {};
          final newAccess = data['accessToken'] as String? ?? '';
          final newRefresh = data['refreshToken'] as String? ?? '';
          if (newAccess.isNotEmpty && newRefresh.isNotEmpty) {
            await authNotifier.updateTokens(
              accessToken: newAccess,
              refreshToken: newRefresh,
            );
            refreshToken = newRefresh;
          }
        } catch (_) {
          // Refresh token đã invalid/expired thì chỉ cần xóa local session.
        }
      }

      await _dio.post<dynamic>(
        '/auth/logout',
        data: refreshToken != null ? {'refreshToken': refreshToken} : null,
      );
    } catch (_) {
      // Vẫn xóa token local dù server lỗi
    } finally {
      await authNotifier.logout();
    }
  }

  Future<void> _saveAuthData(
    Map<String, dynamic> data,
    String fallbackPhone,
  ) async {
    final accessToken = data['accessToken'] as String? ?? '';
    final refreshToken = data['refreshToken'] as String? ?? '';
    final userId = data['userId'] as String? ?? '';
    final displayName = data['displayName'] as String? ?? fallbackPhone;
    final roles = _parseRoles(data['roles'] ?? data['Roles']);

    if (!roles.contains(_requiredRole)) {
      throw Exception(
        'Tài khoản này không có quyền đăng nhập ứng dụng Caregiver.',
      );
    }

    await _ref.read(authStateProvider.notifier).login(
          accessToken: accessToken,
          refreshToken: refreshToken,
          userId: userId,
          phone: displayName,
          roles: roles,
        );
  }

  List<String> _parseRoles(Object? rawRoles) {
    if (rawRoles is List) {
      return rawRoles
          .map((role) => role.toString().trim().toUpperCase())
          .where((role) => role.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }
}
