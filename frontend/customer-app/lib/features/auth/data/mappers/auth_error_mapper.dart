import 'package:dio/dio.dart';

import 'package:caresitter_customer/core/api/dio_client.dart';

class AuthErrorMapper {
  const AuthErrorMapper._();

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
