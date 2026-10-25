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

  test('timeline range keeps a shift ending at midnight on the next day', () {
    expect(
      ScheduleRules.timelineHours(
        DateTime(2026, 10, 24, 20),
        DateTime(2026, 10, 25),
      ),
      (start: 20, end: 24),
    );
  });

  test('timeline range includes a partially occupied end hour', () {
    expect(
      ScheduleRules.timelineHours(
        DateTime(2026, 10, 24, 8, 30),
        DateTime(2026, 10, 24, 12, 30),
      ),
      (start: 8, end: 13),
    );
  });

  test('timeline minute offsets preserve exact placement and duration', () {
    expect(
      ScheduleRules.timelineMinutes(
        DateTime(2026, 10, 24, 4, 25),
        DateTime(2026, 10, 24, 6, 25),
      ),
      (start: 265, end: 385),
    );
  });

  test('timeline minute offsets keep midnight at the end of the day', () {
    expect(
      ScheduleRules.timelineMinutes(
        DateTime(2026, 10, 24, 23),
        DateTime(2026, 10, 25, 1),
      ),
      (start: 1380, end: 1500),
    );
    expect(
      ScheduleRules.timelineHours(
        DateTime(2026, 10, 24, 23),
        DateTime(2026, 10, 25, 1),
      ),
      (start: 23, end: 25),
    );
  });

  test('timeline range rejects an invalid interval', () {
    expect(
      ScheduleRules.timelineHours(
        DateTime(2026, 10, 24, 20),
        DateTime(2026, 10, 24, 20),
      ),
      isNull,
    );
  });
}
