import 'package:dio/dio.dart';

import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/auth/domain/google_identity_gateway.dart';

class AuthErrorMapper {
  const AuthErrorMapper._();
  static String registration(Object error) {
    final api = _apiException(error);
    if (api?.statusCode == 409) {
      return 'Email hoặc số điện thoại đã được đăng ký';
    }
    if (api?.isTransportFailure == true) return 'Không có kết nối internet';
    if (api != null && api.message.trim().isNotEmpty) return api.message;
    return 'Đăng ký thất bại, vui lòng thử lại';
  }

  static String login(Object error) {
    final apiError = _apiException(error);
    final statusCode = apiError?.statusCode ?? _statusCode(error);
    final message = (apiError?.message ?? error.toString()).trim();
    final normalized = message.toLowerCase();

    if (statusCode == 401 || normalized.contains('invalid')) {
      return 'Email hoặc mật khẩu không đúng';
    }
    if (statusCode == 404) return 'Tài khoản không tồn tại';
    if (_isConnectionError(error, normalized)) {
      return 'Không có kết nối internet';
    }
    if (apiError != null && message.isNotEmpty) return message;

    return 'Đăng nhập thất bại, vui lòng thử lại';
  }

  static String? google(Object error) {
    if (error is GoogleIdentityException) {
      return switch (error.code) {
        GoogleIdentityFailureCode.cancelled => null,
        GoogleIdentityFailureCode.configuration =>
          'Google Sign-In chưa được cấu hình đúng. Vui lòng liên hệ quản trị viên.',
        GoogleIdentityFailureCode.missingIdToken =>
          'Google không trả về thông tin xác thực. Vui lòng thử lại.',
        GoogleIdentityFailureCode.unsupportedPlatform => error.message,
        GoogleIdentityFailureCode.unknown =>
          'Không thể đăng nhập bằng Google. Vui lòng thử lại.',
      };
    }

    final apiError = _apiException(error);
    final normalized = (apiError?.message ?? error.toString()).toLowerCase();
    if (_isConnectionError(error, normalized)) {
      return 'Không có kết nối internet';
    }
    if (apiError?.code == 'auth.invalid_google_token' ||
        normalized.contains('google') && normalized.contains('token')) {
      return 'Phiên xác thực Google không hợp lệ hoặc đã hết hạn.';
    }
    if (apiError != null && apiError.message.trim().isNotEmpty) {
      return apiError.message.trim();
    }
    return 'Không thể đăng nhập bằng Google. Vui lòng thử lại.';
  }

  static AppApiException? _apiException(Object error) {
    if (error is AppApiException) return error;
    if (error is DioException && error.error is AppApiException) {
      return error.error! as AppApiException;
    }
    return null;
  }

  static int? _statusCode(Object error) {
    if (error is DioException) return error.response?.statusCode;
    return null;
  }

  static bool _isConnectionError(Object error, String normalizedMessage) {
    if (error is DioException &&
        (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.receiveTimeout)) {
      return true;
    }
    return normalizedMessage.contains('internet') ||
        normalizedMessage.contains('connect') ||
        normalizedMessage.contains('kết nối');
  }
}
