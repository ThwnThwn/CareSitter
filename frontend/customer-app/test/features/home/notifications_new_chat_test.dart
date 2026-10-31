import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/core/notifications/in_app_notification_events.dart';
import 'package:caresitter_customer/features/home/data/repositories/notification_repository.dart';
import 'package:caresitter_customer/features/home/presentation/controllers/notifications_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('realtime chat refresh announces only a newly arrived unread message',
      () async {
    final repository = _Repository();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_SignedInAuth.new),
      notificationRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);

    repository.items = [_notification('old')];
    await container.read(notificationsProvider.future);
    final events = <InAppNotificationEvent>[];
    final subscription = container
        .read(inAppNotificationEventsProvider)
        .stream
        .listen(events.add);
    addTearDown(subscription.cancel);

    final notifier = container.read(notificationsProvider.notifier);
    repository.items = [_notification('new'), _notification('old')];
    await notifier.refreshForNewChat();
    await Future<void>.delayed(Duration.zero);
    expect(events.single.title, 'Bạn có 1 tin nhắn mới');
    expect(events.single.data['bookingId'], 'booking-1');

    await notifier.refreshForNewChat();
    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(1));
  });
}

AppNotification _notification(String id) => AppNotification(
      id: id,
      type: 'BOOKING_CHAT',
      title: 'Tin nhắn mới',
      body: 'Mở ứng dụng để xem.',
      createdAt: DateTime.utc(2026, 10, 31),
      data: const {'bookingId': 'booking-1'},
      isRead: false,
    );

class _SignedInAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'customer', isAuthenticated: true);
}

class _Repository implements NotificationRepository {
  List<AppNotification> items = [];

  @override
  Future<List<AppNotification>> getNotifications() async => items;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
