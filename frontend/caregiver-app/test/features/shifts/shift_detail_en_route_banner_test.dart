import 'dart:async';

import 'package:caregiver_app/core/error/app_exception.dart';
import 'package:caregiver_app/core/widgets/app_messenger.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_model.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/live_tracking_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/shift_list_controller.dart';
import 'package:caregiver_app/features/shifts/presentation/widgets/shift_detail_en_route_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Shifts extends StateNotifier<List<ShiftModel>>
    implements ShiftListController {
  _Shifts() : super(const []);

  final checkInCompleter = Completer<void>();

  @override
  Future<void> checkIn(String id) => checkInCompleter.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Tracking extends StateNotifier<LiveTrackingState>
    implements LiveTrackingController {
  _Tracking()
      : super(const LiveTrackingState(
          bookingId: 'shift',
          message: 'Đang chia sẻ vị trí.',
          sending: true,
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _booking = ShiftModel(
  id: 'shift',
  beneficiaryName: 'An',
  caregiverName: 'Caregiver',
  caregiverAvatar: '',
  serviceName: 'Hỗ trợ thiết yếu',
  status: 'caregiver_en_route',
  totalPrice: 200000,
  address: 'TP. Hồ Chí Minh',
);

void main() {
  testWidgets('check-in shows progress then the geofence failure message',
      (tester) async {
    final shifts = _Shifts();
    final tracking = _Tracking();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        shiftsProvider.overrideWith((ref) => shifts),
        liveTrackingProvider.overrideWith((ref) => tracking),
      ],
      child: MaterialApp(
        scaffoldMessengerKey: appMessengerKey,
        home: const Scaffold(
          body: ShiftDetailEnRouteBanner(booking: _booking),
        ),
      ),
    ));

    await tester.tap(find.text('GPS Check-in tại địa điểm'));
    await tester.pump();
    expect(find.text('Đang xác thực vị trí'), findsOneWidget);
    expect(
        find.textContaining('Đang lấy vị trí GPS để check-in'), findsOneWidget);
    expect(find.text('Đang kiểm tra vị trí…'), findsOneWidget);

    shifts.checkInCompleter.completeError(const AppApiException(
      message: 'Ngoài bán kính cho phép (235m > 50m).',
      statusCode: 422,
      code: 'booking.geofence',
    ));
    await tester.pump();

    expect(
      find.text('Check-in chưa thành công'),
      findsOneWidget,
    );
    expect(
      find.text('Ngoài bán kính cho phép (235m > 50m).'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
  });
}
