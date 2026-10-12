import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/features/schedule/domain/schedule_rules.dart';

void main() {
  test('real scheduled date takes precedence over the legacy display date', () {
    final day = DateTime(2026, 10, 12);
    expect(ScheduleRules.matchesDate(DateTime(2026, 10, 13), '12/10/2026', day),
        isFalse);
    expect(ScheduleRules.matchesDate(null, '12/10/2026', day), isTrue);
    expect(ScheduleRules.matchesDate(null, 'unknown', day), isFalse);
  });
  test('only visible statuses and valid time ranges enter the timeline', () {
    expect(ScheduleRules.canShow('in_progress'), isTrue);
    expect(ScheduleRules.canShow('completed'), isFalse);
    expect(ScheduleRules.hours('08:00 - 12:00'), (start: 8, end: 12));
    expect(ScheduleRules.hours('unknown'), isNull);
  });
}
