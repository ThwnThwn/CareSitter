import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/features/home/data/repositories/notification_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requests an inbox page and decodes the server version and total',
      () async {
    final http = _Http();
    final repo = NotificationRepository(http);
    final token = CancelToken();
    final page = await repo.getNotifications(page: 2, cancelToken: token);
    expect(http.token, same(token));
    expect(http.path, '/notifications/inbox');
    expect(http.query, {'page': 2, 'pageSize': 50});
    expect(page.page, 2);
    expect(page.version, 'v1');
    expect(page.unreadCount, 8);
    expect(page.hasMore, isTrue);

    await repo.markRead('notification-id');
    expect(http.path, '/notifications/notification-id/read-group');
    await repo.markAllRead();
    expect(http.path, '/notifications/read-all');
  });

  test('propagates API errors and accepts inbox data from earlier servers',
      () async {
    final http = _Http();
    final repo = NotificationRepository(http);
    http.json.remove('version');
    expect((await repo.getNotifications()).version, isNull);
    http.error = const AppApiException(message: 'Offline');
    await expectLater(repo.getNotifications(), throwsA(same(http.error)));
  });
}

class _Http implements DioClient {
  final json = <String, dynamic>{
    'items': [],
    'version': 'v1',
    'unreadCount': 8,
    'hasMore': true
  };
  String? path;
  Map<String, dynamic>? query;
  AppApiException? error;
  CancelToken? token;

  @override
  Future<Response<T>> getCancelable<T>(String path,
      {Map<String, dynamic>? query,
      required CancelToken cancelToken,
      Duration? receiveTimeout}) async {
    this.path = path;
    this.query = query;
    token = cancelToken;
    if (error != null) throw error!;
    return Response<T>(
        requestOptions: RequestOptions(path: path), data: json as T);
  }

  @override
  Future<Response<T>> put<T>(String path, {dynamic data}) async {
    this.path = path;
    return Response<T>(requestOptions: RequestOptions(path: path));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
