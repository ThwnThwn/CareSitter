import 'dart:async';
import 'dart:convert';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Server server;
  late _Auth auth;
  late ProviderContainer container;
  late List<DioClient> clients;
  setUp(() async {
    server = _Server();
    auth = _Auth();
    final transport = Dio(BaseOptions(baseUrl: 'https://people.test/api/v1'))
      ..httpClientAdapter = server;
    container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(() => auth),
      authRefreshClientProvider.overrideWithValue(transport),
    ]);
    await container.read(authStateProvider.future);
    final provider = Provider((ref) => [
          DioClient(ref,
              baseUrl: 'https://people.test/api/v1', adapter: server),
          DioClient(ref,
              baseUrl: 'https://nutrition.test/api/v1', adapter: server),
        ]);
    clients = container.read(provider);
  });
  tearDown(() => container.dispose());

  test('People and Nutrition share one refresh and retry their original hosts',
      () async {
    server.hold = Completer<void>();
    final both = Future.wait(clients.map((c) => c.get('/data')));
    await server.started.future;
    await Future<void>.delayed(Duration.zero);
    expect(server.refreshes, 1);
    server.hold!.complete();
    final responses = await both;
    expect(responses.map((r) => r.data['host']),
        unorderedEquals(['people.test', 'nutrition.test']));
    expect(auth.updates, 1);
    expect(auth.logouts, 0);
  });

  test('late old refresh neither updates nor logs out a new account', () async {
    server.hold = Completer<void>();
    final checked =
        expectLater(clients[1].get('/data'), throwsA(isA<AppApiException>()));
    await server.started.future;
    auth.switchAccount();
    server.hold!.complete();
    await checked;
    expect(auth.updates, 0);
    expect(auth.logouts, 0);
    expect(container.read(authStateProvider).value!.userId, 'new-owner');
  });

  test(
      'business failure after successful refresh preserves the session and status',
      () async {
    await expectLater(
        clients[1].get('/conflict'),
        throwsA(
            isA<AppApiException>().having((e) => e.statusCode, 'status', 409)));
    expect(auth.updates, 1);
    expect(auth.logouts, 0);
    expect(container.read(authStateProvider).value!.isAuthenticated, isTrue);
  });

  for (final switchToNewAccount in [true, false]) {
    test(
        'secure storage refresh cannot overwrite ${switchToNewAccount ? 'new login' : 'logout'}',
        () async {
      const channel =
          MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
      final values = <String, String>{};
      final writing = Completer<void>(), release = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map? ?? {};
        if (call.method == 'read') return values[args['key']];
        if (call.method == 'write') {
          if (args['value'] == 'refresh-access') {
            writing.complete();
            await release.future;
          }
          values[args['key'] as String] = args['value'] as String;
        }
        if (call.method == 'delete') values.remove(args['key'] as String);
        if (call.method == 'deleteAll') values.clear();
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      final real = ProviderContainer();
      addTearDown(real.dispose);
      await real.read(authStateProvider.future);
      final notifier = real.read(authStateProvider.notifier);
      await notifier.login(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
          userId: 'old-owner',
          phone: '0900000000');
      final refreshing = notifier.updateTokens(
          accessToken: 'refresh-access', refreshToken: 'refresh-token');
      await writing.future;
      final boundary = switchToNewAccount
          ? notifier.login(
              accessToken: 'new-access',
              refreshToken: 'new-refresh',
              userId: 'new-owner',
              phone: '0900000001')
          : notifier.logout();
      release.complete();
      await Future.wait([refreshing, boundary]);
      expect(real.read(authStateProvider).value!.isAuthenticated,
          switchToNewAccount);
      if (switchToNewAccount) {
        expect(values['access_token'], 'new-access');
        expect(values['user_id'], 'new-owner');
      } else {
        expect(values, isEmpty);
      }
    });
  }
}

class _Auth extends AuthNotifier {
  int updates = 0, logouts = 0;
  @override
  Future<AuthState> build() async => const AuthState(
      userId: 'owner',
      isAuthenticated: true,
      accessToken: 'old',
      refreshToken: 'old-refresh');
  @override
  Future<void> updateTokens(
      {required String accessToken, required String refreshToken}) async {
    updates++;
    state = AsyncData(state.value!
        .copyWith(accessToken: accessToken, refreshToken: refreshToken));
  }

  @override
  Future<void> logout() async {
    logouts++;
    state = const AsyncData(AuthState.initial());
  }

  void switchAccount() => state = const AsyncData(AuthState(
      userId: 'new-owner',
      isAuthenticated: true,
      accessToken: 'new-owner-token',
      refreshToken: 'new-owner-refresh'));
}

class _Server implements HttpClientAdapter {
  int refreshes = 0;
  Completer<void>? hold;
  final started = Completer<void>();
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    var status = 200;
    Map<String, dynamic> data;
    if (options.path == '/auth/refresh') {
      refreshes++;
      if (!started.isCompleted) started.complete();
      if (hold != null) await hold!.future;
      data = {'accessToken': 'fresh', 'refreshToken': 'fresh-refresh'};
    } else if (options.headers['Authorization'] != 'Bearer fresh') {
      status = 401;
      data = {'detail': 'Expired'};
    } else if (options.path == '/conflict') {
      status = 409;
      data = {'title': 'nutrition.profile_changed', 'detail': 'Changed'};
    } else {
      data = {'host': options.uri.host};
    }
    return ResponseBody.fromString(jsonEncode(data), status, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }
}
