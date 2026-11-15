import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/shift_tracking/data/models/booking_timeline_event_model.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/controllers/booking_timeline_controller.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/screens/care_timeline_screen.dart';

class _Bookings extends BookingStore {
  @override
  List<BookingModel> build() => [
        BookingModel.fromJson({
          'id': 'booking',
          'status': 'in_progress',
          'scheduledStart': '2026-11-14T04:00:00Z',
          'scheduledEnd': '2026-11-14T06:00:00Z',
          'caregiverName': 'Người chăm sóc',
        })
      ];
}

void main() {
  testWidgets(
      'existing timeline renders the actual meal record and note from the server',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          bookingStoreProvider.overrideWith(_Bookings.new),
          bookingTimelineProvider.overrideWith((ref, id) async => [
                BookingTimelineEventModel(
                    id: 'event',
                    eventType: 'NOTE',
                    title: 'Ăn một phần: Cháo',
                    note: 'Ăn nửa phần.',
                    recordedAt: DateTime.parse('2026-11-14T05:00:00Z'))
              ]),
        ],
        child:
            const MaterialApp(home: CareTimelineScreen(bookingId: 'booking'))));
    await tester.pumpAndSettle();
    expect(find.text('Ăn một phần: Cháo'), findsOneWidget);
    expect(find.text('Ăn nửa phần.'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('Thực hiện các hoạt động chăm sóc'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
