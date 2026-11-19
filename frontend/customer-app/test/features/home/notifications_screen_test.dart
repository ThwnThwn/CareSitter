import 'dart:async';

import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/core/push/notification_deep_link_service.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/home/data/repositories/notification_repository.dart';
import 'package:caresitter_customer/features/home/presentation/controllers/notifications_controller.dart';
import 'package:caresitter_customer/features/home/presentation/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('shows the chat preview and marks the group by swiping at 320px',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final item = _chat();
    final repository =
        _Repository(NotificationInboxModel(items: [item], unreadCount: 3));
    final links = _Links();
    await _mount(tester, repository, links, textScale: 2);
    await tester.pumpAndSettle();

    expect(find.text('Nguyễn Thị Lan'), findsOneWidget);
    expect(find.text('Mai chị đến sớm 30 phút nhé.'), findsOneWidget);
    expect(find.text('NL'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('14:30'), findsOneWidget);
    expect(find.text('Lịch 20/11 · 09:00'), findsOneWidget);
    expect(find.text('3 thông báo chưa đọc'), findsOneWidget);
    expect(find.text('3 chưa đọc'), findsOneWidget);
    expect(find.textContaining('Mở ứng dụng'), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(Dismissible), const Offset(-230, 0));
    await tester.pumpAndSettle();
    expect(repository.readIds, ['head']);
    expect(find.text('3 thông báo chưa đọc'), findsNothing);
    expect(find.text('Nguyễn Thị Lan'), findsOneWidget);

    await tester.tap(find.text('Nguyễn Thị Lan'));
    await tester.pumpAndSettle();
    expect(links.opened.single['bookingId'], 'booking-1');
    expect(links.opened.single['type'], 'BOOKING_CHAT');
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses the inbox total and offers to load earlier notifications',
      (tester) async {
    final first = _chat();
    final earlier = AppNotification(
      id: 'older',
      type: 'BOOKING',
      title: 'Đã xác nhận lịch chăm sóc',
      body: '',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      data: const {},
      isRead: false,
    );
    final repository = _Repository(
      NotificationInboxModel(items: [first], unreadCount: 4, hasMore: true),
    )..next = NotificationInboxModel(items: [earlier], unreadCount: 4, page: 2);
    await _mount(tester, repository, _Links());
    await tester.pumpAndSettle();

    expect(find.text('4 thông báo chưa đọc'), findsOneWidget);
    await tester.tap(find.text('Xem thông báo cũ hơn'));
    await tester.pumpAndSettle();
    expect(find.text('Cũ hơn'), findsOneWidget);
    expect(find.text('Đã xác nhận lịch chăm sóc'), findsOneWidget);
    expect(find.text('Nguyễn Thị Lan'), findsOneWidget);
    expect(find.text('4 thông báo chưa đọc'), findsOneWidget);

    await tester.tap(find.text('Đọc tất cả'));
    await tester.pumpAndSettle();
    expect(repository.markedAll, 1);
    expect(find.text('4 thông báo chưa đọc'), findsNothing);
    expect(find.byTooltip('Đánh dấu đã đọc'), findsNothing);
  });

  testWidgets('shows loading, an error and the empty inbox on retry',
      (tester) async {
    final pending = Completer<NotificationInboxModel>();
    final repository = _Repository(const NotificationInboxModel())
      ..pending = pending.future;
    await _mount(tester, repository, _Links());
    await tester.pump();
    expect(find.bySemanticsLabel('Đang tải thông báo'), findsOneWidget);
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Không thể tải thông báo'), findsOneWidget);
    repository.pending = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thông báo'), findsOneWidget);
  });

  test('uses local calendar boundaries and real time instead of rounded days',
      () {
    final now = DateTime(2026, 11, 18, 9);
    final yesterday = DateTime(2026, 11, 17, 14, 30);
    expect(notificationTimestamp(yesterday, now), '14:30 hôm qua');
    expect(notificationTimestamp(DateTime(2026, 11, 8, 12, 7), now),
        '08/11 · 12:07');
    final items = [
      for (final (id, day) in [('today', 18), ('week', 16), ('older', 15)])
        AppNotification(
          id: id,
          type: 'BOOKING',
          title: id,
          body: '',
          createdAt: DateTime(2026, 11, day),
          data: const {},
          isRead: true,
        ),
    ];
    expect(
      notificationSections(items, now)
          .map((section, rows) => MapEntry(section, rows.single.id)),
      {'Hôm nay': 'today', 'Tuần này': 'week', 'Cũ hơn': 'older'},
    );
  });

  test('secondary inbox text meets 4.5:1 on the read and unread backgrounds',
      () {
    final textLuminance = AppColors.textSecondary.computeLuminance();
    for (final background in [AppColors.surface, AppColors.primaryContainer]) {
      final contrast =
          (background.computeLuminance() + .05) / (textLuminance + .05);
      expect(contrast, greaterThanOrEqualTo(4.5));
    }
  });
}

AppNotification _chat() {
  final now = DateTime.now();
  return AppNotification.fromJson({
    'id': 'head',
    'groupKey': 'BOOKING_CHAT:booking-1',
    'type': 'BOOKING_CHAT',
    'title': 'Tin nhắn mới về lịch chăm sóc',
    'body': 'Bạn có tin nhắn mới. Mở ứng dụng để xem.',
    'createdAt':
        DateTime(now.year, now.month, now.day, 14, 31).toIso8601String(),
    'unreadCount': 3,
    'data': '{"bookingId":"booking-1","conversationId":"chat-1"}',
    'chat': {
      'senderName': 'Nguyễn Thị Lan',
      'preview': 'Mai chị đến sớm 30 phút nhé.',
      'sentAt':
          DateTime(now.year, now.month, now.day, 14, 30).toIso8601String(),
      'scheduledStart': '2026-11-20T09:00:00',
    },
  });
}

Future<void> _mount(WidgetTester tester, _Repository repository, _Links links,
        {double textScale = 1}) =>
    tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_SignedInAuth.new),
        notificationRepositoryProvider.overrideWithValue(repository),
        notificationDeepLinkServiceProvider.overrideWithValue(links),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const NotificationsScreen(),
      ),
    ));

class _SignedInAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'customer', isAuthenticated: true);
}

class _Repository implements NotificationRepository {
  _Repository(this.first);

  final NotificationInboxModel first;
  NotificationInboxModel? next;
  Future<NotificationInboxModel>? pending;
  final readIds = <String>[];
  int markedAll = 0;

  @override
  Future<NotificationInboxModel> getNotifications(
      {int page = 1, CancelToken? cancelToken}) async {
    final request = pending;
    if (request != null) return request;
    return page == 1 ? first : next ?? const NotificationInboxModel();
  }

  @override
  Future<void> markRead(String id) async => readIds.add(id);

  @override
  Future<void> markAllRead() async => markedAll++;
}

class _Links implements NotificationDeepLinkService {
  final opened = <Map<String, dynamic>>[];

  @override
  Future<void> handle(Map<String, dynamic> data, {String? deliveryId}) async =>
      opened.add(data);

  @override
  String? resolveRoute(Map<String, dynamic> data) => '/bookings/booking-1/chat';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
