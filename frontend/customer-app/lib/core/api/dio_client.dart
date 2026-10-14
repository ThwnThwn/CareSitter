import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/api/api_constants.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';

export 'package:caresitter_customer/core/error/app_exception.dart';

// baseUrl đọc từ --dart-define=BASE_URL=http://localhost:5033/api/v1
// Nếu không truyền → dùng giá trị mặc định trong api_constants.dart
const String _baseUrl = kBaseUrl;

final dioClientProvider = Provider<DioClient>((ref) => DioClient(ref));
final authRefreshClientProvider = Provider<Dio>((ref) {
  final client = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30)));
  ref.onDispose(() => client.close(force: true));
  return client;
});
final _authInterceptorProvider = Provider<_AuthInterceptor>(_AuthInterceptor.new);

class DioClient {
  late final Dio _dio;
  final Ref _ref;

  DioClient(this._ref, {String? baseUrl, HttpClientAdapter? adapter}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        // Không set Content-Type cứng ở đây!
        // Dio tự set 'application/json' cho Map/String body,
        // và 'multipart/form-data' cho FormData.
        'Accept': 'application/json',
        'Accept-Language': 'vi',
      },
    ));
    if (adapter != null) _dio.httpClientAdapter = adapter;
    _dio.interceptors.add(_ref.read(_authInterceptorProvider));
    _dio.interceptors.add(_ErrorInterceptor());
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _request(() => _dio.get<T>(path, queryParameters: query));

  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _request(() => _dio.post<T>(path, data: data));

  Future<Response<T>> postIdempotent<T>(String path,
          {dynamic data, required String idempotencyKey}) =>
      _request(() => _dio.post<T>(path,
          data: data,
          options: Options(headers: {'Idempotency-Key': idempotencyKey})));

  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _request(() => _dio.put<T>(path, data: data));

  Future<Response<T>> patch<T>(String path, {dynamic data}) =>
      _request(() => _dio.patch<T>(path, data: data));

  Future<Response<T>> getCancelable<T>(String path,
          {Map<String, dynamic>? query, required CancelToken cancelToken}) =>
      _request(
          () => _dio.get<T>(path, queryParameters: query, cancelToken: cancelToken));
  Future<Response<T>> postCancelable<T>(String path,
          {dynamic data, required CancelToken cancelToken}) =>
      _request(() => _dio.post<T>(path, data: data, cancelToken: cancelToken));
  Future<Response<T>> patchCancelable<T>(String path,
          {dynamic data, required CancelToken cancelToken}) =>
      _request(() => _dio.patch<T>(path, data: data, cancelToken: cancelToken));
  Future<Response<T>> putCancelable<T>(String path,
          {dynamic data, required CancelToken cancelToken}) =>
      _request(() => _dio.put<T>(path, data: data, cancelToken: cancelToken));
  Future<Response<T>> deleteCancelable<T>(String path,
          {required CancelToken cancelToken}) =>
      _request(() => _dio.delete<T>(path, cancelToken: cancelToken));

  Future<Response<T>> delete<T>(String path) => _request(() => _dio.delete<T>(path));

  Future<Response<T>> postForm<T>(String path, FormData data) =>
      _request(() => _dio.post<T>(path, data: data));
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

class _AuthInterceptor extends Interceptor {
  final Ref _ref;
  Future<String?>? _refreshing;
  int _epoch = 0, _refreshEpoch = -1;
  bool _active = true;
  _AuthInterceptor(this._ref) {
    _ref.onDispose(() => _active = false);
    _ref.listen(authStateProvider, (previous, next) {
      if (previous?.valueOrNull?.userId != next.valueOrNull?.userId ||
          previous?.valueOrNull?.isAuthenticated !=
              next.valueOrNull?.isAuthenticated) {
        _epoch++;
      }
    });
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _ref.read(authStateProvider).valueOrNull?.accessToken;
    options.extra['authSessionEpoch'] = _epoch;
    options.extra['authSessionGeneration'] =
        _ref.read(authStateProvider.notifier).sessionGeneration;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final path = err.requestOptions.path;
    final isAuthEndpoint =
        path.endsWith('/auth/refresh') || path.endsWith('/auth/logout');
    if (!_active) return handler.next(err);

    final notifier = _ref.read(authStateProvider.notifier);
    final epoch = err.requestOptions.extra['authSessionEpoch'];
    final generation = err.requestOptions.extra['authSessionGeneration'];
    bool current() =>
        _active &&
        epoch == _epoch &&
        generation == notifier.sessionGeneration &&
        _ref.read(authStateProvider).valueOrNull?.isAuthenticated == true &&
        err.requestOptions.cancelToken?.isCancelled != true;
    if (err.response?.statusCode != 401 || isAuthEndpoint || !current()) {
      return handler.next(err);
    }
    try {
      var token = notifier.accessToken;
      // Một client khác có thể đã refresh trước khi response 401 này về.
      if (token == null ||
          err.requestOptions.headers['Authorization'] == 'Bearer $token') {
        final activeEpoch = _epoch;
        if (_refreshing == null || _refreshEpoch != activeEpoch) {
          _refreshEpoch = activeEpoch;
          final operation = _refreshAsync(activeEpoch, notifier.sessionGeneration);
          _refreshing = operation;
          operation.then((_) {
            if (identical(_refreshing, operation)) _refreshing = null;
          });
        }
        token = await _refreshing;
      }
      if (!current() || token == null) return handler.next(err);
      err.requestOptions.headers['Authorization'] = 'Bearer $token';
      final retried =
          await _ref.read(authRefreshClientProvider).fetch(err.requestOptions);
      if (!current()) return handler.next(err);
      handler.resolve(retried);
    } on DioException catch (retryError) {
      // Lỗi nghiệp vụ/mạng của request retry không phải lỗi refresh phiên.
      handler.next(retryError);
    } catch (_) {
      handler.next(err);
    }
  }

  Future<String?> _refreshAsync(int epoch, int generation) async {
    final notifier = _ref.read(authStateProvider.notifier);
    final refresh = notifier.refreshToken;
    bool current() =>
        _active &&
        epoch == _epoch &&
        generation == notifier.sessionGeneration &&
        notifier.refreshToken == refresh;
    try {
      if (refresh == null) throw StateError('Missing refresh token');
      final response = await _ref
          .read(authRefreshClientProvider)
          .post('/auth/refresh', data: {'refreshToken': refresh});
      if (!current()) return null;
      final access = response.data['accessToken'] as String;
      final nextRefresh = response.data['refreshToken'] as String;
      if (access.isEmpty || nextRefresh.isEmpty) {
        throw StateError('Invalid refresh response');
      }
      await notifier.updateTokens(accessToken: access, refreshToken: nextRefresh);
      return epoch == _epoch && generation == notifier.sessionGeneration
          ? access
          : null;
    } catch (_) {
      if (current()) {
        try {
          await notifier.logout();
        } catch (_) {/* Preserve the original 401. */}
      }
      return null;
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
    final data = err.response?.data;
    handler.next(DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: AppApiException(
        message: message,
        statusCode: err.response?.statusCode,
        code: data is Map ? (data['code'] ?? data['title'])?.toString() : null,
        details: data is Map ? Map<String, dynamic>.from(data) : null,
      ),
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
