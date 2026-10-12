import 'package:flutter_test/flutter_test.dart';
import 'package:caregiver_app/core/utils/currency_formatter.dart';
import 'package:caregiver_app/core/utils/date_formatter.dart';
import 'package:caregiver_app/core/utils/phone_formatter.dart';

void main() {
  test('VND preserves signs, separators, rounding and the zero label', () {
    expect(formatVnd(1234567), '1.234.567đ');
    expect(formatVnd(1234567, compact: true, suffix: ''), '1.2tr');
    expect(formatVnd(-1234567, separator: ',', suffix: ''), '-1,234,567');
    expect(formatVnd(1000.9), '1.000đ');
    expect(formatVnd(1000.9, round: true), '1.001đ');
    expect(formatVnd(0, zeroLabel: 'Liên hệ'), 'Liên hệ');
  });
  test('date and elapsed time keep leading zeros and durations over 24 hours',
      () {
    expect(formatDate(DateTime(2026, 1, 2), padded: true), '02/01/2026');
    expect(formatDate(DateTime(7, 1, 2), padded: true), '02/01/0007');
    expect(formatClock(DateTime(2026, 1, 2, 8, 5)), '08:05');
    expect(formatDuration(const Duration(hours: 25, minutes: 1, seconds: 2)),
        '25:01:02');
  });
  test('phone normalization supports the Vietnamese country code', () {
    expect(normalizePhone('+84 (90) 123-4567'), '0901234567');
    expect(normalizePhone('090.123.4567'), '0901234567');
  });
}
