import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/booking/domain/booking_status_rules.dart';
import 'package:caresitter_customer/features/booking/domain/booking_amount_rules.dart';

void main() {
  test(
      'server customer amount overrides escrow including a zero payable amount',
      () {
    expect(BookingAmountRules.payable(100000, 0), 0);
    expect(BookingAmountRules.payable(100000, 75000), 75000);
    expect(BookingAmountRules.payable(100000, null), 100000);
    expect(BookingAmountRules.caregiverEarning(100000, 15000), 85000);
  });
  final now = DateTime.utc(2026, 10, 12);
  test('future check-in cannot turn an upcoming booking into a live shift', () {
    final status = BookingStatusRules.presentationStatusAt(
        status: 'in_progress',
        now: now,
        actualStart: now.add(const Duration(hours: 1)),
        caregiverAssigned: true);
    expect(status, 'caregiver_accepted');
    expect(BookingStatusRules.isLiveStatus(status), isFalse);
  });
  test('cancellation metadata wins over an old live status', () {
    expect(
        BookingStatusRules.presentationStatusAt(
            status: 'in_progress',
            now: now,
            cancelledAt: now,
            actualStart: now.subtract(const Duration(hours: 1)),
            caregiverAssigned: true),
        'cancelled');
  });
  test(
      'refund and dispute retain their terminal status when cancellation exists',
      () {
    for (final status in ['refunded', 'disputed']) {
      expect(
          BookingStatusRules.presentationStatusAt(
              status: status,
              now: now,
              cancelledAt: now,
              caregiverAssigned: false),
          status);
    }
  });
}
