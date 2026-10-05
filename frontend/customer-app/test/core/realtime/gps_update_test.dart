import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/realtime/gps_update.dart';

void main() {
  Map<String, dynamic> payload(int version) => {
        'bookingId': 'booking',
        'caregiverId': 'caregiver',
        'latitude': 10.8,
        'longitude': 106.7,
        'capturedAt': '2026-10-05T01:00:00Z',
        'version': version,
      };

  test('Reject invalid coordinates, timestamp and unversioned legacy events',
      () {
    for (final bad in [
      {...payload(1), 'latitude': double.nan},
      {...payload(1), 'longitude': double.infinity},
      {...payload(1), 'latitude': 91},
      {...payload(1), 'longitude': -181},
      {...payload(1), 'capturedAt': null},
      payload(0),
    ]) {
      expect(() => GpsUpdate.fromJson(bad), throwsFormatException);
    }
  });

  test('Late REST snapshot cannot overwrite a newer SignalR event', () {
    final state = LiveGpsAccumulator();
    bool accept(int version) =>
        state.accept(GpsUpdate.fromJson(payload(version)),
            bookingId: 'booking', caregiverId: 'caregiver', enRoute: true);
    expect(accept(12), true);
    expect(accept(11), false);
    expect(accept(12), false);
    expect(state.latest!.version, 12);
    expect(accept(13), true);
  });

  test('Ended or reassigned bookings reject delayed coordinates', () {
    final state = LiveGpsAccumulator();
    final sample = GpsUpdate.fromJson(payload(20));
    expect(
        state.accept(sample,
            bookingId: 'booking', caregiverId: 'caregiver', enRoute: false),
        false);
    expect(
        state.accept(sample,
            bookingId: 'booking', caregiverId: 'new-caregiver', enRoute: true),
        false);
    expect(
        state.accept(sample,
            bookingId: 'another', caregiverId: 'caregiver', enRoute: true),
        false);
    expect(state.latest, isNull);
  });

  test('Clearing a deleted snapshot preserves its watermark across recreation',
      () {
    final state = LiveGpsAccumulator();
    bool accept(int v) => state.accept(GpsUpdate.fromJson(payload(v)),
        bookingId: 'booking', caregiverId: 'caregiver', enRoute: true);
    accept(100);
    state.clear();
    expect(accept(100), false);
    expect(state.latest, isNull);
    expect(accept(103), true);
  });
}
