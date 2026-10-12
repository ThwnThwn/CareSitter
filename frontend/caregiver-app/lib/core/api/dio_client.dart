import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/config/env_config.dart';
import 'package:caregiver_app/core/error/app_exception.dart';

const String _baseUrl = EnvConfig.baseUrl;

final dioClientProvider = Provider<DioClient>((ref) => DioClient(ref));

class DioClient {
  late final Dio _dio;
  final Ref _ref;

  DioClient(this._ref, {HttpClientAdapter? adapter}) {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        // Dio tự chọn application/json hoặc multipart/form-data theo body.
        // Không set cứng Content-Type để upload FormData hoạt động đúng.
        'Accept': 'application/json',
        'Accept-Language': 'vi',
      },
    ));
    if (adapter != null) _dio.httpClientAdapter = adapter;
    _dio.interceptors.add(_AuthInterceptor(_ref));
    _dio.interceptors.add(_ErrorInterceptor());
  }

  Future<Response<T>> get<T>(String path,
          {Map<String, dynamic>? query, CancelToken? cancelToken}) =>
      _request(() =>
          _dio.get<T>(path, queryParameters: query, cancelToken: cancelToken));

  Future<Response<T>> post<T>(String path,
          {dynamic data, CancelToken? cancelToken}) =>
      _request(() => _dio.post<T>(path, data: data, cancelToken: cancelToken));

  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _request(() => _dio.put<T>(path, data: data));

  Future<Response<T>> patch<T>(String path, {dynamic data}) =>
      _request(() => _dio.patch<T>(path, data: data));

  Future<Response<T>> delete<T>(String path) =>
      _request(() => _dio.delete<T>(path));

  Future<Response<T>> postForm<T>(String path, FormData data,
          {CancelToken? cancelToken}) =>
      _request(() => _dio.post<T>(path, data: data, cancelToken: cancelToken));
  Future<Response<T>> _request<T>(Future<Response<T>> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      final wrapped = error.error;
      final data = error.response?.data;
      throw AppApiException(
        message: wrapped is AppApiException
            ? wrapped.message
            : 'Chưa kết nối được máy chủ. Vui lòng thử lại.',
        statusCode: error.response?.statusCode,
        code: wrapped is AppApiException
            ? wrapped.code
            : data is Map
                ? (data['code'] ?? data['title'])?.toString()
                : null,
        details: wrapped is AppApiException
            ? wrapped.details
            : data is Map
                ? Map<String, dynamic>.from(data)
                : null,
        isCancelled: error.type == DioExceptionType.cancel,
        retryAfterSeconds:
            int.tryParse(error.response?.headers.value('retry-after') ?? ''),
      );
    }
  }
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
        // Chỉ cần refreshToken; backend tra session DB, không cần accessToken.
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
    if (err.error is AppApiException) {
      handler.next(err);
      return;
    }
    final message = _parseMessage(err);
    handler.next(DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: AppApiException(
          message: message,
          statusCode: err.response?.statusCode,
          code: err.response?.data is Map
              ? (err.response?.data['code'] ?? err.response?.data['title'])
                  ?.toString()
              : null,
          details: err.response?.data is Map
              ? Map<String, dynamic>.from(err.response?.data)
              : null),
    ));
  }

  String _parseMessage(DioException err) {
    final data = err.response?.data;
    if (data is Map) {
      for (final key in const ['detail', 'message', 'error', 'title']) {
        final value = data[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
      final errors = data['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is Iterable && value.isNotEmpty) {
            final message = value.first.toString().trim();
            if (message.isNotEmpty) return message;
          }
          final message = value?.toString().trim();
          if (message != null && message.isNotEmpty) return message;
        }
      }
    }
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Kết nối quá chậm, vui lòng kiểm tra mạng.';
      case DioExceptionType.connectionError:
        return 'Không thể kết nối máy chủ. Vui lòng kiểm tra backend và thử lại.';
      default:
        return _messageForStatus(err.response?.statusCode);
    }
  }

  String _messageForStatus(int? statusCode) => switch (statusCode ?? 0) {
        400 || 422 => 'Dữ liệu chưa hợp lệ. Vui lòng kiểm tra lại.',
        401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        403 => 'Bạn không có quyền thực hiện thao tác này.',
        404 => 'Không tìm thấy dữ liệu yêu cầu.',
        409 => 'Dữ liệu đã thay đổi. Vui lòng tải lại và thử lại.',
        413 => 'Tệp tải lên vượt quá dung lượng cho phép.',
        429 => 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.',
        >= 500 => 'Hệ thống đang gặp sự cố. Vui lòng thử lại sau.',
        _ => 'Đã xảy ra lỗi, vui lòng thử lại.',
      };
}
