import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_notifier.dart';
import 'api_constants.dart';

// baseUrl đọc từ --dart-define=BASE_URL=http://localhost:5033/api/v1
// Nếu không truyền → dùng giá trị mặc định trong api_constants.dart
const String _baseUrl = kBaseUrl;

final dioClientProvider = Provider<DioClient>((ref) => DioClient(ref));

class DioClient {
  late final Dio _dio;
  final Ref _ref;

  DioClient(this._ref) {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Accept-Language': 'vi',
      },
    ));
    _dio.interceptors.add(_AuthInterceptor(_ref));
    _dio.interceptors.add(_ErrorInterceptor());
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _dio.get(path, queryParameters: query);

  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  Future<Response<T>> patch<T>(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

  Future<Response<T>> delete<T>(String path) => _dio.delete(path);

  Future<Response<T>> postForm<T>(String path, FormData data) =>
      _dio.post(path, data: data);
}

/// Giữ thông tin một request đang chờ token refresh
class _PendingRequest {
  final RequestOptions options;
  final Completer<Response<dynamic>> _completer = Completer();

  _PendingRequest(this.options);

  Future<Response<dynamic>> get future => _completer.future;
  void complete(Response<dynamic> response) => _completer.complete(response);
  void completeError(Object error) => _completer.completeError(error);
}

class _AuthInterceptor extends Interceptor {
  final Ref _ref;
  bool _isRefreshing = false;
  final List<_PendingRequest> _pendingRequests = [];

  _AuthInterceptor(this._ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _ref.read(authStateProvider).value?.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final path = err.requestOptions.path;
    final isAuthEndpoint =
        path.endsWith('/auth/refresh') || path.endsWith('/auth/logout');

    if (err.response?.statusCode == 401 && !isAuthEndpoint) {
      final authNotifier = _ref.read(authStateProvider.notifier);
      final refreshToken = authNotifier.refreshToken;

      if (refreshToken == null) {
        await authNotifier.logout();
        return handler.next(err);
      }

      // Nếu đang refresh, xếp request này vào hàng chờ
      if (_isRefreshing) {
        final pending = _PendingRequest(err.requestOptions);
        _pendingRequests.add(pending);
        try {
          final response = await pending.future;
          handler.resolve(response);
        } catch (_) {
          handler.next(err);
        }
        return;
      }

      _isRefreshing = true;
      try {
        final dio = Dio(BaseOptions(baseUrl: _baseUrl));
        // BE stateful: chỉ cần refreshToken — userId lấy từ Redis, không cần accessToken
        final resp = await dio
            .post('/auth/refresh', data: {'refreshToken': refreshToken});
        final newAccess = resp.data['accessToken'] as String;
        final newRefresh = resp.data['refreshToken'] as String;

        await authNotifier.updateTokens(
          accessToken: newAccess,
          refreshToken: newRefresh,
        );

        // Retry original request
        err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
        final retried = await dio.fetch(err.requestOptions);

        // Retry toàn bộ pending requests
        for (final pending in _pendingRequests) {
          try {
            pending.options.headers['Authorization'] = 'Bearer $newAccess';
            final retriedPending = await dio.fetch(pending.options);
            pending.complete(retriedPending);
          } catch (e) {
            pending.completeError(e);
          }
        }
        _pendingRequests.clear();

        handler.resolve(retried);
      } catch (_) {
        // Refresh thất bại → reject toàn bộ pending, logout
        for (final pending in _pendingRequests) {
          pending.completeError(err);
        }
        _pendingRequests.clear();
        await authNotifier.logout();
        handler.next(err);
      } finally {
        _isRefreshing = false;
      }
    } else {
      handler.next(err);
    }
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final message = _parseMessage(err);
    handler.next(DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: AppApiException(
          message: message, statusCode: err.response?.statusCode),
    ));
  }

  String _parseMessage(DioException err) {
    try {
      final data = err.response?.data;
      if (data is Map) {
        return data['detail'] as String? ??
            data['title'] as String? ??
            data['message'] as String? ??
            'Đã xảy ra lỗi, vui lòng thử lại.';
      }
    } catch (_) {}
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Kết nối quá chậm, vui lòng kiểm tra mạng.';
      case DioExceptionType.connectionError:
        return 'Không có kết nối internet.';
      default:
        return 'Đã xảy ra lỗi, vui lòng thử lại.';
    }
  }
}

class AppApiException implements Exception {
  final String message;
  final int? statusCode;
  const AppApiException({required this.message, this.statusCode});

  @override
  String toString() => 'AppApiException($statusCode): $message';
}
