import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/features/booking/domain/schedule_rules.dart';
import 'package:caresitter_customer/features/booking/domain/booking_step_rules.dart';
import 'package:caresitter_customer/features/booking/domain/caregiver_match_rules.dart';

void main() {
  test('rounding midnight advances the date', () {
    expect(ScheduleRules.snap(DateTime(2026, 10, 12), 23 * 60 + 59),
        DateTime(2026, 10, 13));
    expect(ScheduleRules.snap(DateTime(2026, 10, 12), 13),
        DateTime(2026, 10, 12, 0, 15));
  });
  test('the thirty-minute boundary is not a valid start', () {
    final now = DateTime(2026, 10, 12, 8);
    expect(ScheduleRules.isValid(now, 510, now), isFalse);
    expect(ScheduleRules.isValid(now, 515, now), isTrue);
    expect(ScheduleRules.isValid(null, 515, now), isFalse);
  });
  test('confirmation requires every prerequisite including caregiver choice',
      () {
    bool ready({bool caregiver = true, bool consent = true}) =>
        BookingStepRules.canContinue(
            step: 5,
            service: true,
            recipient: true,
            schedule: true,
            address: true,
            caregiver: caregiver,
            consent: consent);
    expect(ready(), isTrue);
    expect(ready(caregiver: false), isFalse);
    expect(ready(consent: false), isFalse);
  });
  test('matching excludes offline caregivers and ranks by rating', () {
    final ranked = CaregiverMatchRules.rankOnline([
      (id: 'offline', online: false, rating: 5.0),
      (id: 'a', online: true, rating: 4.0),
      (id: 'b', online: true, rating: 4.5)
    ], isOnline: (c) => c.online, rating: (c) => c.rating);
    expect(ranked.map((c) => c.id), ['b', 'a']);
  });
}
