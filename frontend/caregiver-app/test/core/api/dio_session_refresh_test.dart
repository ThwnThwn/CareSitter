import 'dart:async';

import 'package:caregiver_app/core/api/dio_client.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Server implements HttpClientAdapter {
  final refreshStarted = Completer<void>();
  final secondRefreshStarted = Completer<void>();
  Completer<void>? holdRefresh;
  int refreshStatus = 200;
  int refreshCalls = 0;
  int retriedUploads = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.path.endsWith('/auth/refresh')) {
      refreshCalls++;
      if (!refreshStarted.isCompleted) refreshStarted.complete();
      if (refreshCalls == 2) secondRefreshStarted.complete();
      if (refreshCalls == 1) await holdRefresh?.future;
      return _response(
          refreshStatus,
          refreshStatus == 200
              ? '{"accessToken":"fresh-access","refreshToken":"fresh-refresh"}'
              : '{"detail":"Refresh failed"}');
    }
    if (options.headers['Authorization'] == 'Bearer old-access') {
      return _response(401, '{"detail":"Expired"}');
    }
    if (options.path.endsWith('/conflict')) {
      return _response(409, '{"detail":"Conflict"}');
    }
    if (options.path.endsWith('/upload')) {
      retriedUploads++;
      return _response(200, '{"ok":true}');
    }
    return _response(200, '{"ok":true}');
  }

  ResponseBody _response(int status, String body) =>
      ResponseBody.fromString(body, status, headers: {
        'content-type': ['application/json']
      });

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late ProviderContainer container;
  late DioClient client;
  late _Server server;
  late Map<String, String> values;
  late Completer<void> accessWriteStarted;
  Completer<void>? holdAccessWrite;

  setUp(() async {
    values = <String, String>{
      'access_token': 'old-access',
      'refresh_token': 'old-refresh',
      'user_id': 'account-a',
      'phone': '000',
      'roles': 'CAREGIVER',
    };
    accessWriteStarted = Completer<void>();
    holdAccessWrite = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      final args = (call.arguments as Map?) ?? {};
      final key = args['key']?.toString();
      switch (call.method) {
        case 'read':
          return values[key];
        case 'write':
          if (args['value'] == 'fresh-access' && holdAccessWrite != null) {
            if (!accessWriteStarted.isCompleted) accessWriteStarted.complete();
            await holdAccessWrite!.future;
          }
          values[key!] = args['value'] as String;
          return null;
        case 'delete':
          values.remove(key);
          return null;
        case 'deleteAll':
          values.clear();
          return null;
      }
      throw UnimplementedError(call.method);
    });
    server = _Server();
    final refreshClient = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = server;
    container = ProviderContainer(overrides: [
      dioClientProvider.overrideWith((ref) => DioClient(ref, adapter: server)),
      authRefreshClientProvider.overrideWithValue(refreshClient),
    ]);
    await container.read(authStateProvider.future);
    client = container.read(dioClientProvider);
  });

  tearDown(() {
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('late refresh cannot replace a new account session', () async {
    server.holdRefresh = Completer<void>();
    final oldRequest =
        expectLater(client.get('/data'), throwsA(isA<AppApiException>()));
    await server.refreshStarted.future;
    await container.read(authStateProvider.notifier).login(
      accessToken: 'account-b-access',
      refreshToken: 'account-b-refresh',
      userId: 'account-b',
      phone: '111',
      roles: const ['CAREGIVER'],
    );
    server.holdRefresh!.complete();
    await oldRequest;
    final auth = container.read(authStateProvider).value!;
    expect(auth.userId, 'account-b');
    expect(auth.accessToken, 'account-b-access');
    expect(auth.refreshToken, 'account-b-refresh');
  });

  test('failed old refresh cannot log out a new account', () async {
    server.refreshStatus = 500;
    server.holdRefresh = Completer<void>();
    final oldRequest =
        expectLater(client.get('/data'), throwsA(isA<AppApiException>()));
    await server.refreshStarted.future;
    await container.read(authStateProvider.notifier).login(
      accessToken: 'account-b-access',
      refreshToken: 'account-b-refresh',
      userId: 'account-b',
      phone: '111',
      roles: const ['CAREGIVER'],
    );
    server.holdRefresh!.complete();
    await oldRequest;
    expect(container.read(authStateProvider).value!.userId, 'account-b');
    expect(container.read(authStateProvider).value!.isAuthenticated, isTrue);
  });

  test('new login for the same account starts its own refresh', () async {
    server.holdRefresh = Completer<void>();
    final oldRequest =
        expectLater(client.get('/data'), throwsA(isA<AppApiException>()));
    await server.refreshStarted.future;
    await container.read(authStateProvider.notifier).login(
      accessToken: 'old-access',
      refreshToken: 'new-session-refresh',
      userId: 'account-a',
      phone: '000',
      roles: const ['CAREGIVER'],
    );
    final newRequest = client.get('/data');
    try {
      await server.secondRefreshStarted.future
          .timeout(const Duration(seconds: 2));
    } finally {
      server.holdRefresh!.complete();
    }
    expect(server.refreshCalls, 2);
    await oldRequest;
    expect((await newRequest).data['ok'], isTrue);
    expect(container.read(authStateProvider).value!.isAuthenticated, isTrue);
  });

  test('business failure after refresh keeps the session and status', () async {
    await expectLater(
        client.get('/conflict'),
        throwsA(isA<AppApiException>()
            .having((error) => error.statusCode, 'status', 409)));
    expect(container.read(authStateProvider).value!.isAuthenticated, isTrue);
  });

  test('concurrent 401 responses share one refresh', () async {
    server.holdRefresh = Completer<void>();
    final requests = Future.wait([client.get('/data'), client.get('/data')]);
    await server.refreshStarted.future;
    await Future<void>.delayed(Duration.zero);
    expect(server.refreshCalls, 1);
    server.holdRefresh!.complete();
    final responses = await requests;
    expect(responses.length, 2);
    expect(
        container.read(authStateProvider).value!.accessToken, 'fresh-access');
  });

  test('late secure storage write cannot replace a newer login', () async {
    holdAccessWrite = Completer<void>();
    final authNotifier = container.read(authStateProvider.notifier);
    final updating = authNotifier.updateTokens(
        accessToken: 'fresh-access', refreshToken: 'fresh-refresh');
    await accessWriteStarted.future;
    final login = authNotifier.login(
      accessToken: 'account-b-access',
      refreshToken: 'account-b-refresh',
      userId: 'account-b',
      phone: '111',
      roles: const ['CAREGIVER'],
    );
    holdAccessWrite!.complete();
    await Future.wait([updating, login]);
    expect(container.read(authStateProvider).value!.userId, 'account-b');
    expect(container.read(authStateProvider).value!.accessToken,
        'account-b-access');
    expect(values['access_token'], 'account-b-access');
    expect(values['refresh_token'], 'account-b-refresh');
  });

  test('multipart request can be retried after refresh', () async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes([1, 2, 3], filename: 'photo.jpg'),
    });
    final response =
        await client.postForm<Map<String, dynamic>>('/upload', form);
    expect(response.data?['ok'], isTrue);
    expect(server.retriedUploads, 1);
    expect(container.read(authStateProvider).value!.isAuthenticated, isTrue);
  });
}
