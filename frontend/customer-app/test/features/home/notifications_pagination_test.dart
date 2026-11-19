import 'dart:async';

import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/features/home/data/repositories/notification_repository.dart';
import 'package:caresitter_customer/features/home/presentation/controllers/notifications_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('realtime refresh keeps older groups pushed onto the following page',
      () async {
    const days = {'a': 4, 'b': 3, 'c': 2, 'd': 1};
    var rows = ['b', 'c', 'd'];
    var version = '1';
    final c = await _container((p) async => _page(
        rows[p - 1], p, rows.length, version,
        last: p == rows.length, day: days[rows[p - 1]]!));
    await c.read(notificationsProvider.future);
    final notifier = c.read(notificationsProvider.notifier);
    await notifier.loadMore();
    expect(_keys(c), ['b', 'c']);
    rows = ['a', ...rows];
    version = '2';
    await notifier.refreshForNewChat();
    expect(_keys(c), ['a', 'b', 'c']);
    expect(c.read(notificationsProvider).requireValue.page, 3);
    await notifier.loadMore();
    expect(_keys(c), ['a', 'b', 'c', 'd']);
  });

  test('loading more reconciles an earlier read on another device', () async {
    var remoteRead = false;
    final c = await _container((p) async => _page(p == 1 ? 'first' : 'older', p,
        remoteRead ? 0 : 1, remoteRead ? '2' : '1',
        last: p == 2, read: remoteRead || p == 2));
    await c.read(notificationsProvider.future);
    remoteRead = true;
    await c.read(notificationsProvider.notifier).loadMore();
    final inbox = c.read(notificationsProvider).requireValue;
    expect(inbox.unreadCount, 0);
    expect(inbox.items, hasLength(2));
    expect(inbox.items.every((i) => i.isRead), isTrue);
  });

  test('a changed revision during a multi-page refresh retries the window',
      () async {
    var version = '1';
    var changeOnSecondPage = false;
    final pages = <int>[];
    final c = await _container((p) async {
      pages.add(p);
      if (p == 2 && changeOnSecondPage) {
        version = '3';
        changeOnSecondPage = false;
      }
      return _page('group-$p', p, version == '3' ? 0 : 2, version,
          last: p == 2, read: version == '3');
    });
    await c.read(notificationsProvider.future);
    final notifier = c.read(notificationsProvider.notifier);
    await notifier.loadMore();
    pages.clear();
    version = '2';
    changeOnSecondPage = true;
    await notifier.refresh();
    expect(pages, [1, 2, 1, 2]);
    final result = c.read(notificationsProvider).requireValue;
    expect(result.items.every((n) => n.isRead), isTrue);
    expect(result.version, '3');
  });

  test('initial load and push refresh publish in request order', () async {
    final initial = Completer<NotificationInboxModel>();
    var requests = 0;
    final c = await _container((_) {
      if (++requests == 1) return initial.future;
      return Future.value(_page('fresh', 1, 0, '2', last: true, read: true));
    });
    final notifier = c.read(notificationsProvider.notifier);
    final refreshing = notifier.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    initial.complete(_page('stale', 1, 1, '1', last: true));
    await refreshing;
    expect(requests, 2);
    expect(_keys(c), ['fresh']);
    expect(c.read(unreadNotificationsCountProvider), 0);
  });

  test('a new account does not inherit pending requests or loaded pages',
      () async {
    final initial = Completer<NotificationInboxModel>();
    var requests = 0;
    final c = await _container((_) => ++requests == 1
        ? initial.future
        : Future.value(_page('new-account', 1, 1, '2', last: true)));
    final old = c.read(notificationsProvider.notifier).refresh();
    (c.read(authStateProvider.notifier) as _Session).switchTo('other');
    await c.read(notificationsProvider.future);
    initial.complete(_page('previous-account', 1, 1, '1', last: true));
    await old;
    expect(_keys(c), ['new-account']);
    expect(requests, 2);
  });
}

List<String> _keys(ProviderContainer c) =>
    c.read(notificationsProvider).requireValue.items.map((i) => i.key).toList();

NotificationInboxModel _page(String key, int page, int total, String version,
        {required bool last, bool read = false, int day = 1}) =>
    NotificationInboxModel(
      items: [
        AppNotification(
            id: key,
            type: 'BOOKING',
            title: key,
            body: '',
            data: const {},
            createdAt: DateTime.utc(2026, 1, day),
            isRead: read)
      ],
      unreadCount: total,
      page: page,
      hasMore: !last,
      version: version,
    );

Future<ProviderContainer> _container(
    Future<NotificationInboxModel> Function(int) fetch) async {
  final c = ProviderContainer(overrides: [
    authStateProvider.overrideWith(_Session.new),
    notificationRepositoryProvider.overrideWithValue(_Repository(fetch)),
  ]);
  addTearDown(c.dispose);
  await c.read(authStateProvider.future);
  return c;
}

class _Session extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'customer', isAuthenticated: true);

  void switchTo(String user) =>
      state = AsyncData(AuthState(userId: user, isAuthenticated: true));
}

class _Repository implements NotificationRepository {
  _Repository(this.fetch);
  final Future<NotificationInboxModel> Function(int) fetch;

  @override
  Future<NotificationInboxModel> getNotifications(
          {int page = 1, CancelToken? cancelToken}) =>
      fetch(page);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
