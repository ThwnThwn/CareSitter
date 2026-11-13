import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/diagnostics/lab_demo_policy.dart';

void main() {
  test('native crash demo requires explicit build flag and is unavailable on web', () {
    expect(LabDemoPolicy.permits(web: false, enabled: true), isTrue);
    expect(LabDemoPolicy.permits(web: true, enabled: true), isFalse);
    expect(LabDemoPolicy.permits(web: false, enabled: false), isFalse);
  });
}
