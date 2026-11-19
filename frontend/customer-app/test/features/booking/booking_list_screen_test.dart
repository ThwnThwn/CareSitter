import 'dart:async';

import 'package:caresitter_customer/core/auth/auth_notifier.dart';
import 'package:caresitter_customer/core/auth/auth_state.dart';
import 'package:caresitter_customer/core/error/app_exception.dart';
import 'package:caresitter_customer/core/realtime/care_signalr_service.dart';
import 'package:caresitter_customer/features/booking/data/models/booking_list_response.dart';
import 'package:caresitter_customer/features/booking/data/repositories/booking_repository.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/screens/booking_list_screen.dart';
import 'package:caresitter_customer/features/home/presentation/controllers/notifications_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('waiting, failure and successful empty list are distinct',
      (tester) async {
    final repository = _PendingBookings();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_SignedInAuth.new),
      bookingRepositoryProvider.overrideWithValue(repository),
      careSignalRProvider.overrideWithValue(_DisconnectedHub()),
      notificationsProvider.overrideWith(_EmptyInbox.new),
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BookingListScreen())));
    await tester.pump();
    expect(repository.requests, hasLength(1));
    expect(find.text('Chưa có lịch hẹn'), findsNothing);
    expect(find.text('Đang tải lịch hẹn…'), findsOneWidget);

    repository.requests.first
        .completeError(const AppApiException(message: 'Mất kết nối'));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được lịch hẹn'), findsOneWidget);
    expect(find.text('Chưa có lịch hẹn'), findsNothing);
    expect(find.text('Đặt lịch ngay'), findsNothing);

    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(repository.requests, hasLength(2));
    expect(find.text('Đang tải lịch hẹn…'), findsOneWidget);
    repository.requests.last.complete(
        const BookingListResponse(items: [], total: 0, page: 1, pageSize: 50));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có lịch hẹn'), findsOneWidget);
    expect(find.text('Đặt lịch ngay'), findsOneWidget);
    expect(find.text('Không tải được lịch hẹn'), findsNothing);

    await tester.tap(find.widgetWithText(Tab, 'Hoàn tất'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có lịch hoàn tất'), findsOneWidget);
    expect(find.text('Đặt lịch ngay'), findsNothing);
  });

  testWidgets(
      'active bookings past their end keep their status and show a warning',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingStoreProvider.overrideWith(_FakeBookingStore.new),
        ],
        child: const MaterialApp(home: BookingListScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Chờ thanh toán'), findsOneWidget);
    expect(find.text('Đã qua giờ hẹn'), findsOneWidget);
    expect(find.text('Gói AN'), findsOneWidget);
    expect(find.text('123 Nguyễn Huệ'), findsOneWidget);

    final firstTab = tester.getRect(find.byType(Tab).at(0));
    final lastTab = tester.getRect(find.byType(Tab).last);
    expect(
      (firstTab.left + lastTab.right) / 2,
      closeTo(tester.view.physicalSize.width / 2, 2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('booking cards wrap at 320 px with enlarged text',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingStoreProvider.overrideWith(_FakeBookingStore.new),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.4),
            ),
            child: child!,
          ),
          home: const BookingListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chờ thanh toán'), findsOneWidget);
    for (final label in [
      'Đang xử lý',
      'Hoàn tất',
      'Chưa ghép',
      'Khiếu nại',
      'Hủy / hoàn tiền'
    ]) {
      final labelFinder = find.text(label);
      final tabFinder = find.ancestor(
        of: labelFinder,
        matching: find.byType(Tab),
      );
      final labelRect = tester.getRect(labelFinder);
      final tabRect = tester.getRect(tabFinder);
      final labelRender = tester.renderObject<RenderParagraph>(labelFinder);
      final naturalLabelWidth =
          labelRender.getMaxIntrinsicWidth(double.infinity);
      expect(
        labelRect.left >= tabRect.left && labelRect.right <= tabRect.right,
        isTrue,
        reason: 'Nhãn "$label" phải nằm trong vùng tab ở màn hình hẹp.',
      );
      expect(
        naturalLabelWidth,
        lessThanOrEqualTo(labelRect.width + 0.5),
        reason: 'Nhãn "$label" không được bị cắt mất chữ.',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmatched tab shows confirmed bookings without caregiver',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        bookingStoreProvider.overrideWith(_UnmatchedBookingStore.new)
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: const BookingListScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Ca đang chờ ghép'), findsNothing);
    await tester.ensureVisible(find.text('Chưa ghép'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chưa ghép'));
    await tester.pumpAndSettle();
    expect(find.text('Ca đang chờ ghép'), findsOneWidget);
    expect(find.text('Chờ ghép chăm sóc viên'), findsOneWidget);
    expect(find.text('Ca ghép thất bại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _UnmatchedBookingStore extends BookingStore {
  @override
  List<BookingModel> build() => [
        _booking('confirmed', 'Ca đang chờ ghép'),
        _booking('matching_failed', 'Ca ghép thất bại'),
      ];

  BookingModel _booking(String status, String serviceName) =>
      BookingModel.fromJson({
        'id': serviceName,
        'status': status,
        'beneficiaryId': 'beneficiary-1',
        'addressId': 'address-1',
        'serviceTypeId': 'service-1',
        'scheduledStart': '2026-11-12T07:00:00Z',
        'scheduledEnd': '2026-11-12T09:00:00Z',
        'serviceName': serviceName,
      });
}

class _PendingBookings implements BookingRepository {
  final requests = <Completer<BookingListResponse>>[];

  @override
  Future<BookingListResponse> getBookings(
      {String? status, int page = 1, int pageSize = 20}) {
    final request = Completer<BookingListResponse>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedInAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async =>
      const AuthState(userId: 'owner', isAuthenticated: true);
}

class _DisconnectedHub implements CareSignalRService {
  @override
  bool get isConnected => false;

  @override
  Future<void> connect() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyInbox extends NotificationsNotifier {
  @override
  Future<NotificationInboxModel> build() async =>
      const NotificationInboxModel();
}

class _FakeBookingStore extends BookingStore {
  @override
  List<BookingModel> build() {
    return [
      BookingModel(
        id: 'booking-pending-payment',
        beneficiaryId: 'beneficiary-1',
        caregiverId: 'caregiver-1',
        addressId: 'address-1',
        serviceTypeId: 'service-1',
        scheduledStart: DateTime(2020, 9, 10, 11),
        scheduledEnd: DateTime(2020, 9, 10, 13),
        status: 'pending_payment',
        escrowAmount: 247000,
        platformFeeAmount: 37050,
        createdAt: DateTime(2026, 9, 8, 13),
        updatedAt: DateTime(2026, 9, 8, 13),
        caregiverName: 'Nguyễn Thị Bích Ngọc',
        beneficiaryName: 'Ông Nguyễn Văn Ba',
        addressText: '123 Nguyễn Huệ',
        serviceName: 'Gói AN',
      ),
    ];
  }
}
