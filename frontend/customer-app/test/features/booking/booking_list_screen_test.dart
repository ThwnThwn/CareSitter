import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/screens/booking_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pending payment bookings are shown in upcoming tab',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
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
    expect(find.text('Gói AN'), findsOneWidget);
    expect(find.text('123 Nguyễn Huệ'), findsOneWidget);

    final firstTab = tester.getRect(find.byType(Tab).at(0));
    final lastTab = tester.getRect(find.byType(Tab).at(3));
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
    for (final label in ['Sắp tới', 'Hoàn tất', 'Chưa ghép', 'Đã hủy']) {
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
        scheduledStart: DateTime(2026, 9, 10, 11),
        scheduledEnd: DateTime(2026, 9, 10, 13),
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
