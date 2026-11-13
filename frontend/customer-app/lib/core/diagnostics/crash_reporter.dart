import 'package:flutter_riverpod/flutter_riverpod.dart';

final crashReporterProvider =
    Provider<CrashReporter>((_) => NoopCrashReporter());

abstract interface class CrashReporter {
  bool get available;
  Future<void> identify(String? userId);
  Future<void> setScreen(String screen);
  Future<void> record(Object error, StackTrace stack,
      {required bool fatal, required String source});
  Future<void> nonfatalDemo(String runId);
  Future<void> crashDemo(String runId);
}

class NoopCrashReporter implements CrashReporter {
  @override
  bool get available => false;
  @override
  Future<void> identify(String? userId) async {}
  @override
  Future<void> setScreen(String screen) async {}
  @override
  Future<void> record(Object error, StackTrace stack,
      {required bool fatal, required String source}) async {}
  @override
  Future<void> nonfatalDemo(String runId) async =>
      throw StateError('Crashlytics chưa sẵn sàng.');
  @override
  Future<void> crashDemo(String runId) async =>
      throw StateError('Crashlytics chưa sẵn sàng.');
}
