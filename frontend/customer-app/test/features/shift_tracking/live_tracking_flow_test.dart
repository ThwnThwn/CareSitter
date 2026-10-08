import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:caresitter_customer/core/api/dio_client.dart';
import 'package:caresitter_customer/core/maps/google_maps_runtime.dart';
import 'package:caresitter_customer/core/realtime/care_signalr_service.dart';
import 'package:caresitter_customer/core/theme/app_theme.dart';
import 'package:caresitter_customer/features/booking/data/repositories/booking_repository.dart';
import 'package:caresitter_customer/features/booking/presentation/controllers/booking_controller.dart';
import 'package:caresitter_customer/features/shift_tracking/presentation/screens/shift_tracking_screen.dart';
import 'live_caregiver_map_test.dart' show FakeGoogleMapPlatform;

const _bookingId = 'tracking-booking';
const _caregiverId = 'current-caregiver';

class _UnusedClient implements DioClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repository extends BookingRepository {
  int calls = 0;
  _Repository() : super(_UnusedClient());
  @override
  Future<GpsTrackModel?> getLatestGps(String bookingId) async {
    calls++;
    return GpsTrackModel(
        id: 'snapshot',
        bookingId: _bookingId,
        caregiverId: _caregiverId,
        latitude: 10.79,
        longitude: 106.71,
        recordedAt: DateTime.now(),
        version: 1);
  }
}

class _Store extends BookingStore {
  @override
  List<BookingModel> build() => [
        BookingModel(
            id: _bookingId,
            beneficiaryId: 'beneficiary',
            addressId: 'address',
            serviceTypeId: 'service',
            caregiverId: _caregiverId,
            status: 'caregiver_en_route',
            escrowAmount: 100000,
            platformFeeAmount: 0,
            scheduledStart: DateTime.now().add(const Duration(hours: 1)),
            scheduledEnd: DateTime.now().add(const Duration(hours: 3)),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            addressLatitude: 10.7769,
            addressLongitude: 106.7009,
            addressText: '123 Nguyễn Huệ, TP. Hồ Chí Minh',
            caregiverName: 'Chăm sóc viên thử nghiệm')
      ];
  @override
  Future<void> refresh() async {}
  @override
  Future<List<CareTaskModel>> loadTasks(String bookingId) async => const [];
}

class _Hub implements CareSignalRService {
  final gps = StreamController<GpsUpdate>.broadcast();
  final statuses = StreamController<BookingStatusChange>.broadcast();
  final lifecycle = StreamController<SignalRConnectionState>.broadcast();
  final joining = Completer<void>();
  bool ready = true;
  @override
  bool get isReady => ready;
  @override
  Stream<GpsUpdate> get gpsStream => gps.stream;
  @override
  Stream<BookingStatusChange> get statusStream => statuses.stream;
  @override
  Stream<SignalRConnectionState> get lifecycleStream => lifecycle.stream;
  @override
  Stream<void> get onReconnected => const Stream.empty();
  @override
  Future<void> joinBooking(String id) => joining.future;
  @override
  Future<void> leaveBooking(String id) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  Future<void> close() async {
    if (!joining.isCompleted) joining.complete();
    await gps.close();
    await statuses.close();
    await lifecycle.close();
  }
}

GpsUpdate _gps(int version,
        {String caregiver = _caregiverId, String booking = _bookingId}) =>
    GpsUpdate(
        bookingId: booking,
        caregiverId: caregiver,
        latitude: 10.785,
        longitude: 106.705,
        recordedAt: DateTime.now(),
        version: version,
        heading: 90);

void main() {
  testWidgets(
      'REST works before Hub joins, valid push moves Google marker, outage polls and ending clears GPS',
      (tester) async {
    final original = GoogleMapsFlutterPlatform.instance;
    final platform = FakeGoogleMapPlatform();
    GoogleMapsFlutterPlatform.instance = platform;
    addTearDown(() => GoogleMapsFlutterPlatform.instance = original);
    final hub = _Hub();
    final repository = _Repository();
    final container = ProviderContainer(overrides: [
      bookingStoreProvider.overrideWith(_Store.new),
      bookingRepositoryProvider.overrideWithValue(repository),
      careSignalRProvider.overrideWithValue(hub),
      googleMapsReadyProvider.overrideWith((_) async => true),
    ]);
    addTearDown(container.dispose);
    addTearDown(hub.close);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.4)),
                child: child!),
            home: const ShiftTrackingScreen(bookingId: _bookingId))));
    await tester.pumpAndSettle();
    expect(hub.joining.isCompleted, false);
    expect(repository.calls, 1);
    expect(platform.markers[const MarkerId('caregiver')]!.position,
        const LatLng(10.79, 106.71));
    // Nút bản đồ phải nhận được thao tác, kể cả cạnh thanh tiêu đề trên màn nhỏ.
    final beforeFit = platform.cameraUpdates.length;
    await tester.tap(find.byKey(const Key('tracking-fit-both')));
    await tester.pumpAndSettle();
    expect(platform.cameraUpdates.length, greaterThan(beforeFit));
    await tester.tap(find.byKey(const Key('tracking-follow')));
    await tester.pumpAndSettle();

    hub.gps.add(_gps(9, caregiver: 'another-caregiver'));
    hub.gps.add(_gps(10, booking: 'another-booking'));
    await tester.pumpAndSettle();
    expect(platform.markers[const MarkerId('caregiver')]!.position,
        const LatLng(10.79, 106.71));
    hub.gps.add(_gps(2));
    await tester.pumpAndSettle();
    expect(platform.markers[const MarkerId('caregiver')]!.position,
        const LatLng(10.785, 106.705));

    hub.ready = false;
    hub.lifecycle.add(SignalRConnectionState.reconnecting);
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    // Snapshot phiên bản 1 trả chậm không ghi đè mẫu SignalR phiên bản 2.
    expect(platform.markers[const MarkerId('caregiver')]!.position,
        const LatLng(10.785, 106.705));

    hub.statuses.add(BookingStatusChange(
        bookingId: _bookingId,
        oldStatus: 'caregiver_en_route',
        newStatus: 'in_progress',
        changedAt: DateTime.now()));
    await tester.pumpAndSettle();
    expect(platform.markers.containsKey(const MarkerId('caregiver')), false);
    hub.gps.add(_gps(3));
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(platform.markers.containsKey(const MarkerId('caregiver')), false);
    expect(repository.calls, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
