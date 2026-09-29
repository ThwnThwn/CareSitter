import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/booking/presentation/screens/booking_list_screen.dart';
import 'package:flutter/material.dart';
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
    expect(tester.takeException(), isNull);
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
