import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/application/booking_store.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/shift_tracking_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders an en-route booking without layout or null errors',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(466, 950);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingStoreProvider.overrideWith(_EnRouteBookingStore.new),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ShiftTrackingScreen(bookingId: _bookingId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Theo dõi ca chăm sóc'), findsOneWidget);
    expect(find.text('Caregiver đang trên đường đến'), findsOneWidget);
    expect(find.text(_address), findsOneWidget);
    final error = tester.takeException();
    debugDefaultTargetPlatformOverride = null;
    expect(error, isNull);
  });

  testWidgets('renders malformed optional task data defensively',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingStoreProvider.overrideWith(_InProgressBookingStore.new),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ShiftTrackingScreen(bookingId: _bookingId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Công việc hôm nay'), findsOneWidget);
    expect(find.text('Chưa có công việc nào'), findsNothing);
    final error = tester.takeException();
    debugDefaultTargetPlatformOverride = null;
    expect(error, isNull);
  });
}

const _bookingId = '669b5213-5405-45f6-a2ba-ec70fb57a2fe';
const _address = 'ẤP 10 XÃ LƯƠNG HÒA HUYỆN BẾN LỨC TỈNH LONG AN';

BookingModel _booking(
    {required String status, List<dynamic> tasks = const []}) {
  return BookingModel(
    id: _bookingId,
    beneficiaryId: '5bca24eb-ea6e-4764-86b9-f598e38833a2',
    caregiverId: 'a0000000-0000-0000-0000-0000000000e4',
    addressId: '4f225453-0e2e-45b6-9f95-12beb5d1e12a',
    serviceTypeId: 'a0000000-0000-0000-0000-0000000000f1',
    scheduledStart: DateTime(2026, 10, 1, 8),
    scheduledEnd: DateTime(2026, 10, 1, 12),
    status: status,
    escrowAmount: 390000,
    platformFeeAmount: 58500,
    createdAt: DateTime(2026, 9, 8, 21, 25),
    updatedAt: DateTime(2026, 9, 9, 13, 29),
    caregiverName: 'Nguyễn Thị Bích Ngọc',
    beneficiaryName: 'Văn Châu Trường Thuận',
    addressText: _address,
    serviceName: 'Gói DƯỠNG (Thể chất & Sinh hoạt)',
    tasks: tasks,
  );
}

class _EnRouteBookingStore extends BookingStore {
  @override
  List<BookingModel> build() => [_booking(status: 'caregiver_en_route')];
}

class _InProgressBookingStore extends BookingStore {
  @override
  List<BookingModel> build() => [
        _booking(
          status: 'in_progress',
          tasks: const [
            null,
            <String, dynamic>{'title': null}
          ],
        ),
      ];
}
