import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/core/auth/auth_notifier.dart';
import 'package:caregiver_app/core/auth/auth_state.dart';
import 'package:caregiver_app/features/home/data/models/notification_model.dart';
import 'package:caregiver_app/features/home/data/repositories/home_repository.dart';
import 'package:caregiver_app/features/home/presentation/controllers/notifications_controller.dart';

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'first', isAuthenticated: true);
  void switchToSecond() => state =
      const AsyncData(AuthState(userId: 'second', isAuthenticated: true));
}

class _Repository implements HomeRepository {
  final loads = <Completer<List<AppNotificationModel>>>[];
  final readRequest = Completer<void>();
  @override
  Future<List<AppNotificationModel>> getNotifications() {
    final pending = Completer<List<AppNotificationModel>>();
    loads.add(pending);
    return pending.future;
  }

  @override
  Future<void> markNotificationAsRead(String id) => readRequest.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

AppNotificationModel notification(String id, {bool read = false}) =>
    AppNotificationModel(
        id: id,
        title: 'Title',
        body: 'Body',
        createdAt: DateTime.utc(2026, 10, 12),
        type: 'system',
        isRead: read);
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('old notification response cannot populate a different account',
      () async {
    final repository = _Repository();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      homeRepositoryProvider.overrideWithValue(repository)
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    container.read(notificationsProvider);
    (container.read(authStateProvider.notifier) as _Auth).switchToSecond();
    expect(container.read(notificationsProvider), isEmpty);
    repository.loads.last.complete([notification('new')]);
    await flush();
    repository.loads.first.complete([notification('old')]);
    await flush();
    expect(container.read(notificationsProvider).single.id, 'new');
  });
  test('late failed read cannot roll back a more recent refresh', () async {
    final repository = _Repository();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      homeRepositoryProvider.overrideWithValue(repository)
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    final controller = container.read(notificationsProvider.notifier);
    repository.loads.first.complete([notification('first')]);
    await flush();
    final marking = controller.markAsRead('first');
    final loading = controller.refresh();
    repository.loads.last.complete([notification('latest', read: true)]);
    await loading;
    repository.readRequest.completeError(StateError('failed'));
    await marking;
    expect(container.read(notificationsProvider).single.id, 'latest');
    expect(container.read(notificationsProvider).single.isRead, isTrue);
  });
}
