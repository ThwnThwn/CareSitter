import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/features/home/domain/home_shift_rules.dart';

void main() {
  test('expired offers stop appearing exactly at their expiry', () {
    final now = DateTime(2026, 10, 12, 8);
    expect(HomeShiftRules.isOpenOffer('open', 'id', now, now), isFalse);
    expect(
        HomeShiftRules.isOpenOffer(
            'pending', 'id', now.add(const Duration(seconds: 1)), now),
        isTrue);
    expect(
        HomeShiftRules.isOpenOffer(
            'confirmed', 'id', now.add(const Duration(seconds: 1)), now),
        isFalse);
  });
  test('today classification preserves active statuses and undated fallback',
      () {
    final now = DateTime(2026, 10, 12);
    expect(HomeShiftRules.isToday('in_progress', null, now), isTrue);
    expect(HomeShiftRules.isToday('completed', null, now), isFalse);
    expect(HomeShiftRules.isToday('confirmed', DateTime(2026, 10, 13), now),
        isFalse);
  });
  test(
      'turnaround warning covers both adjacent sides but excludes overlapping shifts',
      () {
    final start = DateTime(2026, 10, 12, 10);
    final end = DateTime(2026, 10, 12, 12);
    expect(
        HomeShiftRules.isTightTurnaround(
            start,
            end,
            start.subtract(const Duration(hours: 2)),
            start.subtract(const Duration(minutes: 30))),
        isTrue);
    expect(
        HomeShiftRules.isTightTurnaround(
            start,
            end,
            end.add(const Duration(minutes: 30)),
            end.add(const Duration(hours: 2))),
        isTrue);
    expect(HomeShiftRules.isTightTurnaround(start, end, start, end), isFalse);
  });
}
