import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/api/api_cancellation.dart';
import 'package:caresitter_customer/features/settings/data/repositories/settings_repository.dart';
import 'package:caresitter_customer/features/settings/presentation/controllers/notification_preferences_controller.dart';
import '../../support/session_test_auth.dart';

void main() {
  late ProviderContainer container;
  late _Settings repository;
  late SessionTestAuth auth;
  Future<void> open() async {
    repository = _Settings();
    container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(SessionTestAuth.new),
      settingsRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    auth = container.read(authStateProvider.notifier) as SessionTestAuth;
    container.listen(notificationPrefsProvider, (_, __) {});
    await flushSessionWork();
  }

  for (final user in ['second', 'first', null]) {
    test('pending preferences are cancelled when login changes to $user', () async {
      await open();
      container
          .read(notificationPrefsProvider.notifier)
          .toggle(const NotificationPrefs(bookingUpdates: false));
      auth.switchTo(user);
      await Future<void>.delayed(const Duration(milliseconds: 550));
      expect(repository.saves, isEmpty);
    });
  }

  test('late load and cancellation cannot overwrite the next login', () async {
    await open();
    final first = Completer<NotificationPrefs>();
    repository.load = first.future;
    container.invalidate(notificationPrefsProvider);
    await flushSessionWork();
    final oldCancellation = repository.lastCancellation!;
    repository.load = Future.value(const NotificationPrefs(promotion: false));
    auth.switchTo('second');
    await flushSessionWork();
    first.complete(const NotificationPrefs(promotion: true));
    await flushSessionWork();
    expect(oldCancellation.isCancelled, isTrue);
    expect(
        container.read(notificationPrefsProvider).requireValue.preferences.promotion,
        isFalse);
  });

  test('load failure is visible instead of silently enabling defaults', () async {
    await open();
    repository.failLoad = true;
    container.invalidate(notificationPrefsProvider);
    await flushSessionWork();
    expect(container.read(notificationPrefsProvider).hasError, isTrue);
  });

  test('save failure keeps the draft and retry saves it', () async {
    await open();
    repository.failSave = true;
    final notifier = container.read(notificationPrefsProvider.notifier);
    notifier.toggle(const NotificationPrefs(bookingUpdates: false));
    await Future<void>.delayed(const Duration(milliseconds: 550));
    var draft = container.read(notificationPrefsProvider).requireValue;
    expect(draft.saveError, isTrue);
    expect(draft.preferences.bookingUpdates, isFalse);
    repository.failSave = false;
    notifier.retrySave();
    await Future<void>.delayed(const Duration(milliseconds: 550));
    draft = container.read(notificationPrefsProvider).requireValue;
    expect(draft.saveError, isFalse);
    expect(draft.saving, isFalse);
    expect(repository.saves.last.bookingUpdates, isFalse);
  });

  test('a newer edit waits for the first save and wins last', () async {
    await open();
    final pending = Completer<void>();
    repository.pendingSave = pending.future;
    final notifier = container.read(notificationPrefsProvider.notifier);
    notifier.toggle(const NotificationPrefs(bookingUpdates: false));
    await Future<void>.delayed(const Duration(milliseconds: 550));
    notifier.toggle(const NotificationPrefs(bookingUpdates: true));
    await Future<void>.delayed(const Duration(milliseconds: 550));
    expect(repository.saves.length, 1);
    repository.pendingSave = null;
    pending.complete();
    await flushSessionWork();
    expect(repository.saves.map((p) => p.bookingUpdates), [false, true]);
    expect(container.read(notificationPrefsProvider).requireValue.saving, isFalse);
  });
}

class _Settings implements SettingsRepository {
  Future<NotificationPrefs>? load;
  Future<void>? pendingSave;
  bool failLoad = false, failSave = false;
  ApiCancellation? lastCancellation;
  final saves = <NotificationPrefs>[];
  @override
  Future<NotificationPrefs> getNotificationPreferences(
      {ApiCancellation? cancellation}) async {
    lastCancellation = cancellation;
    if (failLoad) throw StateError('offline');
    return load == null ? const NotificationPrefs() : await load!;
  }

  @override
  Future<void> saveNotificationPreferences(NotificationPrefs preferences,
      {ApiCancellation? cancellation}) async {
    saves.add(preferences);
    if (failSave) throw StateError('offline');
    await pendingSave;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
