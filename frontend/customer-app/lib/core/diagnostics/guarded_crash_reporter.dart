import 'dart:async';
import 'crash_reporter.dart';

/// A failed identity change cannot attribute later events to the previous owner.
class GuardedCrashReporter implements CrashReporter {
  GuardedCrashReporter(this.delegate,
      {this.timeout = const Duration(seconds: 5)});
  final CrashReporter delegate;
  final Duration timeout;
  Future<void> _tail = Future.value();
  bool _identityReady = false, _stopped = false;
  @override
  bool get available => delegate.available && !_stopped;
  Future<void> _serial(Future<void> Function() action) {
    final operation = _tail.then((_) async {
      if (_stopped) throw StateError('Crash reporting paused until restart.');
      try {
        await action().timeout(timeout);
      } on TimeoutException {
        _stopped = true;
        _identityReady = false;
        rethrow;
      }
    });
    _tail = operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  @override
  Future<void> identify(String? id) => _serial(() async {
        _identityReady = false;
        await delegate.identify(id);
        _identityReady = true;
      });
  @override
  Future<void> setScreen(String screen) =>
      _serial(() => delegate.setScreen(screen));
  Future<void> _report(Future<void> Function() action) => _serial(() async {
        if (!_identityReady) {
          throw StateError('Crash identity has not been reconciled.');
        }
        await action();
      });
  @override
  Future<void> record(Object error, StackTrace stack,
          {required bool fatal, required String source}) =>
      _report(
          () => delegate.record(error, stack, fatal: fatal, source: source));
  @override
  Future<void> nonfatalDemo(String runId) =>
      _report(() => delegate.nonfatalDemo(runId));
  @override
  Future<void> crashDemo(String runId) =>
      _report(() => delegate.crashDemo(runId));
}
