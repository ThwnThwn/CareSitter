import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/core/diagnostics/crash_reporter.dart';
import 'package:caresitter_customer/core/diagnostics/guarded_crash_reporter.dart';

class Reporter extends NoopCrashReporter {
  bool failIdentity = false;
  Completer<void>? pendingIdentity;
  int reports = 0;
  @override
  bool get available => true;
  @override
  Future<void> identify(String? id) async {
    if (failIdentity) throw StateError('identity unavailable');
    if (pendingIdentity != null) await pendingIdentity!.future;
  }

  @override
  Future<void> nonfatalDemo(String runId) async {
    reports++;
  }
}

void main() {
  test('failed owner transition blocks reports until identity is reconciled',
      () async {
    final sdk = Reporter();
    final reporter = GuardedCrashReporter(sdk);
    await reporter.identify('first');
    await reporter.nonfatalDemo('first-event');
    sdk.failIdentity = true;
    await expectLater(reporter.identify('second'), throwsStateError);
    await expectLater(reporter.nonfatalDemo('unsafe'), throwsStateError);
    expect(sdk.reports, 1);
    sdk.failIdentity = false;
    await reporter.identify('second');
    await reporter.nonfatalDemo('second-event');
    expect(sdk.reports, 2);
  });
  test('late identity completion cannot resume reporting after a timeout',
      () async {
    final sdk = Reporter()..pendingIdentity = Completer<void>();
    final reporter =
        GuardedCrashReporter(sdk, timeout: const Duration(milliseconds: 20));
    await expectLater(
        reporter.identify('first'), throwsA(isA<TimeoutException>()));
    sdk.pendingIdentity!.complete();
    await expectLater(reporter.identify('second'), throwsStateError);
    await expectLater(reporter.nonfatalDemo('unsafe'), throwsStateError);
    expect(reporter.available, isFalse);
    expect(sdk.reports, 0);
  });
}
