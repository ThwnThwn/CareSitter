import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/config/env_config.dart';
import 'package:caregiver_app/core/error/app_exception.dart';

final String _baseUrl = EnvConfig.baseUrl;

final dioClientProvider = Provider<DioClient>((ref) => DioClient(ref));
final authRefreshClientProvider = Provider<Dio>((ref) {
  final client = Dio(BaseOptions(baseUrl: _baseUrl));
  ref.onDispose(() => client.close(force: true));
  return client;
});

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

  Future<Response<T>> postIdempotent<T>(String path,
          {dynamic data, required String idempotencyKey}) =>
      _request(() => _dio.post<T>(path,
          data: data,
          options: Options(headers: {'Idempotency-Key': idempotencyKey})));

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

class _AuthInterceptor extends Interceptor {
  final Ref _ref;
  Future<String?>? _refreshing;
  int _epoch = 0, _refreshEpoch = -1, _refreshGeneration = -1;
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
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final path = err.requestOptions.path;
    final isAuthEndpoint =
        path.endsWith('/auth/refresh') || path.endsWith('/auth/logout');
    if (!_active) return handler.next(err);

    final authNotifier = _ref.read(authStateProvider.notifier);
    final epoch = err.requestOptions.extra['authSessionEpoch'];
    final generation = err.requestOptions.extra['authSessionGeneration'];
    bool current() =>
        _active &&
        epoch == _epoch &&
        generation == authNotifier.sessionGeneration &&
        _ref.read(authStateProvider).valueOrNull?.isAuthenticated == true &&
        err.requestOptions.cancelToken?.isCancelled != true;
    if (err.response?.statusCode != 401 || isAuthEndpoint || !current()) {
      return handler.next(err);
    }
    try {
      var token = authNotifier.accessToken;
      // Request khác có thể đã refresh trước khi response 401 này về.
      if (token == null ||
          err.requestOptions.headers['Authorization'] == 'Bearer $token') {
        final activeEpoch = _epoch;
        final activeGeneration = authNotifier.sessionGeneration;
        if (_refreshing == null ||
            _refreshEpoch != activeEpoch ||
            _refreshGeneration != activeGeneration) {
          _refreshEpoch = activeEpoch;
          _refreshGeneration = activeGeneration;
          final operation = _refreshAsync(activeEpoch, activeGeneration);
          _refreshing = operation;
          operation.then((_) {
            if (identical(_refreshing, operation)) _refreshing = null;
          });
        }
        token = await _refreshing;
      }
      if (!current() || token == null) return handler.next(err);
      err.requestOptions.headers['Authorization'] = 'Bearer $token';
      final body = err.requestOptions.data;
      if (body is FormData) err.requestOptions.data = body.clone();
      final retried =
          await _ref.read(authRefreshClientProvider).fetch(err.requestOptions);
      if (!current()) return handler.next(err);
      handler.resolve(retried);
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (_) {
      handler.next(err);
    }
  }

  Future<String?> _refreshAsync(int epoch, int generation) async {
    final authNotifier = _ref.read(authStateProvider.notifier);
    final refresh = authNotifier.refreshToken;
    bool current() =>
        _active &&
        epoch == _epoch &&
        generation == authNotifier.sessionGeneration &&
        authNotifier.refreshToken == refresh;
    try {
      if (refresh == null) throw StateError('Missing refresh token');
      // Backend tra phiên bằng refresh token, không cần access token.
      final response = await _ref
          .read(authRefreshClientProvider)
          .post('/auth/refresh', data: {'refreshToken': refresh});
      if (!current()) return null;
      final access = response.data['accessToken'] as String;
      final nextRefresh = response.data['refreshToken'] as String;
      if (access.isEmpty || nextRefresh.isEmpty) {
        throw StateError('Invalid refresh response');
      }
      await authNotifier.updateTokens(
          accessToken: access, refreshToken: nextRefresh);
      return epoch == _epoch && generation == authNotifier.sessionGeneration
          ? access
          : null;
    } catch (_) {
      if (current()) {
        try {
          await authNotifier.logout();
        } catch (_) {/* Giữ lỗi 401 ban đầu. */}
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
