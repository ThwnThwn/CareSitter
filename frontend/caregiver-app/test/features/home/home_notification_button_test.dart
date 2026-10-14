import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:caregiver_app/features/home/data/models/notification_model.dart';
import 'package:caregiver_app/features/home/presentation/controllers/notifications_controller.dart';
import 'package:caregiver_app/features/home/presentation/widgets/home_notification_button.dart';

class _Notifications extends StateNotifier<List<AppNotificationModel>>
    implements NotificationsController {
  _Notifications() : super(const []);
  void replace(List<AppNotificationModel> value) => state = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'notification updates change the unread badge and the bell opens its route',
      (tester) async {
    final notifications = _Notifications();
    const unread = AppNotificationModel(
        id: 'notice',
        title: 'Ca mới',
        body: '',
        createdAt: null,
        type: 'booking',
        isRead: false);
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: HomeNotificationButton())),
      GoRoute(
          path: '/notifications',
          builder: (_, __) => const Scaffold(body: Text('Thông báo'))),
    ]);
    await tester.pumpWidget(ProviderScope(overrides: [
      notificationsProvider.overrideWith((ref) => notifications),
    ], child: MaterialApp.router(routerConfig: router)));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    });
    await tester.pumpAndSettle();
    final badge = find.byKey(const ValueKey('home-unread-notifications'));
    expect(badge, findsNothing);
    notifications.replace([unread]);
    await tester.pump();
    expect(badge, findsOneWidget);
    notifications.replace([unread.copyWith(isRead: true)]);
    await tester.pump();
    expect(badge, findsNothing);
    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Thông báo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
