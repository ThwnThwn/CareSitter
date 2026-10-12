import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/features/shifts/data/models/shift_mapper.dart';

void main() {
  test('missing server times do not become a fabricated shift schedule', () {
    final shift = mapShiftFromApi({'id': 'booking', 'status': 'in_progress'});
    expect(shift.scheduledStart, isNull);
    expect(shift.scheduledEnd, isNull);
    expect(shift.date, 'Chưa có ngày');
    expect(shift.time, 'Chưa có giờ');
    expect(shift.duration, 'Chưa có thời lượng');
  });
  test('server money, offer expiry and status mapping are preserved', () {
    final shift = mapShiftFromApi({
      'id': 'booking',
      'status': 'caregiver_accepted',
      'scheduledStart': '2026-10-12T08:00:00+07:00',
      'scheduledEnd': '2026-10-12T12:00:00+07:00',
      'escrowAmount': 300000,
      'platformFeeAmount': 60000,
      'caregiverEarningAmount': 240000,
      'offerId': 'offer',
      'offerExpiresAt': '2026-10-12T07:00:00+07:00'
    });
    expect(shift.status, 'confirmed');
    expect(shift.caregiverEarning, 240000);
    expect(shift.scheduledEnd!.difference(shift.scheduledStart!).inHours, 4);
    expect(shift.offerId, 'offer');
    expect(shift.offerExpiresAt, isNotNull);
  });
}
