import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/app_exception.dart';
import 'api_constants.dart';

Map<String, String> tunnelHeaders(String baseUrl) {
  final host = Uri.tryParse(baseUrl)?.host.toLowerCase() ?? '';
  if (host.endsWith('.ngrok-free.app') ||
      host.endsWith('.ngrok-free.dev') ||
      host.endsWith('.ngrok.app')) {
    return const {'ngrok-skip-browser-warning': '1'};
  }
  return const {};
}

// No auth interceptor: validation must not wait on the session it is restoring.
final authRefreshClientProvider = Provider<Dio>((ref) {
  final client = Dio(BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: tunnelHeaders(kBaseUrl)));
  ref.onDispose(() => client.close(force: true));
  return client;
});

final authSessionApiProvider = Provider<AuthSessionApi>(
    (ref) => AuthSessionApi(ref.read(authRefreshClientProvider)));

class AuthSessionApi {
  AuthSessionApi(this._client);
  final Dio _client;

  /// Null means the server rejected the session; transient failures are errors.
  Future<({String accessToken, String? refreshToken})?> restore(
      String accessToken, String? refreshToken) async {
    try {
      await _client.get<void>('/auth/session',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}));
      return (accessToken: accessToken, refreshToken: refreshToken);
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) throw _unavailable(error);
    }
    if (refreshToken == null || refreshToken.trim().isEmpty) return null;
    try {
      final response = await _client.post<Map<String, dynamic>>('/auth/refresh',
          data: {'refreshToken': refreshToken});
      final access = response.data?['accessToken'];
      final refresh = response.data?['refreshToken'];
      if (access is! String ||
          refresh is! String ||
          access.trim().isEmpty ||
          refresh.trim().isEmpty) {
        throw const AppApiException(message: _retryMessage);
      }
      return (accessToken: access, refreshToken: refresh);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      if (status == 400 ||
          status == 401 ||
          status == 403 ||
          (status == 404 &&
              data is Map &&
              data['code'] == 'auth.user_not_found')) {
        return null;
      }
      throw _unavailable(error);
    }
  }

  static const _retryMessage =
      'Chưa kiểm tra được phiên đăng nhập. Vui lòng kiểm tra kết nối và thử lại.';

  AppApiException _unavailable(DioException error) => AppApiException(
      message: _retryMessage, statusCode: error.response?.statusCode);
}
