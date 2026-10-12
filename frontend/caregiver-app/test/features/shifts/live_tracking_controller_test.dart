import 'package:caregiver_app/core/api/api_cancellation.dart';
import 'package:caregiver_app/core/error/app_exception.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:caregiver_app/features/shifts/data/repositories/gps_repository.dart';
import 'package:caregiver_app/features/shifts/presentation/controllers/live_tracking_controller.dart';
import 'package:caregiver_app/features/shifts/data/repositories/tracking_location_source.dart';

class FakeLocations extends TrackingLocationSource {
  final stream = StreamController<Position>.broadcast(sync: true);
  bool allowed = true;
  int permissionCalls = 0;
  @override
  Future<bool> requestAccess() async {
    permissionCalls++;
    return allowed;
  }

  @override
  Stream<Position> positions() => stream.stream;
}

class FakeGps implements GpsRepository {
  String status = 'caregiver_en_route';
  int statusChecks = 0;
  int sessions = 0;
  final samples = <DateTime>[];
  ApiCancellation? lastCancel;
  Completer<void>? pendingUpload;
  Completer<String>? pendingStatus;
  AppApiException? nextError;
  @override
  Future<String> bookingStatus(String id,
      {ApiCancellation? cancelToken}) async {
    statusChecks++;
    return pendingStatus == null ? status : await pendingStatus!.future;
  }

  @override
  Future<Map<String, dynamic>> openSession(String id, String sourceId,
      {ApiCancellation? cancelToken}) async {
    sessions++;
    return {'sessionId': 'session-$sessions', 'sendIntervalSeconds': 10};
  }

  @override
  Future<void> postLocation(String id,
      {required String sessionId,
      required DateTime capturedAt,
      required double latitude,
      required double longitude,
      double? accuracyMeters,
      double? speed,
      double? heading,
      ApiCancellation? cancelToken}) async {
    samples.add(capturedAt);
    lastCancel = cancelToken;
    final error = nextError;
    nextError = null;
    if (error != null) throw error;
    await pendingUpload?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Position fix(DateTime timestamp) => Position(
    latitude: 10.8,
    longitude: 106.7,
    timestamp: timestamp,
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 2,
    speedAccuracy: 0);

void main() {
  testWidgets(
      'Permission denial leaves the booking usable without opening a GPS session',
      (tester) async {
    final api = FakeGps();
    final locations = FakeLocations()..allowed = false;
    final controller =
        LiveTrackingController(api, locations, observeLifecycle: false);
    await controller.start('booking');
    expect(api.sessions, 0);
    expect(controller.state.bookingId, 'booking');
    expect(controller.state.sending, false);
    controller.dispose();
    await locations.stream.close();
  });

  testWidgets(
      'Only one upload is in flight and offline samples collapse to the newest fix',
      (tester) async {
    final api = FakeGps()..pendingUpload = Completer<void>();
    final locations = FakeLocations();
    final controller = LiveTrackingController(api, locations,
        observeLifecycle: false, now: tester.binding.clock.now);
    await controller.start('booking');
    final first =
        tester.binding.clock.now().subtract(const Duration(seconds: 2));
    locations.stream.add(fix(first));
    await tester.pump();
    locations.stream.add(fix(first.add(const Duration(seconds: 1))));
    locations.stream.add(fix(first.add(const Duration(seconds: 2))));
    await tester.pump(const Duration(seconds: 10));
    expect(api.samples, [first]);
    api.pendingUpload!.complete();
    api.pendingUpload = null;
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(api.samples, [first, first.add(const Duration(seconds: 2))]);
    controller.reconcileStatus('booking', 'in_progress');
    await tester.pump();
    locations.stream.add(fix(tester.binding.clock.now()));
    await tester.pump(const Duration(seconds: 15));
    expect(api.samples.length, 2);
    expect(controller.state.bookingId, isNull);
    controller.dispose();
    await locations.stream.close();
  });

  test(
      'Logout cancels in-flight work and cannot be undone by its late completion',
      () async {
    final api = FakeGps()..pendingUpload = Completer<void>();
    final locations = FakeLocations();
    final controller = LiveTrackingController(api, locations,
        observeLifecycle: false, now: DateTime.now);
    await controller.start('booking');
    locations.stream.add(fix(DateTime.now()));
    await Future<void>.delayed(Duration.zero);
    final stopping = controller.stop();
    await Future<void>.delayed(Duration.zero);
    await stopping;
    expect(api.lastCancel!.isCancelled, true);
    api.pendingUpload!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.bookingId, isNull);
    expect(controller.state.sending, false);
    controller.dispose();
    await locations.stream.close();
  });

  testWidgets(
      'Stopping during server verification never prompts for permission or starts tracking',
      (tester) async {
    final api = FakeGps()..pendingStatus = Completer<String>();
    final locations = FakeLocations();
    final controller =
        LiveTrackingController(api, locations, observeLifecycle: false);
    final starting = controller.start('booking');
    await tester.pump();
    await controller.stop();
    api.pendingStatus!.complete('caregiver_en_route');
    await starting;
    expect(locations.permissionCalls, 0);
    expect(api.sessions, 0);
    expect(controller.state.bookingId, isNull);
    controller.dispose();
    await locations.stream.close();
  });

  testWidgets(
      'Pause stops uploads and resume rechecks the server before restarting',
      (tester) async {
    final api = FakeGps();
    final locations = FakeLocations();
    final controller = LiveTrackingController(api, locations,
        observeLifecycle: false, now: tester.binding.clock.now);
    await controller.start('booking');
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    locations.stream.add(fix(tester.binding.clock.now()));
    await tester.pump(const Duration(seconds: 20));
    expect(api.samples, isEmpty);
    api.status = 'completed';
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(api.statusChecks, 2);
    expect(api.sessions, 1);
    expect(controller.state.bookingId, isNull);
    controller.dispose();
    await locations.stream.close();
  });

  testWidgets(
      '429 respects Retry-After while keeping only the newest pending position',
      (tester) async {
    final api = FakeGps()
      ..nextError = const AppApiException(
          message: 'Quá nhiều yêu cầu', statusCode: 429, retryAfterSeconds: 20);
    final locations = FakeLocations();
    final controller = LiveTrackingController(api, locations,
        observeLifecycle: false, now: tester.binding.clock.now);
    await controller.start('booking');
    locations.stream.add(fix(tester.binding.clock.now()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    final newest = tester.binding.clock.now();
    locations.stream.add(fix(newest));
    await tester.pump(const Duration(seconds: 9));
    expect(api.samples.length, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(api.samples.length, 2);
    expect(api.samples.last, newest);
    controller.dispose();
    await locations.stream.close();
  });
}
