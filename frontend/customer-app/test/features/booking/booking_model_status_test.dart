import 'package:caresitter_customer/features/booking/presentation/models/booking_display_model.dart';
import 'package:caresitter_customer/features/booking/data/models/booking_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookingModel presentation status', () {
    final now = DateTime(2026, 9, 29, 12);

    test('cancelled metadata wins over a stale in-progress status', () {
      final booking = _booking(
        now: now,
        status: 'in_progress',
        scheduledStart: DateTime(2026, 10, 7, 11),
        cancelledAt: DateTime(2026, 9, 11, 19, 58),
      );

      expect(booking.presentationStatusAt(now), 'cancelled');
      expect(booking.isLiveTrackingAt(now), isFalse);
    });

    test('future in-progress status without check-in is treated as upcoming',
        () {
      final booking = _booking(
        now: now,
        status: 'in_progress',
        scheduledStart: DateTime(2026, 10, 7, 11),
        caregiverId: 'caregiver',
      );

      expect(booking.presentationStatusAt(now), 'caregiver_accepted');
      expect(booking.isLiveTrackingAt(now), isFalse);
    });

    test('in-progress status remains live after a real check-in', () {
      final booking = _booking(
        now: now,
        status: 'in_progress',
        scheduledStart: DateTime(2026, 9, 29, 11),
        caregiverId: 'caregiver',
        actualStart: DateTime(2026, 9, 29, 10, 55),
      );

      expect(booking.presentationStatusAt(now), 'in_progress');
      expect(booking.isLiveTrackingAt(now), isTrue);
    });
  });
}

BookingModel _booking({
  required DateTime now,
  required String status,
  required DateTime scheduledStart,
  String? caregiverId,
  DateTime? actualStart,
  DateTime? cancelledAt,
}) {
  return BookingModel(
    id: 'booking',
    beneficiaryId: 'beneficiary',
    caregiverId: caregiverId,
    addressId: 'address',
    serviceTypeId: 'service',
    scheduledStart: scheduledStart,
    scheduledEnd: scheduledStart.add(const Duration(hours: 4)),
    actualStart: actualStart,
    status: status,
    escrowAmount: 380000,
    platformFeeAmount: 57000,
    cancelledAt: cancelledAt,
    createdAt: now.subtract(const Duration(days: 2)),
    updatedAt: now,
  );
}
