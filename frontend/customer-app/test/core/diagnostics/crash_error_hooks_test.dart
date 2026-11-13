import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caresitter_customer/app/diagnostics/crash_error_hooks.dart';
import 'package:caresitter_customer/core/diagnostics/crash_reporter.dart';

class Reporter extends NoopCrashReporter {
  int recorded = 0;
  @override
  bool get available => true;
  @override
  Future<void> record(Object error, StackTrace stack,
      {required bool fatal, required String source}) async {
    expect(fatal, isTrue);
    expect(source, 'flutter_framework');
    recorded++;
  }
}

void main() {
  test('framework hook preserves existing reporter and forwards fatal evidence',
      () async {
    final original = FlutterError.onError;
    var previousCalls = 0;
    FlutterError.onError = (_) => previousCalls++;
    final reporter = Reporter();
    final platformOriginal = PlatformDispatcher.instance.onError;
    try {
      installCrashErrorHooks(reporter);
      FlutterError.onError!(FlutterErrorDetails(
          exception: StateError('synthetic'), stack: StackTrace.current));
      expect(previousCalls, 1);
      expect(reporter.recorded, 1);
    } finally {
      FlutterError.onError = original;
      PlatformDispatcher.instance.onError = platformOriginal;
    }
  });
}
