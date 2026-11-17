import 'dart:async';
import 'dart:convert';

import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/app/auth/session_bootstrap_gate.dart';
import 'package:caresitter_customer/app/care_sitter_app.dart';
import 'package:caresitter_customer/app/router/app_router.dart';
import 'package:caresitter_customer/app/push/notification_deep_link_service.dart';
import 'package:caresitter_customer/core/push/notification_deep_link_service.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/router/auth_route_redirect.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> values;
  late _SessionServer server;
  late ProviderContainer container;
  setUp(() {
    values = {
      'access_token': 'expired-access',
      'refresh_token': 'expired-refresh',
      'user_id': 'owner',
      'phone': '0900000000',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (call) async {
      final args = call.arguments as Map;
      if (call.method == 'read') return values[args['key']];
      if (call.method == 'delete') values.remove(args['key']);
      if (call.method == 'write') {
        values[args['key'] as String] = args['value'] as String;
      }
      return null;
    });
    server = _SessionServer();
    final transport = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
      ..httpClientAdapter = server;
    container = ProviderContainer(overrides: [
      authRefreshClientProvider.overrideWithValue(transport),
      notificationDeepLinkServiceProvider
          .overrideWith(createNotificationDeepLinkService),
    ]);
  });
  tearDown(() {
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null);
  });

  testWidgets('expired persisted session never builds Home before Login',
      (tester) async {
    await tester.runAsync(() async {
      container.read(authStateProvider.future);
      await Future<void>.delayed(Duration.zero);
    });
    var homeBuilds = 0;
    final router = GoRouter(
      initialLocation: '/home',
      redirect: (_, state) => authSessionRouteRedirect(
        location: state.uri.toString(),
        isAuthenticated: container
            .read(authStateProvider.future)
            .then((session) => session.isAuthenticated),
      ),
      routes: [
        GoRoute(
            path: '/home',
            builder: (_, __) {
              homeBuilds++;
              return const Text('Home');
            }),
        GoRoute(path: '/auth/login', builder: (_, __) => const Text('Login')),
      ],
    );
    addTearDown(router.dispose);
    try {
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(const Duration(milliseconds: 100));
      expect(homeBuilds, 0,
          reason: 'Protected Home must wait for stored-session validation.');
      server.release.complete();
      await tester.runAsync(() => container.read(authStateProvider.future));
      await tester.pumpAndSettle();
      expect(homeBuilds, 0);
      expect(find.text('Login'), findsOneWidget);
      expect(values, isEmpty);
      expect(server.paths, ['/auth/session', '/auth/refresh']);
    } finally {
      if (!server.release.isCompleted) server.release.complete();
    }
  });

  test('valid stored access is checked without rotating its refresh token',
      () async {
    server.sessionStatus = 204;
    final pending = container.read(authStateProvider.future);
    await server.started.future;
    expect(container.read(authStateProvider).isLoading, isTrue);
    server.release.complete();
    final session = await pending;
    expect(session.isAuthenticated, isTrue);
    expect(session.accessToken, 'expired-access');
    expect(server.paths, ['/auth/session']);
    expect(server.bearers, ['Bearer expired-access']);
    expect(values['refresh_token'], 'expired-refresh');
  });

  test(
      'expired access is refreshed and persisted before opening protected routes',
      () async {
    server.refreshStatus = 200;
    final pending = container.read(authStateProvider.future);
    server.release.complete();
    final session = await pending;
    expect(session.isAuthenticated, isTrue);
    expect(session.accessToken, 'fresh-access');
    expect(session.refreshToken, 'fresh-refresh');
    expect(values['access_token'], 'fresh-access');
    expect(values['refresh_token'], 'fresh-refresh');
    expect(server.paths, ['/auth/session', '/auth/refresh']);
  });

  test('missing refresh cannot restore an expired access token', () async {
    values.remove('refresh_token');
    server.release.complete();
    expect((await container.read(authStateProvider.future)).isAuthenticated,
        isFalse);
    expect(values, isEmpty);
    expect(server.paths, ['/auth/session']);
  });

  test('backend validation rejection of an expired refresh clears the session',
      () async {
    server.refreshStatus = 400;
    server.release.complete();
    expect((await container.read(authStateProvider.future)).isAuthenticated,
        isFalse);
    expect(values, isEmpty);
  });

  test('no saved session goes straight to anonymous without a network call',
      () async {
    values.clear();
    expect((await container.read(authStateProvider.future)).isAuthenticated,
        isFalse);
    expect(server.paths, isEmpty);
  });

  for (final failedStep in ['validation', 'refresh']) {
    test('temporary $failedStep failure preserves credentials for retry',
        () async {
      if (failedStep == 'validation') {
        server.sessionStatus = 503;
      } else {
        server.refreshStatus = 503;
      }
      server.release.complete();
      await expectLater(container.read(authStateProvider.future),
          throwsA(isA<AppApiException>()));
      expect(container.read(authStateProvider).hasError, isTrue);
      expect(values['access_token'], 'expired-access');
      expect(values['refresh_token'], 'expired-refresh');
      server.sessionStatus = 204;
      await container.read(authStateProvider.notifier).retryRestore();
      expect(container.read(authStateProvider).requireValue.isAuthenticated,
          isTrue);
    });
  }

  for (final outcome in [200, 400, 503]) {
    for (final newLogin in [true, false]) {
      test(
          'late bootstrap $outcome cannot overwrite ${newLogin ? 'login' : 'logout'}',
          () async {
        server.refreshStatus = outcome;
        final pending = container.read(authStateProvider.future);
        await server.started.future;
        final auth = container.read(authStateProvider.notifier);
        if (newLogin) {
          await auth.login(
              accessToken: 'new-access',
              refreshToken: 'new-refresh',
              userId: 'new-owner',
              phone: '0900000001');
        } else {
          await auth.logout();
        }
        server.release.complete();
        await pending;
        final session = container.read(authStateProvider).requireValue;
        expect(session.isAuthenticated, newLogin);
        expect(session.userId, newLogin ? 'new-owner' : null);
        if (newLogin) {
          expect(values['access_token'], 'new-access');
          expect(values['refresh_token'], 'new-refresh');
        } else {
          expect(values, isEmpty);
        }
      });
    }
  }

  testWidgets(
      'bootstrap gate keeps routes unbuilt on a network error and retries',
      (tester) async {
    var routeBuilds = 0;
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/payment-result?bookingId=booking-1&intentId=intent-1';
    addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    server.sessionStatus = 503;
    late Future<void> failure;
    await tester.runAsync(() async {
      failure = expectLater(container.read(authStateProvider.future),
          throwsA(isA<AppApiException>()));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: SessionBootstrapGate(builder: (_, __) {
        routeBuilds++;
        return const MaterialApp(home: Text('Ready'));
      }),
    ));
    expect(find.text('Đang kiểm tra phiên đăng nhập…'), findsOneWidget);
    expect(routeBuilds, 0);
    expect(find.byType(Navigator), findsNothing);
    server.release.complete();
    await tester.runAsync(() => failure);
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    expect(routeBuilds, 0);
    expect(find.byType(Navigator), findsNothing);
    expect(values['refresh_token'], 'expired-refresh');
    server.sessionStatus = 204;
    tester.binding.platformDispatcher.clearDefaultRouteNameTestValue();
    await tester.runAsync(() async {
      await tester.tap(find.text('Thử lại'));
      await container.read(authStateProvider.future);
    });
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
    expect(routeBuilds, greaterThan(0));
  });

  testWidgets('app integrations tolerate an unavailable startup session',
      (tester) async {
    server.sessionStatus = 503;
    late Future<void> failure;
    await tester.runAsync(() async {
      failure = expectLater(container.read(authStateProvider.future),
          throwsA(isA<AppApiException>()));
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const CareSitterApp()));
    addTearDown(() => container.read(appRouterProvider).dispose());
    server.release.complete();
    await tester.runAsync(() => failure);
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(container.read(authStateProvider).hasError, isTrue);
    final links = container.read(notificationDeepLinkServiceProvider);
    await links.handle({'type': 'PAYMENT', 'bookingId': 'booking-1'},
        deliveryId: 'startup-delivery');
    await links.flushPending();
  });
}

class _SessionServer implements HttpClientAdapter {
  final release = Completer<void>();
  final started = Completer<void>();
  final paths = <String>[];
  final bearers = <String?>[];
  int sessionStatus = 401, refreshStatus = 401;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    paths.add(options.path);
    bearers.add(options.headers['Authorization'] as String?);
    if (!started.isCompleted) started.complete();
    await release.future;
    final status =
        options.path == '/auth/session' ? sessionStatus : refreshStatus;
    final data = status == 200
        ? {'accessToken': 'fresh-access', 'refreshToken': 'fresh-refresh'}
        : {'code': 'auth.invalid_refresh_token'};
    return ResponseBody.fromString(
        status == 204 ? '' : jsonEncode(data), status,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }
}
